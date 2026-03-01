/*
    scripts\naval\fn_destroyPatrolBoats.sqf
    NAVAL MISSION: Destroy Enemy Patrol Boats
*/
if (!isServer) exitWith {};

diag_log "[NAVAL-PATROL] Setting up Destroy Patrol Boats mission...";

// =====================================================
// 1. FIND DEEP WATER POSITION (far from land)
// =====================================================
private _basePos  = getMarkerPos "respawn_west";
private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];
private _mapSz    = worldSize;
private _waterCenter = [];

for "_i" from 1 to 200 do {
    private _x = 200 + random (_mapSz - 400);
    private _y = 200 + random (_mapSz - 400);
    private _p = [_x, _y, 0];

    if !(surfaceIsWater _p) then { continue };
    if (_p distance2D _basePos < 2500) then { continue };
    if !(_aoCenter isEqualTo [0,0,0]) then {
        if (_p distance2D _aoCenter < 1500) then { continue };
    };

    private _allWater = true;
    for "_d" from 0 to 315 step 45 do {
        private _chk = [_p, 400, _d] call DYN_fnc_posOffset;
        if !(surfaceIsWater _chk) exitWith { _allWater = false };
    };
    if (!_allWater) then { continue };

    _waterCenter = _p;
    break;
};

if (_waterCenter isEqualTo []) exitWith {
    diag_log "[NAVAL-PATROL] Could not find deep water position. Aborting.";
    DYN_naval_active = false;
};

diag_log format ["[NAVAL-PATROL] Deep water center: %1", _waterCenter];

// =====================================================
// 2. SETTINGS
// =====================================================
private _boatCount   = 2 + floor random 3;
private _patrolArea  = 600;
private _timeout     = 1800;
private _repReward   = 5 + floor random 6;
private _cleanupDelay = 300;

private _boatClasses = [
    "O_Boat_Armed_01_hmg_F",
    "O_Boat_Armed_01_hmg_F"
];

private _crewPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Ratnik_Autumn"
];

// =====================================================
// 3. SPAWN BOATS
// =====================================================
private _taskId = format ["naval_patrol_%1", round (diag_tickTime * 1000)];

for "_i" from 1 to _boatCount do {
    private _spawnPos = [_waterCenter, 100, _patrolArea, 40] call DYN_fnc_findNearbyWater;
    if (_spawnPos isEqualTo []) then {
        _spawnPos = [_waterCenter, 200 + random 300, _i * (360 / _boatCount)] call DYN_fnc_posOffset;
    };
    if !(surfaceIsWater _spawnPos) then { continue };

    private _boat = createVehicle [selectRandom _boatClasses, _spawnPos, [], 0, "NONE"];
    _boat setDir (random 360);
    _boat setPosASL [_spawnPos#0, _spawnPos#1, 0];

    { deleteVehicle _x } forEach crew _boat;

    private _grp = createGroup east;
    DYN_naval_enemyGroups pushBack _grp;

    private _driver = _grp createUnit [selectRandom _crewPool, _spawnPos, [], 0, "NONE"];
    _driver moveInDriver _boat;
    DYN_naval_enemies pushBack _driver;
    _driver allowFleeing 0;
    _driver setSkill 0.50;

    private _gunner = _grp createUnit [selectRandom _crewPool, _spawnPos, [], 0, "NONE"];
    _gunner moveInGunner _boat;
    DYN_naval_enemies pushBack _gunner;
    _gunner allowFleeing 0;
    _gunner setSkill 0.50;
    _gunner setSkill ["spotDistance", 0.60];
    _gunner setSkill ["aimingSpeed", 0.45];

    DYN_naval_enemyVehs pushBack _boat;

    if (random 1 < 0.5) then {
        private _extra = _grp createUnit [selectRandom _crewPool, _spawnPos, [], 0, "NONE"];
        if (!isNull _extra) then {
            _extra moveInCargo _boat;
            DYN_naval_enemies pushBack _extra;
            _extra allowFleeing 0;
        };
    };

    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
    _grp setSpeedMode "NORMAL";

    for "_w" from 1 to 5 do {
        private _wpPos = [_waterCenter, 100, _patrolArea * 1.2, 30] call DYN_fnc_findNearbyWater;
        if (_wpPos isEqualTo []) then {
            _wpPos = [_waterCenter, 200 + random 400, _w * 72] call DYN_fnc_posOffset;
        };

        private _wp = _grp addWaypoint [_wpPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "AWARE";
    };
    (_grp addWaypoint [_spawnPos, 0]) setWaypointType "CYCLE";
};

private _actualBoats = DYN_naval_enemyVehs select { !isNull _x && alive _x };
if (_actualBoats isEqualTo []) exitWith {
    diag_log "[NAVAL-PATROL] No boats spawned. Aborting.";
    DYN_naval_active = false;
};

// =====================================================
// 4. MARKER & TASK
// =====================================================
private _mkr = format ["naval_mkr_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _waterCenter];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [_patrolArea + 200, _patrolArea + 200];
_mkr setMarkerColor "ColorBlue";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
DYN_naval_markers pushBack _mkr;

[
    west,
    _taskId,
    [
        "Enemy patrol boats have been spotted operating in open water. Neutralize all hostile naval assets in the area.",
        "Destroy Enemy Naval Patrol",
        ""
    ],
    _waterCenter,
    "CREATED",
    3,
    true,
    "destroy"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_naval_tasks pushBack _taskId;

["NavalMission", ["Enemy naval patrol detected in open water."]]
    remoteExecCall ["BIS_fnc_showNotification", 0];

diag_log format ["[NAVAL-PATROL] %1 boats spawned at %2", count _actualBoats, _waterCenter];

// =====================================================
// 5. MONITOR COMPLETION & DELAYED CLEANUP
// =====================================================
[_taskId, _timeout, _repReward, _cleanupDelay] spawn {
    params ["_tid", "_tOut", "_rep", "_despawnDelay"];
    private _startTime = diag_tickTime;

    private _localEnemies = +DYN_naval_enemies;
    private _localGroups  = +DYN_naval_enemyGroups;
    private _localVehs    = +DYN_naval_enemyVehs;
    private _localMarkers = +DYN_naval_markers;

    waitUntil {
        sleep 8;
        private _allDead = ({ !isNull _x && alive _x } count _localVehs) == 0;
        private _timedOut = (diag_tickTime - _startTime) > _tOut;
        _allDead || _timedOut
    };

    private _boatsAlive = { !isNull _x && alive _x } count _localVehs;

    if (_boatsAlive == 0) then {
        [_tid, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalComplete", ["All enemy patrol boats neutralized."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        [_rep, "Naval Patrol Neutralized"] call DYN_fnc_changeReputation;
        diag_log format ["[NAVAL-PATROL] SUCCESS. +%1 rep.", _rep];
    } else {
        [_tid, "FAILED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalFailed", ["Naval patrol mission expired."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[NAVAL-PATROL] TIMED OUT.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_naval_markers = DYN_naval_markers - _localMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_naval_active = false;

    diag_log format ["[NAVAL-PATROL] Wreck cleanup in %1 minutes", floor (_despawnDelay / 60)];
    sleep _despawnDelay;

    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            deleteVehicle _x;
        };
    } forEach _localVehs;

    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
    { if (!isNull _x) then { deleteGroup _x } }   forEach _localGroups;

    DYN_naval_enemies     = DYN_naval_enemies     - _localEnemies;
    DYN_naval_enemyGroups = DYN_naval_enemyGroups  - _localGroups;
    DYN_naval_enemyVehs   = DYN_naval_enemyVehs   - _localVehs;

    diag_log "[NAVAL-PATROL] Full cleanup complete";
};
