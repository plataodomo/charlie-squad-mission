/*
    scripts\fn_gpsJammer.sqf
    UPDATED: ACE interaction with progress bar + repair animation
    FIXED: Sphere spawns offset from terminal, always in forest, AO clamped
    Requires ToolKit. 12 second duration.
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

// CUP Russian unit pools
private _staticPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

private _patrolPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AA_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_AO_hiddenTerrain") then { DYN_AO_hiddenTerrain = []; };
if (isNil "DYN_OBJ_centers") then { DYN_OBJ_centers = []; };

missionNamespace setVariable ["DYN_gpsJammerDisabled", false, true];

// Blackout marker
private _blackMarker = format ["GPS_BLACK_%1", round (diag_tickTime * 1000)];
createMarker [_blackMarker, _aoPos];
_blackMarker setMarkerShape "ELLIPSE";
_blackMarker setMarkerSize [_aoRadius * 1.08, _aoRadius * 1.08];
_blackMarker setMarkerColor "ColorBlack";
_blackMarker setMarkerBrush "SolidFull";
_blackMarker setMarkerAlpha 1;

// =====================================================
// DISTANCE CHECK — 600m from other objectives
// =====================================================
private _fn_farEnough = {
    params ["_pos"];
    if (_pos isEqualTo [] || {_pos isEqualTo [0,0,0]}) exitWith { false };
    private _tooClose = false;
    {
        if (!(_x isEqualTo []) && {!(_x isEqualTo [0,0,0])}) then {
            if ((_pos distance2D _x) < 600) then { _tooClose = true; };
        };
    } forEach DYN_OBJ_centers;
    !_tooClose
};

// =====================================================
// FIND FOREST POSITION — prioritize dense tree cover
// =====================================================
private _aoHardLimit = _aoRadius * 0.85;
private _minDist = 100;
private _maxDist = (_aoHardLimit - 20) max 150;

if (_maxDist < (_minDist + 50)) then {
    _minDist = 50;
    _maxDist = (_aoHardLimit - 20) max 100;
};

private _jamPos = [];
private _bestPos = [];
private _bestTreeCount = 0;

// Pass 1: Find position with HEAVY forest cover (20+ trees within 30m)
for "_i" from 1 to 400 do {
    private _dist = _minDist + random (_maxDist - _minDist);
    private _dir  = random 360;
    private _cand = _aoPos getPos [_dist, _dir];

    // Must be inside AO
    if ((_cand distance2D _aoPos) > _aoHardLimit) then { continue };
    if (surfaceIsWater _cand) then { continue };

    // No buildings or roads
    if ((count (nearestObjects [_cand, ["House","Building"], 40])) > 0) then { continue };
    if ((count (_cand nearRoads 25)) > 0) then { continue };

    // Must have forest — count trees in area
    private _treeCount = count (nearestTerrainObjects [_cand, ["TREE", "SMALL TREE"], 30, false]);
    if (_treeCount < 10) then { continue };

    // Must have clear spot right at center (so terminal fits)
    private _blockers = nearestTerrainObjects [_cand, ["TREE", "SMALL TREE", "ROCK", "ROCKS"], 3];
    if (count _blockers > 0) then { continue };

    // Check objective spacing
    if !([_cand] call _fn_farEnough) then { continue };

    // Track best position by tree density
    if (_treeCount > _bestTreeCount) then {
        _bestTreeCount = _treeCount;
        _bestPos = _cand;
    };

    // If we found a really dense spot (20+ trees), use it immediately
    if (_treeCount >= 20) exitWith {
        _jamPos = _cand;
        diag_log format ["[GPS] Found dense forest position (%1 trees) at attempt %2", _treeCount, _i];
    };
};

// Use best found position if we didn't find a 20+ tree spot
if (_jamPos isEqualTo [] && !(_bestPos isEqualTo [])) then {
    _jamPos = _bestPos;
    diag_log format ["[GPS] Using best forest position found (%1 trees)", _bestTreeCount];
};

// Pass 2: Relaxed search — any trees at all, still in AO
if (_jamPos isEqualTo []) then {
    diag_log "[GPS] Pass 1 failed, trying relaxed forest search";
    for "_i" from 1 to 300 do {
        private _cand = [_aoPos, _minDist, _maxDist, 5, 0, 0.4, 0] call BIS_fnc_findSafePos;
        if (_cand isEqualTo [0,0,0]) then { continue };
        if ((_cand distance2D _aoPos) > _aoHardLimit) then { continue };
        if (surfaceIsWater _cand) then { continue };

        private _treeCount = count (nearestTerrainObjects [_cand, ["TREE", "SMALL TREE"], 40, false]);
        if (_treeCount < 5) then { continue };

        private _blockers = nearestTerrainObjects [_cand, ["TREE", "SMALL TREE", "ROCK", "ROCKS"], 3];
        if (count _blockers > 0) then { continue };

        if ((count (nearestObjects [_cand, ["House","Building"], 30])) > 0) then { continue };

        _jamPos = _cand;
        diag_log format ["[GPS] Relaxed search found position (%1 trees) at attempt %2", _treeCount, _i];
        if (!(_jamPos isEqualTo [])) exitWith {};
    };
};

// Pass 3: Emergency fallback — just find dry land inside AO
if (_jamPos isEqualTo []) then {
    diag_log "[GPS] WARNING: No forest found, using emergency fallback";
    for "_k" from 1 to 200 do {
        private _rnd = _aoPos getPos [_minDist + random (_maxDist - _minDist), random 360];
        if (!surfaceIsWater _rnd && {(_rnd distance2D _aoPos) <= _aoHardLimit}) exitWith {
            _jamPos = _rnd;
        };
    };
};

if (_jamPos isEqualTo [] || {_jamPos isEqualTo [0,0,0]}) exitWith {
    diag_log "[GPS] ERROR: Could not find any position for GPS jammer, aborting";
    missionNamespace setVariable ["DYN_gpsJammerDisabled", true, true];
    deleteMarker _blackMarker;
};

// Final AO safety check
if ((_jamPos distance2D _aoPos) > _aoRadius) exitWith {
    diag_log format ["[GPS] ERROR: Jammer position outside AO (%1m), aborting", round (_jamPos distance2D _aoPos)];
    missionNamespace setVariable ["DYN_gpsJammerDisabled", true, true];
    deleteMarker _blackMarker;
};

// Register objective position
DYN_OBJ_centers pushBack _jamPos;

private _jamDir = random 360;

diag_log format ["[GPS] Jammer position: %1, %2m from AO center, %3 trees nearby", _jamPos, round (_jamPos distance2D _aoPos), count (nearestTerrainObjects [_jamPos, ["TREE", "SMALL TREE"], 30, false])];

// =====================================================
// OBJECTS
// =====================================================
// Only clear bushes right at center — leave trees for concealment
private _hiddenObjects = nearestTerrainObjects [_jamPos, ["BUSH"], 4, false];
{
    if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
        _x setVariable ["DYN_hiddenByAO", true, false];
        _x hideObjectGlobal true;
        DYN_AO_hiddenTerrain pushBack _x;
    };
} forEach _hiddenObjects;

// Also clear any small trees right at the terminal spot (within 2m)
{
    if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
        _x setVariable ["DYN_hiddenByAO", true, false];
        _x hideObjectGlobal true;
        DYN_AO_hiddenTerrain pushBack _x;
    };
} forEach (nearestTerrainObjects [_jamPos, ["SMALL TREE"], 2, false]);

private _camo = createVehicle ["CamoNet_BLUFOR_big_F", _jamPos, [], 0, "CAN_COLLIDE"];
_camo setDir _jamDir;
_camo setVectorUp (surfaceNormal _jamPos);
DYN_AO_objects pushBack _camo;

private _terminalPos = _jamPos getPos [0.8, _jamDir + 45];
private _terminal = createVehicle ["RuggedTerminal_01_communications_hub_F", _terminalPos, [], 0, "CAN_COLLIDE"];
_terminal setDir (_jamDir + 180);
_terminal setVectorUp (surfaceNormal _terminalPos);
_terminal allowDamage false;

_terminal setObjectTextureGlobal [0, "a3\props_f_decade\objectives\data\computerscreen_flame_ca.paa"];
_terminal setObjectTextureGlobal [1, "#(argb,8,8,3)color(1,0.5,0.25,0.99,ca)"];

_terminal setVariable ["gpsDisabled", false, true];
_terminal setVariable ["gpsBlackMarker", _blackMarker, true];

DYN_AO_objects pushBack _terminal;

// =====================================================
// GUARDS
// =====================================================
private _staticGrp = createGroup east;
DYN_AO_enemyGroups pushBack _staticGrp;
_staticGrp setBehaviour "AWARE";
_staticGrp setCombatMode "RED";

private _staticCount = 2 + floor (random 2);
for "_i" from 1 to _staticCount do {
    private _p = _jamPos getPos [3 + random 4, random 360];
    private _u = _staticGrp createUnit [selectRandom _staticPool, _p, [], 0, "NONE"];
    _u setDir (random 360);
    _u disableAI "PATH";
    _u setUnitPos "UP";
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

// Patrol Group 1
private _patrolGrp1 = createGroup east;
DYN_AO_enemyGroups pushBack _patrolGrp1;
_patrolGrp1 setBehaviour "AWARE";
_patrolGrp1 setCombatMode "RED";
_patrolGrp1 setSpeedMode "LIMITED";

private _patrol1Count = 3 + floor (random 2);
for "_i" from 1 to _patrol1Count do {
    private _p = [_jamPos, 10, 30, 2, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_p isEqualTo [0,0,0]) then { _p = _jamPos getPos [20, random 360]; };

    private _u = _patrolGrp1 createUnit [selectRandom _patrolPool, _p, [], 0, "FORM"];
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

for "_w" from 1 to 5 do {
    private _wpPos = [_jamPos, 15, 50, 2, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_wpPos isEqualTo [0,0,0]) then { _wpPos = _jamPos getPos [30, _w * 72]; };

    private _wp = _patrolGrp1 addWaypoint [_wpPos, 5];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCompletionRadius 5;
};
(_patrolGrp1 addWaypoint [_jamPos getPos [20, random 360], 0]) setWaypointType "CYCLE";

// Patrol Group 2
private _patrolGrp2 = createGroup east;
DYN_AO_enemyGroups pushBack _patrolGrp2;
_patrolGrp2 setBehaviour "AWARE";
_patrolGrp2 setCombatMode "RED";
_patrolGrp2 setSpeedMode "NORMAL";

private _patrol2Count = 2 + floor (random 2);
for "_i" from 1 to _patrol2Count do {
    private _p = [_jamPos, 40, 70, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_p isEqualTo [0,0,0]) then { _p = _jamPos getPos [50, random 360]; };

    private _u = _patrolGrp2 createUnit [selectRandom _patrolPool, _p, [], 0, "FORM"];
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

for "_w" from 1 to 6 do {
    private _wpPos = [_jamPos, 50, 90, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_wpPos isEqualTo [0,0,0]) then { _wpPos = _jamPos getPos [70, _w * 60]; };

    private _wp = _patrolGrp2 addWaypoint [_wpPos, 10];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCompletionRadius 10;
};
(_patrolGrp2 addWaypoint [_jamPos getPos [60, random 360], 0]) setWaypointType "CYCLE";

// =====================================================
// SERVER DISABLE FUNCTION
// =====================================================
DYN_fnc_disableGPSJammer = {
    params ["_terminal", "_caller"];

    if (!isServer) exitWith {};
    if (isNull _terminal || isNull _caller) exitWith {};
    if (_terminal getVariable ["gpsDisabled", false]) exitWith {};

    private _remoteOwner = remoteExecutedOwner;
    private _callerOwner = owner _caller;

    if (_remoteOwner > 2 && {_callerOwner != _remoteOwner}) exitWith {};
    if (!isPlayer _caller || !alive _caller) exitWith {};
    if (side (group _caller) != west) exitWith {};
    if ((_caller distance _terminal) > 6) exitWith {};

    private _items = items _caller + assignedItems _caller + backpackItems _caller + vestItems _caller + uniformItems _caller;
    if (!("ToolKit" in _items)) exitWith {
        ["TaskFailed", ["Need Toolkit", "You need a Toolkit to hack this device."]] remoteExecCall ["BIS_fnc_showNotification", _caller];
    };

    _terminal setVariable ["gpsDisabled", true, true];
    missionNamespace setVariable ["DYN_gpsJammerDisabled", true, true];

    private _mkr = _terminal getVariable ["gpsBlackMarker", ""];
    if (_mkr != "" && {(getMarkerPos _mkr) isNotEqualTo [0,0,0]}) then {
        _mkr setMarkerAlpha 0;
        deleteMarker _mkr;
    };

    _terminal setObjectTextureGlobal [0, "#(argb,8,8,3)color(0,0,0,1,ca)"];
    _terminal setObjectTextureGlobal [1, "#(argb,8,8,3)color(0.1,0.1,0.1,1,ca)"];

    ["TaskSucceeded", ["GPS Jammer Disabled", "Enemy GPS jamming signal neutralized."]]
        remoteExecCall ["BIS_fnc_showNotification", 0];
};
publicVariable "DYN_fnc_disableGPSJammer";

// =====================================================
// CLIENT ACE INTERACTION
// Helper placed OFFSET from terminal — in front of it
// NOT hidden - made visually invisible via transparent texture
// =====================================================
DYN_fnc_addGPSJammerHoldAction = {
    params ["_helper"];
    if (isNull _helper) exitWith {};

    if (isNil "ace_interact_menu_fnc_createAction") exitWith {
        diag_log "[GPS] ACE interact menu not loaded!";
    };

    private _terminal = _helper getVariable ["DYN_gpsTerminal", objNull];
    if (isNull _terminal) exitWith {};

    private _action = [
        "DYN_DisableGPSJammer",
        "Disable GPS Jammer",
        "\a3\ui_f\data\IGUI\Cfg\HoldActions\holdAction_hack_ca.paa",
        // --- STATEMENT ---
        {
            params ["_target", "_caller", "_params"];

            private _terminal = _target getVariable ["DYN_gpsTerminal", objNull];
            if (isNull _terminal) exitWith { hint "Device not found."; };

            private _items = items _caller + assignedItems _caller + backpackItems _caller + vestItems _caller + uniformItems _caller;
            if (!("ToolKit" in _items)) exitWith {
                hint "You need a ToolKit to disable this device.";
            };

            if (_terminal getVariable ["DYN_gpsHacking", false]) exitWith {
                hint "Someone is already working on this device.";
            };

            _terminal setVariable ["DYN_gpsHacking", true, true];

            missionNamespace setVariable ["DYN_progressTarget", _terminal];
            missionNamespace setVariable ["DYN_progressCaller", _caller];
            missionNamespace setVariable ["DYN_progressActive", true];

            _caller action ["SwitchWeapon", _caller, _caller, 99];

            [_caller] spawn {
                params ["_unit"];
                sleep 0.5;
                while {missionNamespace getVariable ["DYN_progressActive", false]} do {
                    if (!alive _unit) exitWith {};
                    _unit playMoveNow "Acts_carFixingWheel";
                    sleep 14;
                };
            };

            [
                12,
                "DISABLING GPS JAMMER",
                {
                    missionNamespace setVariable ["DYN_progressActive", false];
                    private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                    private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                    if (!isNull _c) then {
                        _c playMoveNow "";
                        _c switchMove "";
                    };
                    if (!isNull _t) then {
                        [_t, _c] remoteExecCall ["DYN_fnc_disableGPSJammer", 2];
                    };
                },
                {
                    missionNamespace setVariable ["DYN_progressActive", false];
                    private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                    private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                    if (!isNull _c) then {
                        _c playMoveNow "";
                        _c switchMove "";
                    };
                    if (!isNull _t) then {
                        _t setVariable ["DYN_gpsHacking", false, true];
                    };
                    hint "Disable cancelled.";
                    [] spawn { sleep 2; hintSilent ""; };
                },
                {
                    private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                    private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                    !isNull _t
                    && {!isNull _c}
                    && {alive _c}
                    && {(_c distance _t) < 6}
                }
            ] call DYN_fnc_showProgressBar;
        },
        // --- CONDITION ---
        {
            params ["_target", "_caller", "_params"];
            private _terminal = _target getVariable ["DYN_gpsTerminal", objNull];
            alive _caller
            && {(_caller distance _target) < 5}
            && {!isNull _terminal}
            && {!(_terminal getVariable ["gpsDisabled", false])}
            && {!(_terminal getVariable ["DYN_gpsHacking", false])}
        },
        {},
        [],
        [0, 0, 0],
        5
    ] call ace_interact_menu_fnc_createAction;

    [_helper, 0, ["ACE_MainActions"], _action] call ace_interact_menu_fnc_addActionToObject;

    diag_log format ["[GPS] ACE action added to helper %1 for terminal %2", _helper, _terminal];
};
publicVariable "DYN_fnc_addGPSJammerHoldAction";

// =====================================================
// HELPER SPHERE — spawned IN FRONT of terminal, not inside it
// Offset 1m in the terminal's facing direction at waist height
// =====================================================

// Terminal faces _jamDir + 180, so "in front" is _jamDir (the original forward)
private _helperOffset = _jamDir;  // Direction the terminal screen faces
private _helperWorldPos = _terminalPos getPos [1.0, _helperOffset];

private _helper = createVehicle ["Sign_Sphere10cm_F", [0,0,0], [], 0, "CAN_COLLIDE"];

// Place at the offset position, 1.0m above ground (waist height for comfortable ACE interaction)
private _helperATL = [_helperWorldPos#0, _helperWorldPos#1, 1.0];
_helper setPosATL _helperATL;

// Make visually invisible — DO NOT hideObjectGlobal (kills ACE interactions)
_helper setObjectTextureGlobal [0, "#(argb,8,8,3)color(0,0,0,0)"];

// DO NOT disable simulation — ACE needs it for interaction detection
_helper allowDamage false;

_helper setVariable ["DYN_gpsTerminal", _terminal, true];
DYN_AO_objects pushBack _helper;

// Verify helper is not inside terminal geometry
[_helper, _terminal, _helperWorldPos, _helperOffset] spawn {
    params ["_h", "_t", "_wPos", "_dir"];
    sleep 1;
    if (isNull _h || isNull _t) exitWith {};

    // Check if helper is too close to terminal center (inside the model)
    private _dist = _h distance _t;
    if (_dist < 0.5) then {
        // Push it further out
        private _newPos = (getPosATL _t) getPos [1.2, _dir];
        _newPos set [2, 1.0];
        _h setPosATL _newPos;
        diag_log format ["[GPS] Helper was inside terminal (dist %1m), repositioned to %2", _dist, _newPos];
    };
};

[_helper] remoteExec ["DYN_fnc_addGPSJammerHoldAction", 0, true];

diag_log format ["[GPS] Jammer spawned at %1, helper offset 1m in front at %2", _jamPos, _helperWorldPos];
