// init.sqf

// =====================================================
// MEDICAL FACILITY HEALING FUNCTION (marker-based)
// Server detects players in "medical_zone" marker area
// and remoteExecs this function to the player's client.
// Remove any building init field code for healing.
// =====================================================
MED_fnc_startHealing = {
    params ["_unit", "_markerPos", "_radius", "_time"];

    [_unit, _markerPos, _radius, _time] spawn {
        params ["_unit", "_markerPos", "_radius", "_time"];

        private _elapsed = 0;
        private _cancelled = false;

        hintSilent format ["Medical Facility\nHealing in %1 seconds...\nStay in the area.", _time];

        while {_elapsed < _time} do {
            sleep 1;
            _elapsed = _elapsed + 1;

            if (_unit distance2D _markerPos > _radius || !alive _unit) exitWith {
                _cancelled = true;
            };

            hintSilent format ["Medical Facility\nHealing in %1 seconds...", _time - _elapsed];
        };

        if (_cancelled) then {
            hintSilent "Healing cancelled.\nYou left the medical facility.";
            sleep 5;
            hintSilent "";
        } else {
            [_unit] call ace_medical_treatment_fnc_fullHealLocal;
            hintSilent "You have been fully healed!";
            sleep 5;
            hintSilent "";
        };

        _unit setVariable ["isHealing", false, true];
    };
};

// =====================================================
// CLIENT
// =====================================================
if (hasInterface) then {
    [] spawn {
        waitUntil { !isNull player };
        waitUntil { alive player };
        
        // Wait for reputation to sync from server (JIP fix)
        waitUntil { !isNil {missionNamespace getVariable "DYN_Reputation"} };
        
        sleep 1;
        execVM "scripts\fn_squadMenu.sqf";
    };
};

// =====================================================
// SERVER ONLY BLOCK
// =====================================================
if (!isServer) exitWith {};

// =====================================================
// GLOBAL POSITION HELPER
// Replaces invalid: _posArray getPos [dist, dir]
// =====================================================
DYN_fnc_posOffset = {
    params ["_pos", "_dist", "_dir"];
    [
        (_pos select 0) + _dist * sin _dir,
        (_pos select 1) + _dist * cos _dir,
        0
    ]
};
publicVariable "DYN_fnc_posOffset";

// Load saved reputation using safe loader (checks backup key if primary is missing/wiped)
// DYN_fnc_safeRepLoad is defined in fn_repSystem.sqf which loads further below,
// so we do a direct dual-key load here at startup before the scripts run.
private _primaryRep  = profileNamespace getVariable ["DYN_SavedReputation", -9999];
private _backupRep   = profileNamespace getVariable ["DYN_SavedReputation_BACKUP", -9999];
private _savedRep = 0;

if (_primaryRep == -9999 && _backupRep == -9999) then {
    // First ever run - start at 0
    _savedRep = 0;
    diag_log "[REP] No save data found - starting fresh";
} else {
    if (_primaryRep == -9999) then {
        // Primary missing, restore from backup
        _savedRep = _backupRep;
        diag_log format ["[REP] Primary save missing - restored from backup: %1", _backupRep];
    } else {
        if (_backupRep != -9999 && _backupRep > _primaryRep && (_backupRep - _primaryRep) > 20) then {
            // Backup is significantly higher - likely a wipe, use backup
            _savedRep = _backupRep;
            diag_log format ["[REP] WARNING: Primary (%1) much lower than backup (%2) - using backup", _primaryRep, _backupRep];
        } else {
            _savedRep = _primaryRep;
        };
    };
};

missionNamespace setVariable ["DYN_Reputation", _savedRep, true];
diag_log format ["[REP] Loaded reputation: %1 (primary=%2 backup=%3)", _savedRep, _primaryRep, _backupRep];

missionNamespace setVariable ["DYN_AO_lock", false, true];
missionNamespace setVariable ["DYN_AO_cleanupDone", false, false];
missionNamespace setVariable ["DYN_AO_killRequired", 0.60, true];
missionNamespace setVariable ["DYN_dataLinkDisabled", true, true];

// =====================================================
// ACE CAPTIVE REGISTRATION
// =====================================================
if (isNil "DYN_fnc_registerAceCapture") then {
    DYN_fnc_registerAceCapture = {
        params ["_unit", "_taskId", "_prisonerType", "_capturedVarName"];
        if (!isServer) exitWith {};
        if (isNull _unit) exitWith {};
        if !(isClass (configFile >> "CfgPatches" >> "ace_captives")) exitWith {};
        
        [_unit, _taskId, _prisonerType, _capturedVarName] spawn {
            params ["_u", "_taskId", "_ptype", "_capVar"];
            
            private _fn_isHandcuffed = {
                params ["_x"];
                if (!isNil "ace_captives_fnc_isHandcuffed") exitWith { [_x] call ace_captives_fnc_isHandcuffed };
                (_x getVariable ["ace_captives_isHandcuffed", false])
                || (_x getVariable ["ACE_isHandcuffed", false])
                || (_x getVariable ["ACE_captives_isHandcuffed", false])
            };
            
            waitUntil {
                sleep 1;
                isNull _u
                || {!alive _u}
                || {_u getVariable ["DYN_prisonDelivered", false]}
                || {_u getVariable [_capVar, false]}
                || ([_u] call _fn_isHandcuffed)
            };
            
            if (isNull _u || {!alive _u}) exitWith {};
            if (_u getVariable ["DYN_prisonDelivered", false]) exitWith {};
            if (_u getVariable [_capVar, false]) exitWith {};
            
            _u setVariable [_capVar, true, true];
            _u setVariable ["DYN_isPrisoner", true, true];
            _u setVariable ["DYN_prisonerType", _ptype, true];
            _u setVariable ["DYN_prisonTaskId", _taskId, true];
            
            removeAllWeapons _u;
            _u setCaptive true;
            _u allowFleeing 0;
            _u enableAI "MOVE";
            _u enableAI "PATH";
            _u enableAI "FSM";
            _u disableAI "AUTOCOMBAT";
            _u disableAI "TARGET";
            _u disableAI "SUPPRESSION";
            
            [_taskId, getMarkerPos "prison_dropoff"] remoteExec ["BIS_fnc_taskSetDestination", 0, true];
            ["TaskUpdated", [format ["%1 Restrained", _ptype], "Deliver the prisoner to the prison drop-off at base."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
        };
    };
    publicVariable "DYN_fnc_registerAceCapture";
};

// =====================================================
// OPFOR AWARENESS BOOST
// =====================================================
if (isNil "DYN_fnc_boostOpforAwareness") then {
    missionNamespace setVariable ["DYN_OPFOR_base_spotDistance", 0.80, true];
    missionNamespace setVariable ["DYN_OPFOR_base_spotTime",     0.75, true];
    missionNamespace setVariable ["DYN_OPFOR_base_courage",      0.85, true];
    missionNamespace setVariable ["DYN_OPFOR_base_commanding",   0.85, true];
    missionNamespace setVariable ["DYN_OPFOR_base_general",      0.85, true];
    missionNamespace setVariable ["DYN_OPFOR_base_aimingSpeed",  0.70, true];
    missionNamespace setVariable ["DYN_OPFOR_dl_spotDistance",   1.00, true];
    missionNamespace setVariable ["DYN_OPFOR_dl_spotTime",       1.00, true];
    missionNamespace setVariable ["DYN_OPFOR_dl_courage",        1.00, true];
    missionNamespace setVariable ["DYN_OPFOR_dl_commanding",     1.00, true];
    missionNamespace setVariable ["DYN_OPFOR_dl_general",        1.00, true];
    missionNamespace setVariable ["DYN_OPFOR_dl_aimingSpeed",    0.95, true];
    missionNamespace setVariable ["DYN_OPFOR_allowFleeing", 0.00, true];
    
    DYN_fnc_boostOpforAwareness = {
        params ["_u"];
        if (isNull _u) exitWith {};
        if !(_u isKindOf "Man") exitWith {};
        if (getPlayerUID _u != "") exitWith {};
        
        private _g = group _u;
        if (isNull _g) exitWith {};
        if (side _g != east) exitWith {};
        
        private _dlDisabled = missionNamespace getVariable ["DYN_dataLinkDisabled", true];
        private _spotDist = if (_dlDisabled) then { missionNamespace getVariable ["DYN_OPFOR_base_spotDistance", 0.80] } else { missionNamespace getVariable ["DYN_OPFOR_dl_spotDistance", 1.00] };
        private _spotTime = if (_dlDisabled) then { missionNamespace getVariable ["DYN_OPFOR_base_spotTime", 0.75] } else { missionNamespace getVariable ["DYN_OPFOR_dl_spotTime", 1.00] };
        private _courage  = if (_dlDisabled) then { missionNamespace getVariable ["DYN_OPFOR_base_courage", 0.85] } else { missionNamespace getVariable ["DYN_OPFOR_dl_courage", 1.00] };
        private _cmd      = if (_dlDisabled) then { missionNamespace getVariable ["DYN_OPFOR_base_commanding", 0.85] } else { missionNamespace getVariable ["DYN_OPFOR_dl_commanding", 1.00] };
        private _gen      = if (_dlDisabled) then { missionNamespace getVariable ["DYN_OPFOR_base_general", 0.85] } else { missionNamespace getVariable ["DYN_OPFOR_dl_general", 1.00] };
        private _aimSpd   = if (_dlDisabled) then { missionNamespace getVariable ["DYN_OPFOR_base_aimingSpeed", 0.70] } else { missionNamespace getVariable ["DYN_OPFOR_dl_aimingSpeed", 0.95] };
        
        _u setSkill ["spotDistance", _spotDist];
        _u setSkill ["spotTime",     _spotTime];
        _u setSkill ["courage",      _courage];
        _u setSkill ["commanding",   _cmd];
        _u setSkill ["general",      _gen];
        _u setSkill ["aimingSpeed",  _aimSpd];
        _u allowFleeing (missionNamespace getVariable ["DYN_OPFOR_allowFleeing", 0.0]);
    };
    publicVariable "DYN_fnc_boostOpforAwareness";
    
    if (isNil "DYN_fnc_refreshOpforAwareness") then {
        DYN_fnc_refreshOpforAwareness = {
            if (!isServer) exitWith {};
            private _opfor = allUnits select {side (group _x) == east && getPlayerUID _x == ""};
            { [_x] call DYN_fnc_boostOpforAwareness; } forEach _opfor;
        };
        publicVariable "DYN_fnc_refreshOpforAwareness";
    };

    call DYN_fnc_refreshOpforAwareness;
    
    addMissionEventHandler ["EntityCreated", {
        params ["_ent"];
        if (!isNull _ent && {_ent isKindOf "Man"} && {getPlayerUID _ent == ""} && {side (group _ent) == east}) then {
            [_ent] call DYN_fnc_boostOpforAwareness;
        };
    }];
};

// =====================================================
// AUTO-SAVE REPUTATION EVERY 5 MINUTES
// =====================================================
[] spawn {
    // Wait until fn_repSystem.sqf has loaded the safe save function
    waitUntil { !isNil "DYN_fnc_safeRepSave" };
    while {true} do {
        sleep 300;
        private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
        [_rep] call DYN_fnc_safeRepSave; // Uses validated dual-key save
        diag_log format ["[REP] Auto-saved reputation: %1", _rep];
    };
};

// =====================================================
// STAGGERED SPAWNING SYSTEM - PERFORMANCE FIX
// Reduces FPS drops when spawning large groups of enemies
// =====================================================

if (!isServer) then {} else {

    // =====================================================
    // STAGGERED GROUP SPAWNER
    // Spawns units one at a time with small delays
    // =====================================================
    DYN_fnc_createGroupStaggered = {
        params ["_group", "_unitClassArray", "_position", ["_formation", "FORM"], ["_delayBetween", 0.05]];
        
        if (isNull _group) exitWith { [] };
        if (_unitClassArray isEqualTo []) exitWith { [] };
        
        private _spawnedUnits = [];
        
        {
            private _unitClass = _x;
            private _unit = _group createUnit [_unitClass, _position, [], 0, _formation];
            
            if (!isNull _unit) then {
                _spawnedUnits pushBack _unit;
                
                // Track for cleanup if DYN_AO_enemies exists
                if (!isNil "DYN_AO_enemies") then {
                    DYN_AO_enemies pushBack _unit;
                };
                
                // Apply OPFOR skill boost if defined
                if (!isNil "DYN_fnc_boostOpforAwareness") then {
                    [_unit] call DYN_fnc_boostOpforAwareness;
                };
            };
            
            // Small delay between each unit
            if (_delayBetween > 0) then {
                sleep _delayBetween;
            };
            
        } forEach _unitClassArray;
        
        _spawnedUnits
    };
    publicVariable "DYN_fnc_createGroupStaggered";
    
    // =====================================================
    // BATCH SPAWNER - spawn multiple groups with delays
    // =====================================================
    DYN_fnc_spawnGroupsBatch = {
        params ["_groupDataArray", ["_delayBetweenGroups", 0.1]];
        
        // _groupDataArray format: [[side, unitClassArray, position, formation], ...]
        
        private _allGroups = [];
        
        {
            _x params ["_side", "_unitClasses", "_pos", ["_formation", "FORM"]];
            
            private _grp = createGroup _side;
            
            // Track group if DYN_AO_enemyGroups exists
            if (!isNil "DYN_AO_enemyGroups") then {
                DYN_AO_enemyGroups pushBack _grp;
            };
            
            // Spawn units in this group with stagger
            [_grp, _unitClasses, _pos, _formation, 0.05] call DYN_fnc_createGroupStaggered;
            
            _allGroups pushBack _grp;
            
            // Delay between groups
            if (_delayBetweenGroups > 0) then {
                sleep _delayBetweenGroups;
            };
            
        } forEach _groupDataArray;
        
        _allGroups
    };
    publicVariable "DYN_fnc_spawnGroupsBatch";
    
    diag_log "[PERFORMANCE] Staggered spawning system loaded - FPS drops during AO spawn should be reduced";
};

// =====================================================
// LOAD MISSION SCRIPTS
// =====================================================

// TFAR connection check — clients only (requires UI)
if (hasInterface) then { [] execVM "scripts\fn_checkTFR.sqf"; };

[] execVM "scripts\fn_prisonSystem.sqf";
[] execVM "scripts\fn_spawnObjectives.sqf";
[] execVM "scripts\reputation\fn_repSystem.sqf";
// === VEHICLE SHOP + PERSISTENCE ===
// Persistence MUST load first (defines tracking functions)
// Shop system uses tracking when vehicles are purchased
[] execVM "scripts\shop\fn_vehiclePersistence.sqf";
[] execVM "scripts\shop\fn_shopSystem.sqf";
[] execVM "scripts\naval\fn_navalMissions.sqf";
[] execVM "scripts\groundMissions\fn_groundMissions.sqf";

// =====================================================
// MEDICAL FACILITY - MARKER ZONE DETECTION
// Place a marker named "medical_zone" in the editor
// (ellipse or rectangle) covering your healing area.
// Server detects players inside and triggers healing.
// =====================================================
[] spawn {
    private _marker = "medical_zone";
    private _healTime = 30;

    // Wait for marker to exist (should be instant, but safety check)
    sleep 2;
    if (getMarkerPos _marker isEqualTo [0,0,0]) exitWith {
        diag_log "[MEDICAL] WARNING: marker 'medical_zone' not found - healing disabled";
    };

    private _markerPos = getMarkerPos _marker;
    private _markerSize = getMarkerSize _marker;
    // Cancel radius = largest dimension of marker so players can move freely inside
    private _cancelRadius = ((_markerSize select 0) max (_markerSize select 1)) + 5;

    diag_log format ["[MEDICAL] Healing zone active at %1 (radius %2, heal time %3s)", _markerPos, _cancelRadius, _healTime];

    while {true} do {
        {
            if (alive _x && !(_x getVariable ["isHealing", false]) && {_x inArea _marker}) then {
                _x setVariable ["isHealing", true, true];
                [_x, _markerPos, _cancelRadius, _healTime] remoteExecCall ["MED_fnc_startHealing", _x];
            };
        } forEach allPlayers;
        sleep 3;
    };
};

// =====================================================
// DEAD BODY CLEANUP
// Prevents corpse buildup during long sessions on Nitrado
//
// Timings:
//   OPFOR    ->  8 minutes  (480s) - time to loot
//   BLUFOR   ->  5 minutes  (300s) - squadmates can check fallen player
//   Civilian ->  2 minutes  (120s) - no loot value, clean fast
//
// NOTE: Prisoners marked DYN_keepInPrison are never deleted
// =====================================================
if (isNil "DYN_deadCleanupInit") then {
    DYN_deadCleanupInit = true;
    DYN_corpseQueue = [];

    addMissionEventHandler ["EntityKilled", {
        params ["_killed"];
        if (isNull _killed) exitWith {};
        if !(_killed isKindOf "Man") exitWith {};
        if (_killed getVariable ["DYN_keepInPrison", false]) exitWith {};

        private _g = group _killed;
        if (isNull _g) exitWith {};

        private _unitSide = side _g;
        private _deleteAt = switch (_unitSide) do {
            case east: { diag_tickTime + 480 };
            case west: { diag_tickTime + 300 };
            case civilian: { diag_tickTime + 120 };
            default { -1 };
        };

        if (_deleteAt > 0) then {
            DYN_corpseQueue pushBack [_killed, _deleteAt];
        };
    }];

    // Single cleanup manager instead of per-corpse spawn threads
    [] spawn {
        while {true} do {
            sleep 30;
            private _now = diag_tickTime;
            private _remaining = [];
            {
                _x params ["_corpse", "_deleteTime"];
                if (isNull _corpse) then { continue };
                if (_now >= _deleteTime) then {
                    deleteVehicle _corpse;
                } else {
                    _remaining pushBack _x;
                };
            } forEach DYN_corpseQueue;
            DYN_corpseQueue = _remaining;
        };
    };

    diag_log "[CLEANUP] Dead body cleanup initialized (OPFOR=8min BLUFOR=5min CIV=2min)";
};
