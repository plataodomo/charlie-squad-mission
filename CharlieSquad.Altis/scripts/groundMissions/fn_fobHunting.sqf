/*
    scripts\groundMissions\fn_fobHunting.sqf
    GROUND MISSION: FOB Hunting

    Players are tasked with infiltrating a heavily defended enemy FOB and
    destroying all four supply asset types:
        - B_Slingload_01_Repair_F   (+8 rep)
        - B_Slingload_01_Ammo_F     (+8 rep)
        - B_Slingload_01_Fuel_F     (+8 rep)
        - Box_EAF_AmmoVeh_F x2      (+5 rep each = +10 rep)
    Total possible: 34 reputation

    The FOB is located at a fixed position on the map. A garrison of OPFOR
    infantry defends the compound. All assets must be destroyed within the
    time limit for full mission success.
*/
if (!isServer) exitWith {};

diag_log "[GROUND-FOB] Setting up FOB Hunting mission...";

// =====================================================
// 1. SETTINGS
// =====================================================
private _fobCenter    = [7395, 6412, 0];   // Centre of the FOB compound
private _searchRadius = 200;               // Radius for target object search
private _timeout      = 7200;             // 2 hours
private _cleanupDelay = 120;              // Seconds before entity despawn after mission end

// Reputation per destroyed asset (total 34 if all destroyed)
private _repPerSlingload = 8;   // x3 = 24
private _repPerAmmoBox   = 5;   // x2 = 10

// =====================================================
// 2. SPAWN THE FOB BUILDING
// =====================================================
diag_log "[GROUND-FOB] Calling building SQF to create FOB...";
private _buildResult = [] call compile preprocessFileLineNumbers
    "scripts\groundMissions\buildings\FOB_Hunting.sqf";

// Allow object initialisation to settle
sleep 2;

// Collect all FOB building objects for cleanup at mission end
private _fobObjects = [];
if (!(_buildResult isEqualTo []) && { count _buildResult > 0 }) then {
    private _objList = (_buildResult select 0) select 0;
    { if (!isNull _x) then { _fobObjects pushBack _x } } forEach _objList;
};

diag_log format ["[GROUND-FOB] Building SQF created %1 objects.", count _fobObjects];

// =====================================================
// 3. LOCATE TARGET OBJECTS
// =====================================================
private _repairPod = objNull;
private _ammoPod   = objNull;
private _fuelPod   = objNull;
private _ammoBoxes = [];

{
    switch (typeOf _x) do {
        case "B_Slingload_01_Repair_F": { _repairPod = _x };
        case "B_Slingload_01_Ammo_F":   { _ammoPod   = _x };
        case "B_Slingload_01_Fuel_F":   { _fuelPod   = _x };
        case "Box_EAF_AmmoVeh_F":       { _ammoBoxes pushBack _x };
    };
} forEach nearestObjects [_fobCenter,
    ["B_Slingload_01_Repair_F",
     "B_Slingload_01_Ammo_F",
     "B_Slingload_01_Fuel_F",
     "Box_EAF_AmmoVeh_F"],
    _searchRadius];

// Validate all required targets were found
if (isNull _repairPod || isNull _ammoPod || isNull _fuelPod || count _ammoBoxes < 1) exitWith {
    diag_log "[GROUND-FOB] ERROR: One or more target objects not found. Aborting.";
    { if (!isNull _x) then { deleteVehicle _x } } forEach _fobObjects;
    DYN_ground_active = false;
};

diag_log format [
    "[GROUND-FOB] Targets confirmed - Repair: %1  Ammo: %2  Fuel: %3  AmmoBoxes: %4",
    !isNull _repairPod, !isNull _ammoPod, !isNull _fuelPod, count _ammoBoxes
];

// =====================================================
// 4. SPAWN ENEMY GARRISON
// =====================================================
// Six infantry groups spread around the compound interior and perimeter
private _spawnZones = [
    [30,  10],   // Near gate - north approach
    [45,  80],   // East inner wall
    [45, 160],   // South courtyard
    [45, 250],   // West inner wall
    [20,  40],   // Deep interior NE (near slingloads)
    [25, 220],   // Deep interior SW (near ammo boxes)
];

private _infantryTypes = [
    "CUP_O_TK_Soldier_F",
    "CUP_O_TK_Soldier_SL_F",
    "CUP_O_TK_Soldier_Marksman_F",
    "CUP_O_TK_Soldier_MG_F",
    "CUP_O_TK_Soldier_RPG_F"
];

{
    private _dist = _x select 0;
    private _dir  = _x select 1;
    private _spawnPos = [_fobCenter, _dist, _dir] call DYN_fnc_posOffset;
    private _grpSize  = 4 + floor random 5;  // 4-8 per group
    private _grp = createGroup east;

    for "_i" from 1 to _grpSize do {
        private _unitPos = [_spawnPos, random 8, random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _unitPos) then { _unitPos = _spawnPos };

        private _unit = _grp createUnit [selectRandom _infantryTypes, _unitPos, [], 0, "NONE"];
        if (!isNull _unit) then {
            _unit allowFleeing 0.1;
            _unit setSkill ["aimingAccuracy", 0.40 + random 0.35];
            _unit setSkill ["aimingShake",    0.45 + random 0.30];
            _unit setSkill ["aimingSpeed",    0.45 + random 0.30];
            _unit setSkill ["spotDistance",   0.70 + random 0.30];
            _unit setSkill ["spotTime",       0.65 + random 0.30];
            _unit setSkill ["courage",        0.75 + random 0.25];
            DYN_ground_enemies pushBack _unit;
        };
    };

    if (units _grp isEqualTo []) then {
        deleteGroup _grp;
    } else {
        _grp setBehaviourStrong "AWARE";
        _grp setCombatMode "RED";
        _grp setSpeedMode "NORMAL";

        // Local patrol around spawn zone
        private _wp = _grp addWaypoint [_spawnPos, 35];
        _wp setWaypointType "PATROL";
        _wp setWaypointLoiterRadius 35;

        DYN_ground_enemyGroups pushBack _grp;
    };
} forEach _spawnZones;

// Two static MG posts near the FOB perimeter walls
private _mgPosts = [
    [60,  15],
    [65, 195],
];

{
    private _mgPos = [_fobCenter, _x select 0, _x select 1] call DYN_fnc_posOffset;
    private _mgGrp = createGroup east;

    private _gunner = _mgGrp createUnit ["CUP_O_TK_Soldier_MG_F", _mgPos, [], 0, "NONE"];
    if (!isNull _gunner) then {
        _gunner allowFleeing 0;
        _gunner setSkill 0.85;
        _gunner disableAI "PATH";
        DYN_ground_enemies pushBack _gunner;
    };

    if (units _mgGrp isEqualTo []) then {
        deleteGroup _mgGrp;
    } else {
        _mgGrp setBehaviourStrong "COMBAT";
        _mgGrp setCombatMode "RED";
        DYN_ground_enemyGroups pushBack _mgGrp;
    };
} forEach _mgPosts;

// Outer roving patrol - 1 group circling outside the walls
private _outerPatrolGrp = createGroup east;
private _outerPatrolSize = 4 + floor random 3;

for "_i" from 1 to _outerPatrolSize do {
    private _unitPos = [_fobCenter, 80 + random 30, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _unitPos) then { _unitPos = _fobCenter };

    private _unit = _outerPatrolGrp createUnit [selectRandom _infantryTypes, _unitPos, [], 0, "NONE"];
    if (!isNull _unit) then {
        _unit allowFleeing 0.2;
        _unit setSkill 0.6;
        DYN_ground_enemies pushBack _unit;
    };
};

if (units _outerPatrolGrp isEqualTo []) then {
    deleteGroup _outerPatrolGrp;
} else {
    _outerPatrolGrp setBehaviourStrong "AWARE";
    _outerPatrolGrp setCombatMode "RED";
    _outerPatrolGrp setSpeedMode "NORMAL";

    private _wp = _outerPatrolGrp addWaypoint [_fobCenter, 90];
    _wp setWaypointType "PATROL";
    _wp setWaypointLoiterRadius 90;

    DYN_ground_enemyGroups pushBack _outerPatrolGrp;
};

diag_log format [
    "[GROUND-FOB] Garrison spawned: %1 groups, %2 infantry total.",
    count DYN_ground_enemyGroups,
    count DYN_ground_enemies
];

// Register FOB objects for global cleanup
{ DYN_ground_objects pushBack _x } forEach _fobObjects;

// =====================================================
// 5. MARKER AND TASK
// =====================================================
private _taskId = format ["ground_fob_%1", round (diag_tickTime * 1000)];

private _mkr = format ["ground_mkr_fob_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _fobCenter];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [_searchRadius * 0.6, _searchRadius * 0.6];
_mkr setMarkerColor "ColorRed";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
_mkr setMarkerText "Enemy FOB";
DYN_ground_markers pushBack _mkr;

[
    west,
    _taskId,
    [
        "Intelligence has confirmed an active enemy Forward Operating Base. The FOB is heavily garrisoned and holds critical supply assets that are sustaining enemy operations in the region.<br/><br/><t color='#FF4444'>OBJECTIVES - destroy all of the following:</t><br/><br/>- Repair Pod (B_Slingload_01_Repair_F)<br/>- Ammunition Pod (B_Slingload_01_Ammo_F)<br/>- Fuel Pod (B_Slingload_01_Fuel_F)<br/>- Ammunition Vehicles (Box_EAF_AmmoVeh_F)<br/><br/>Expect a heavily armed garrison. All supply assets must be eliminated to complete the mission.",
        "FOB Hunting",
        ""
    ],
    _fobCenter,
    "CREATED",
    3,
    true,
    "destroy"
] remoteExec ["BIS_fnc_taskCreate", 0, _taskId];

DYN_ground_tasks pushBack _taskId;

diag_log format ["[GROUND-FOB] Mission active. FOB centre: %1", _fobCenter];

// =====================================================
// 6. COMPLETION MONITOR
// =====================================================
private _localEnemies  = +DYN_ground_enemies;
private _localGroups   = +DYN_ground_enemyGroups;
private _localObjects  = +DYN_ground_objects;
private _localMarkers  = +DYN_ground_markers;

[
    _taskId, _timeout, _cleanupDelay,
    _repairPod, _ammoPod, _fuelPod, _ammoBoxes,
    _repPerSlingload, _repPerAmmoBox,
    _localEnemies, _localGroups, _localObjects, _localMarkers
] spawn {
    params [
        "_tid", "_tOut", "_despawnDelay",
        "_repairPod", "_ammoPod", "_fuelPod", "_ammoBoxes",
        "_repPerSlingload", "_repPerAmmoBox",
        "_localEnemies", "_localGroups", "_localObjects", "_localMarkers"
    ];

    private _startTime   = diag_tickTime;
    private _repairDone  = false;
    private _ammoDone    = false;
    private _fuelDone    = false;
    private _ammoBoxDone = false;

    // Helper - vehicle considered destroyed at 90 % damage or when no longer alive
    private _isDead = { (damage _this >= 0.9) || { !alive _this } || { isNull _this } };

    waitUntil {
        sleep 5;

        // ---- Repair pod ----
        if (!_repairDone && (_repairPod call _isDead)) then {
            _repairDone = true;
            [_repPerSlingload, "Enemy Repair Pod Destroyed"] call DYN_fnc_changeReputation;
            diag_log format ["[GROUND-FOB] Repair pod destroyed. +%1 rep.", _repPerSlingload];
        };

        // ---- Ammo pod ----
        if (!_ammoDone && (_ammoPod call _isDead)) then {
            _ammoDone = true;
            [_repPerSlingload, "Enemy Ammo Pod Destroyed"] call DYN_fnc_changeReputation;
            diag_log format ["[GROUND-FOB] Ammo pod destroyed. +%1 rep.", _repPerSlingload];
        };

        // ---- Fuel pod ----
        if (!_fuelDone && (_fuelPod call _isDead)) then {
            _fuelDone = true;
            [_repPerSlingload, "Enemy Fuel Pod Destroyed"] call DYN_fnc_changeReputation;
            diag_log format ["[GROUND-FOB] Fuel pod destroyed. +%1 rep.", _repPerSlingload];
        };

        // ---- Ammo vehicles (all must be destroyed for the reward) ----
        if (!_ammoBoxDone) then {
            private _allGone = (_ammoBoxes findIf { !(_x call _isDead) }) isEqualTo -1;
            if (_allGone && { count _ammoBoxes > 0 }) then {
                _ammoBoxDone = true;
                private _boxRep = _repPerAmmoBox * count _ammoBoxes;
                [_boxRep, "Enemy Ammo Vehicles Destroyed"] call DYN_fnc_changeReputation;
                diag_log format ["[GROUND-FOB] All ammo vehicles destroyed. +%1 rep.", _boxRep];
            };
        };

        // ---- Completion check ----
        private _allDone = _repairDone && _ammoDone && _fuelDone && _ammoBoxDone;
        private _timedOut = (diag_tickTime - _startTime) > _tOut;

        _allDone || _timedOut
    };

    private _allDone = _repairDone && _ammoDone && _fuelDone && _ammoBoxDone;

    if (_allDone) then {
        [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
        ["TaskSucceeded", [
            "FOB Hunting complete! All enemy supply assets have been destroyed.",
            "FOB Hunting"
        ]] remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-FOB] SUCCESS - all targets destroyed.";
    } else {
        [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
        ["TaskFailed", [
            "FOB Hunting Failed",
            "Not all supply assets were destroyed before the deadline."
        ]] remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-FOB] TIMED OUT - mission failed.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_ground_markers = DYN_ground_markers - _localMarkers;

    sleep 15;
    [_tid] remoteExec ["BIS_fnc_deleteTask", 0];
    [] remoteExec ["", 0, _tid];

    DYN_ground_active = false;

    diag_log format ["[GROUND-FOB] Despawning in %1 seconds.", _despawnDelay];
    sleep _despawnDelay;

    // Delete infantry and their groups
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
    { if (!isNull _x) then { deleteGroup _x } } forEach _localGroups;

    // Delete all FOB building objects
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localObjects;

    DYN_ground_enemies     = DYN_ground_enemies     - _localEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _localGroups;
    DYN_ground_objects     = DYN_ground_objects     - _localObjects;

    diag_log "[GROUND-FOB] Full cleanup complete.";
};

diag_log "[GROUND-FOB] FOB Hunting mission initialised successfully.";
