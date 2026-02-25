/*
    scripts\shop\fn_vehiclePersistence.sqf
    VEHICLE PERSISTENCE SYSTEM - SERVER ONLY

    Saves purchased vehicles that are parked inside the base area.
    Vehicles outside base on restart are LOST.
    Destroyed vehicles are deleted after 5 minutes and never saved.

    REQUIRED MARKERS (place in Eden editor):
      base_area     - ELLIPSE or RECTANGLE marker covering your entire base
                      (set alpha to 0 to make invisible on map)
      shop_spawn    - Ground vehicle parking/spawn (already exists)
      heli_spawn    - Helicopter pad (already exists)
      jet_spawn_1   - Jet hangar 1 (already exists)
      jet_spawn_2   - Jet hangar 2 (already exists)
*/
if (!isServer) exitWith {};
diag_log "[PERSISTENCE] Initializing Vehicle Persistence System";

// =====================================================
// TRACKED VEHICLES ARRAY
// =====================================================
if (isNil "DYN_shopTrackedVehicles") then {
    DYN_shopTrackedVehicles = [];
};

// =====================================================
// CHECK IF POSITION IS INSIDE BASE
// =====================================================
DYN_fnc_isInBase = {
    params ["_pos"];

    private _basePos = getMarkerPos "base_area";
    if (!(_basePos isEqualTo [0,0,0])) exitWith {
        _pos inArea "base_area"
    };

    // Fallback: 500m radius around respawn_west
    private _fallback = getMarkerPos "respawn_west";
    if (_fallback isEqualTo [0,0,0]) then {
        _fallback = [worldSize/2, worldSize/2, 0];
    };
    (_pos distance2D _fallback) < 500
};
publicVariable "DYN_fnc_isInBase";

// =====================================================
// TRACK A PURCHASED VEHICLE
// Called after purchase and after loading saved vehicles
// =====================================================
DYN_fnc_trackShopVehicle = {
    params ["_veh", "_category"];

    if (isNull _veh) exitWith {};

    // Tag the vehicle
    _veh setVariable ["DYN_shopPurchased", true, true];
    _veh setVariable ["DYN_shopCategory", _category, true];

    // Add to tracking list
    DYN_shopTrackedVehicles pushBack _veh;

    // --- DESTROYED HANDLER ---
    // Remove from tracking, delete wreck after 5 minutes
    _veh addEventHandler ["Killed", {
        params ["_veh"];

        private _type = typeOf _veh;
        private _cat = _veh getVariable ["DYN_shopCategory", "Unknown"];

        // Remove from persistence
        _veh setVariable ["DYN_shopPurchased", false, true];
        DYN_shopTrackedVehicles = DYN_shopTrackedVehicles - [_veh];

        diag_log format ["[PERSISTENCE] Vehicle destroyed: %1 (%2) - will be cleaned up in 5 min", _type, _cat];

        // Notify all players
        ["RepLoss", [format ["%1 has been destroyed and is permanently lost",
            getText (configFile >> "CfgVehicles" >> _type >> "displayName")
        ]]] remoteExec ["BIS_fnc_showNotification", 0];

        // Delete wreck after 5 minutes
        [_veh] spawn {
            params ["_wreck"];
            sleep 300;
            if (!isNull _wreck) then {
                deleteVehicle _wreck;
                diag_log "[PERSISTENCE] Destroyed wreck cleaned up";
            };
        };
    }];

    diag_log format ["[PERSISTENCE] Tracking: %1 (%2) | Total tracked: %3",
        typeOf _veh, _category, count DYN_shopTrackedVehicles];
};
publicVariable "DYN_fnc_trackShopVehicle";

// =====================================================
// SAVE ALL VEHICLES INSIDE BASE
// =====================================================
DYN_fnc_saveBaseVehicles = {
    if (!isServer) exitWith {};

    // Clean up null/destroyed references first
    DYN_shopTrackedVehicles = DYN_shopTrackedVehicles select {
        !isNull _x && {alive _x} && {_x getVariable ["DYN_shopPurchased", false]}
    };

    private _saveData = [];
    private _savedCount = 0;
    private _outsideCount = 0;

    {
        private _vehPos = getPosATL _x;

        if ([_vehPos] call DYN_fnc_isInBase) then {
            private _entry = [
                typeOf _x,
                _x getVariable ["DYN_shopCategory", "Cars"],
                _vehPos,
                getDir _x,
                fuel _x,
                damage _x
            ];
            _saveData pushBack _entry;
            _savedCount = _savedCount + 1;
        } else {
            _outsideCount = _outsideCount + 1;
        };
    } forEach DYN_shopTrackedVehicles;

    profileNamespace setVariable ["DYN_SavedVehicles", _saveData];
    saveProfileNamespace;

    diag_log format ["[PERSISTENCE] Auto-save: %1 saved in base | %2 outside base | %3 total tracked",
        _savedCount, _outsideCount, count DYN_shopTrackedVehicles];
};
publicVariable "DYN_fnc_saveBaseVehicles";

// =====================================================
// LOAD SAVED VEHICLES ON SERVER START
// =====================================================
DYN_fnc_loadBaseVehicles = {
    if (!isServer) exitWith {};

    private _saveData = profileNamespace getVariable ["DYN_SavedVehicles", []];

    if (count _saveData == 0) exitWith {
        diag_log "[PERSISTENCE] No saved vehicles to restore";
    };

    private _loadedCount = 0;
    private _failedCount = 0;

    {
        _x params ["_class", "_cat", "_pos", "_dir", "_fuelLevel", "_dmg"];

        if (!isClass (configFile >> "CfgVehicles" >> _class)) then {
            diag_log format ["[PERSISTENCE] SKIP: %1 - class not found in loaded mods", _class];
            _failedCount = _failedCount + 1;
            continue;
        };

        private _veh = createVehicle [_class, _pos, [], 0, "NONE"];

        if (isNull _veh) then {
            diag_log format ["[PERSISTENCE] FAILED to create: %1", _class];
            _failedCount = _failedCount + 1;
            continue;
        };

        _veh setDir _dir;
        _veh setPosATL _pos;
        _veh setFuel _fuelLevel;
        _veh setDamage _dmg;
        _veh setVariable ["DYN_restoredVehicle", true, true];

        [_veh, _cat] call DYN_fnc_trackShopVehicle;

        _loadedCount = _loadedCount + 1;

        private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
        diag_log format ["[PERSISTENCE] Restored: %1 (%2) at %3 | Fuel: %4 | Damage: %5",
            _displayName, _cat, _pos, _fuelLevel, _dmg];

    } forEach _saveData;

    diag_log format ["[PERSISTENCE] === RESTORE COMPLETE: %1 loaded, %2 failed, %3 total saved ===",
        _loadedCount, _failedCount, count _saveData];
};

// =====================================================
// GET STATUS (for debug/admin)
// =====================================================
DYN_fnc_getVehicleStatus = {
    if (!isServer) exitWith { "Server only" };

    DYN_shopTrackedVehicles = DYN_shopTrackedVehicles select {
        !isNull _x && {alive _x} && {_x getVariable ["DYN_shopPurchased", false]}
    };

    private _total = count DYN_shopTrackedVehicles;
    private _inBase = 0;
    private _outside = 0;

    {
        if ([getPosATL _x] call DYN_fnc_isInBase) then {
            _inBase = _inBase + 1;
        } else {
            _outside = _outside + 1;
        };
    } forEach DYN_shopTrackedVehicles;

    format ["Tracked: %1 | In Base: %2 (saved) | Outside: %3 (at risk)", _total, _inBase, _outside]
};
publicVariable "DYN_fnc_getVehicleStatus";

// =====================================================
// STARTUP SEQUENCE
// =====================================================
// FIX: Increased from 3 seconds to 15 seconds.
// Nitrado dedicated servers with heavy mods (CUP, ACE, KAT)
// need time to finish streaming terrain and initializing
// the world before vehicles can be placed reliably.
// 3 seconds was too short - vehicles would either fail to
// spawn or clip through terrain on server start.
[] spawn {
    diag_log "[PERSISTENCE] Waiting 15 seconds for world init before restoring vehicles...";
    sleep 15;
    [] call DYN_fnc_loadBaseVehicles;
    diag_log "[PERSISTENCE] Initial load complete";
};

// Auto-save every 3 minutes
[] spawn {
    sleep 90; // First save after 1.5 minutes
    while {true} do {
        [] call DYN_fnc_saveBaseVehicles;
        sleep 180;
    };
};

// Final save on mission end (graceful shutdown/restart)
addMissionEventHandler ["MPEnded", {
    [] call DYN_fnc_saveBaseVehicles;
    diag_log "[PERSISTENCE] === FINAL SAVE ON SHUTDOWN ===";
}];

// Backup save when last player disconnects
addMissionEventHandler ["HandleDisconnect", {
    if (count allPlayers <= 1) then {
        [] call DYN_fnc_saveBaseVehicles;
        diag_log "[PERSISTENCE] Save triggered - last player disconnecting";
    };
    false
}];

diag_log "[PERSISTENCE] Vehicle Persistence System Ready";
