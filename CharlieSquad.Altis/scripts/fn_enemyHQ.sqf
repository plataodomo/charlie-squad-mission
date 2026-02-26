/*
    scripts\fn_enemyHQ.sqf
    CUP RUSSIAN FORCES + MTLB REINFORCEMENTS
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

private _hqTaskId = format ["task_hq_%1", round (diag_tickTime * 1000)];
private _zOffset = 0.35;

// CUP UNIT POOLS
private _infantryPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

private _defenderPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Medic_Ratnik_Autumn"
];

private _towerPool = [
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_MG_Ratnik_Autumn"
];

// CUP Russian Officer
private _officerClass = "CUP_O_RU_Officer_EMR";

// Reinforcement settings
private _reinforcementTrucks = 1 + floor (random 5);
private _captureReinforcementChance = 0.40;

missionNamespace setVariable ["DYN_HQReinforcementsSpawned", false, true];

if (isNil "DYN_AO_hiddenTerrain") then { DYN_AO_hiddenTerrain = []; };
if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_AO_enemyVehs") then { DYN_AO_enemyVehs = []; };
if (isNil "DYN_AO_sideTasks") then { DYN_AO_sideTasks = []; };
if (isNil "DYN_OBJ_centers") then { DYN_OBJ_centers = []; };

// =====================================================
// DISTANCE CHECK — 600m from other major objectives
// =====================================================
private _fn_farEnough = {
    params ["_pos"];
    if (_pos isEqualTo [] || {_pos isEqualTo [0,0,0]}) exitWith { false };
    private _tooClose = false;
    {
        if ((_pos distance2D _x) < 600) exitWith { _tooClose = true; };
    } forEach DYN_OBJ_centers;
    !_tooClose
};

// =====================================================
// HARD AO BOUNDARY CHECK — must be inside AO circle
// =====================================================
private _aoHardLimit = _aoRadius * 0.85;  // Stay within 85% of AO radius (935m for 1100m AO)

private _fn_insideAO = {
    params ["_pos"];
    if (_pos isEqualTo [] || {_pos isEqualTo [0,0,0]}) exitWith { false };
    (_pos distance2D _aoPos) <= _aoHardLimit
};

// =====================================================
// REINFORCEMENTS FUNCTION
// =====================================================
if (isNil "DYN_fnc_spawnHQReinforcements") then {
    DYN_fnc_spawnHQReinforcements = {
        params ["_hqPos", "_truckCount"];
        if (!isServer) exitWith {};
        if (missionNamespace getVariable ["DYN_HQReinforcementsSpawned", false]) exitWith {};
        missionNamespace setVariable ["DYN_HQReinforcementsSpawned", true, true];

        ["TaskFailed", ["HQ Alert!", "Enemy reinforcements inbound!"]]
            remoteExecCall ["BIS_fnc_showNotification", 0];

        private _aoRadius = missionNamespace getVariable ["DYN_AO_radius", 1000];

        private _spawnDist = _aoRadius + 350;
        private _spawnPos = [];
        private _spawnDir = 0;
        private _foundRoad = false;

        for "_attempt" from 1 to 30 do {
            private _searchDir = _attempt * 12;
            private _searchPos = _hqPos getPos [_spawnDist + random 150, _searchDir];
            private _nearbyRoads = _searchPos nearRoads 150;

            if !(_nearbyRoads isEqualTo []) then {
                _nearbyRoads = [_nearbyRoads, [], { _x distance2D _searchPos }, "ASCEND"] call BIS_fnc_sortBy;
                {
                    private _roadPos = getPos _x;
                    if (
                        (_roadPos distance2D _hqPos) > (_aoRadius + 150)
                        && {!surfaceIsWater _roadPos}
                        && {(nearestObjects [_roadPos, ["House", "Building"], 20]) isEqualTo []}
                    ) exitWith {
                        _spawnPos = _roadPos;
                        _spawnDir = _roadPos getDir _hqPos;
                        _foundRoad = true;
                    };
                } forEach _nearbyRoads;
            };

            if (_foundRoad) exitWith {};
        };

        if (!_foundRoad) then {
            for "_attempt" from 1 to 20 do {
                private _testPos = [_hqPos, _spawnDist, _spawnDist + 200, 15, 0, 0.3, 0] call BIS_fnc_findSafePos;

                if !(_testPos isEqualTo [0,0,0]) then {
                    if (
                        (_testPos distance2D _hqPos) > (_aoRadius + 100)
                        && {!surfaceIsWater _testPos}
                        && {(nearestObjects [_testPos, ["House", "Building"], 25]) isEqualTo []}
                    ) exitWith {
                        _spawnPos = _testPos;
                        _spawnDir = _testPos getDir _hqPos;
                    };
                };
            };
        };

        if (_spawnPos isEqualTo []) then {
            _spawnPos = _hqPos getPos [_spawnDist + 100, random 360];
            _spawnDir = _spawnPos getDir _hqPos;
        };

        private _mtlbClass = "CUP_O_MTLB_pk_Green_RU";

        private _infantryClasses = [
            "CUP_O_RU_Soldier_Ratnik_Autumn",
            "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
            "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
            "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
            "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
            "CUP_O_RU_Soldier_SL_Ratnik_Autumn",
            "CUP_O_RU_Medic_Ratnik_Autumn",
            "CUP_O_RU_Soldier_TL_Ratnik_Autumn",
            "CUP_O_RU_Soldier_MG_Ratnik_Autumn"
        ];

        for "_t" from 1 to _truckCount do {
            private _delay = (_t - 1) * (12 + random 10);

            [_t, _delay, _spawnPos, _spawnDir, _hqPos, _mtlbClass, _infantryClasses, _aoRadius] spawn {
                params ["_truckNum", "_delay", "_spawnPos", "_spawnDir", "_hqPos", "_mtlbClass", "_infantryClasses", "_aoRadius"];

                sleep _delay;
                if (!DYN_AO_active) exitWith {};

                private _thisSpawn = [];
                private _offsetPos = _spawnPos getPos [_truckNum * 25, _spawnDir + 90];

                private _emptyPos = _offsetPos findEmptyPosition [0, 80, _mtlbClass];
                if !(_emptyPos isEqualTo []) then {
                    _thisSpawn = _emptyPos;
                } else {
                    _thisSpawn = [_offsetPos, 0, 100, 12, 0, 0.4, 0] call BIS_fnc_findSafePos;
                    if (_thisSpawn isEqualTo [0,0,0]) then { _thisSpawn = _offsetPos; };
                };

                private _nearBuildings = nearestObjects [_thisSpawn, ["House", "Building"], 15];
                if !(_nearBuildings isEqualTo []) then {
                    private _building = _nearBuildings select 0;
                    private _awayDir = _building getDir _thisSpawn;
                    _thisSpawn = _thisSpawn getPos [25, _awayDir];
                };

                private _dismountPos = [_hqPos, 50, 80, 10, 0, 0.5, 0] call BIS_fnc_findSafePos;
                if (_dismountPos isEqualTo [0,0,0]) then { _dismountPos = _hqPos getPos [60 + random 20, random 360]; };

                private _truck = createVehicle [_mtlbClass, _thisSpawn, [], 0, "NONE"];
                if (isNull _truck) exitWith {};

                _truck setPos _thisSpawn;
                _truck setDir (_thisSpawn getDir _hqPos);
                _truck setVelocity [0,0,0];

                sleep 0.3;

                if ((vectorUp _truck) select 2 < 0.5) then { _truck setVectorUp [0,0,1]; };
                if (damage _truck > 0.5) then { _truck setDamage 0; };

                DYN_AO_enemyVehs pushBack _truck;

                createVehicleCrew _truck;
                sleep 0.3;

                private _driver = driver _truck;
                private _gunner = gunner _truck;
                private _driverGrp = grpNull;

                if (!isNull _driver) then {
                    _driverGrp = group _driver;
                    _driver allowFleeing 0;
                    _driver setSkill 1;
                    DYN_AO_enemies pushBack _driver;
                };

                if (!isNull _gunner) then {
                    _gunner allowFleeing 0;
                    _gunner setSkill 1;
                    DYN_AO_enemies pushBack _gunner;
                };

                if (isNull _driver) then {
                    _driverGrp = createGroup east;
                    private _newDriver = _driverGrp createUnit ["O_crew_F", _thisSpawn, [], 0, "NONE"];
                    _newDriver assignAsDriver _truck;
                    _newDriver moveInDriver _truck;
                    _newDriver allowFleeing 0;
                    DYN_AO_enemies pushBack _newDriver;
                    sleep 0.3;
                };

                if (isNull _driverGrp) then { _driverGrp = createGroup east; };
                DYN_AO_enemyGroups pushBack _driverGrp;

                _driver = driver _truck;
                if (isNull _driver) exitWith { deleteVehicle _truck; };

                _driverGrp setBehaviour "CARELESS";
                _driverGrp setCombatMode "BLUE";
                _driverGrp setSpeedMode "FULL";

                private _infantryGrp = createGroup east;
                DYN_AO_enemyGroups pushBack _infantryGrp;
                _infantryGrp setBehaviour "AWARE";
                _infantryGrp setCombatMode "RED";

                private _infantryUnits = [];
                private _maxCargo = _truck emptyPositions "cargo";
                private _fillSeats = (_maxCargo - floor (random 2)) max 4;

                for "_i" from 1 to _fillSeats do {
                    private _u = _infantryGrp createUnit [selectRandom _infantryClasses, _thisSpawn, [], 0, "NONE"];
                    if (!isNull _u) then {
                        _u assignAsCargo _truck;
                        _u moveInCargo _truck;
                        _u allowFleeing 0;
                        DYN_AO_enemies pushBack _u;
                        _infantryUnits pushBack _u;
                    };
                };

                sleep 0.3;
                { if (!isNull _x && alive _x && (vehicle _x != _truck)) then { _x moveInCargo _truck; }; } forEach _infantryUnits;

                for "_i" from (count waypoints _driverGrp - 1) to 0 step -1 do { deleteWaypoint [_driverGrp, _i]; };

                private _wp1 = _driverGrp addWaypoint [_dismountPos, 0];
                _wp1 setWaypointType "MOVE";
                _wp1 setWaypointSpeed "FULL";
                _wp1 setWaypointBehaviour "CARELESS";
                _wp1 setWaypointCombatMode "BLUE";
                _wp1 setWaypointCompletionRadius 25;

                (driver _truck) doMove _dismountPos;

                private _startTime = diag_tickTime;
                private _timeout = 180;
                private _lastPos = getPosATL _truck;
                private _stuckTime = 0;

                waitUntil {
                    sleep 1;

                    if (isNull _truck || !alive _truck) exitWith { true };
                    if (!DYN_AO_active) exitWith { true };
                    if ((diag_tickTime - _startTime) > _timeout) exitWith { true };

                    private _currentPos = getPosATL _truck;
                    private _distToTarget = _truck distance2D _dismountPos;

                    if ((_currentPos distance2D _lastPos) < 2) then { _stuckTime = _stuckTime + 1; } else { _stuckTime = 0; _lastPos = _currentPos; };

                    if (_stuckTime > 15) then { (driver _truck) doMove _dismountPos; _stuckTime = 0; };

                    (_distToTarget < 35)
                };

                if (isNull _truck || !alive _truck) exitWith {};
                if (!DYN_AO_active) exitWith { { if (!isNull _x) then { deleteVehicle _x; }; } forEach crew _truck; deleteVehicle _truck; };

                _truck setVelocity [0,0,0];
                (driver _truck) doMove (getPosATL _truck);

                sleep 0.5;

                private _smokeTypes = ["SmokeShell", "SmokeShellRed", "SmokeShellOrange", "SmokeShellGreen"];
                for "_s" from 1 to 3 do {
                    private _smokePos = (getPosATL _truck) getPos [4 + random 6, _s * 120];
                    createVehicle [selectRandom _smokeTypes, _smokePos, [], 0, "NONE"];
                };

                sleep 1.5;

                {
                    if (!isNull _x && alive _x) then {
                        unassignVehicle _x;
                        [_x] orderGetIn false;
                        moveOut _x;
                    };
                } forEach _infantryUnits;

                sleep 1;

                {
                    if (!isNull _x && alive _x && (vehicle _x == _truck)) then { moveOut _x; };
                } forEach _infantryUnits;

                sleep 1;

                private _aliveInf = _infantryUnits select { !isNull _x && alive _x && (vehicle _x == _x) };

                if ((count _aliveInf) > 0) then {
                    for "_i" from (count waypoints _infantryGrp - 1) to 0 step -1 do { deleteWaypoint [_infantryGrp, _i]; };

                    _infantryGrp setBehaviour "COMBAT";
                    _infantryGrp setCombatMode "RED";
                    _infantryGrp setSpeedMode "FULL";

                    private _suppressPos = _hqPos getPos [20 + random 20, random 360];
                    { if (!isNull _x && alive _x) then { _x doSuppressiveFire _suppressPos; }; } forEach _aliveInf;

                    sleep 2;

                    if ((count _aliveInf) >= 4) then {
                        private _halfCount = floor ((count _aliveInf) / 2);
                        private _teamAlpha = _aliveInf select [0, _halfCount];
                        private _teamBravo = _aliveInf select [_halfCount, count _aliveInf];

                        private _bravoGrp = createGroup east;
                        DYN_AO_enemyGroups pushBack _bravoGrp;
                        _bravoGrp setBehaviour "COMBAT";
                        _bravoGrp setCombatMode "RED";
                        _bravoGrp setSpeedMode "FULL";

                        { [_x] joinSilent _bravoGrp; } forEach _teamBravo;

                        private _wpA1 = _infantryGrp addWaypoint [_hqPos getPos [30, random 360], 15];
                        _wpA1 setWaypointType "SAD";
                        _wpA1 setWaypointSpeed "FULL";
                        _wpA1 setWaypointBehaviour "COMBAT";
                        (_infantryGrp addWaypoint [_hqPos, 0]) setWaypointType "CYCLE";

                        private _flankDir = (_dismountPos getDir _hqPos) + 90 + (random 40) - 20;
                        private _flankPos = _hqPos getPos [50, _flankDir];

                        private _wpB1 = _bravoGrp addWaypoint [_flankPos, 15];
                        _wpB1 setWaypointType "SAD";
                        _wpB1 setWaypointSpeed "FULL";
                        _wpB1 setWaypointBehaviour "COMBAT";
                        (_bravoGrp addWaypoint [_hqPos, 0]) setWaypointType "CYCLE";
                    } else {
                        private _wp2 = _infantryGrp addWaypoint [_hqPos getPos [25, random 360], 15];
                        _wp2 setWaypointType "SAD";
                        _wp2 setWaypointSpeed "FULL";
                        _wp2 setWaypointBehaviour "COMBAT";
                        (_infantryGrp addWaypoint [_hqPos, 0]) setWaypointType "CYCLE";
                    };
                };

                sleep 2;

                private _currentDriver = driver _truck;

                if (!isNull _currentDriver && alive _currentDriver && !isNull _truck && alive _truck) then {
                    for "_i" from (count waypoints _driverGrp - 1) to 0 step -1 do { deleteWaypoint [_driverGrp, _i]; };

                    private _retreatDir = _hqPos getDir (getPosATL _truck);
                    private _retreatPos = (getPosATL _truck) getPos [800 + random 400, _retreatDir];

                    _driverGrp setBehaviour "CARELESS";
                    _driverGrp setCombatMode "BLUE";
                    _driverGrp setSpeedMode "FULL";

                    private _wpRetreat = _driverGrp addWaypoint [_retreatPos, 0];
                    _wpRetreat setWaypointType "MOVE";
                    _wpRetreat setWaypointSpeed "FULL";
                    _wpRetreat setWaypointBehaviour "CARELESS";
                    _wpRetreat setWaypointCombatMode "BLUE";

                    _currentDriver doMove _retreatPos;

                    [_truck, _driverGrp, _hqPos, _truckNum, _aoRadius] spawn {
                        params ["_truck", "_driverGrp", "_hqPos", "_truckNum", "_aoRadius"];

                        private _timeout = diag_tickTime + 180;

                        waitUntil {
                            sleep 3;
                            if (isNull _truck || !alive _truck) exitWith { true };
                            if (!DYN_AO_active) exitWith { true };
                            if (diag_tickTime > _timeout) exitWith { true };
                            ((_truck distance2D _hqPos) > (_aoRadius + 300))
                        };

                        sleep 2;

                        { if (!isNull _x) then { deleteVehicle _x; }; } forEach crew _truck;
                        if (!isNull _truck) then { deleteVehicle _truck; };

                        if (!isNull _driverGrp && {count units _driverGrp == 0}) then { deleteGroup _driverGrp; };
                    };
                };
            };
        };
    };
    publicVariable "DYN_fnc_spawnHQReinforcements";
};

// =====================================================
// HQ POSITION SEARCH — constrained to AO
// =====================================================
private _hqDir = random 360;

// Use AO-relative distances — HQ footprint is ~90m radius, keep it well inside
private _footR = 90;
private _searchMax = (_aoHardLimit - _footR) max 100;  // Max distance from AO center for HQ center
private _minDist = 100;                                  // Min distance from AO center

// Clamp search range
if (_searchMax < _minDist) then { _minDist = _searchMax * 0.5; };

private _deltaStrict = 0.55;
private _deltaRelax  = 0.75;

private _fn_sampleHeightsArr = {
    params ["_p", "_r"];
    private _hs = [];
    _hs pushBack (getTerrainHeightASL _p);
    {
        _hs pushBack (getTerrainHeightASL (_p getPos [_r, _x]));
        _hs pushBack (getTerrainHeightASL (_p getPos [_r*0.55, _x]));
    } forEach [0,45,90,135,180,225,270,315];
    _hs
};

private _fn_minMax = {
    params ["_arr"];
    [selectMin _arr, selectMax _arr]
};

private _fn_footprintDry = {
    params ["_p", "_r"];
    if (_p isEqualTo [0,0,0]) exitWith {false};
    if (surfaceIsWater _p) exitWith {false};
    { if (surfaceIsWater (_p getPos [_r, _x])) exitWith {false}; } forEach [0,45,90,135,180,225,270,315];
    true
};

private _fn_findHQ = {
    params ["_bldDist", "_deltaLimit", "_timeBudget"];

    private _best = [];
    private _bestDH = 1e9;

    private _t0 = diag_tickTime;
    while {(diag_tickTime - _t0) < _timeBudget} do {
        private _cand = [_aoPos, _minDist, _searchMax, 60, 1, 0.25, 0] call BIS_fnc_findSafePos;
        if (_cand isEqualTo [0,0,0]) then { continue };

        // HARD AO BOUNDARY CHECK — candidate center + footprint must be inside AO
        if !([_cand] call _fn_insideAO) then { continue };
        // Also check footprint edges are inside AO
        if ((_cand distance2D _aoPos) > (_aoHardLimit - _footR)) then { continue };

        if !([_cand, _footR] call _fn_footprintDry) then { continue };

        if (isOnRoad _cand) then { continue };
        if ((count (_cand nearRoads 120)) > 0) then { continue };

        // Reject if too close to other major objectives
        if !([_cand] call _fn_farEnough) then { continue };

        if (_bldDist > 0 && {(count (nearestObjects [_cand, ["House","Building"], _bldDist])) > 0}) then { continue };

        private _hs = [_cand, _footR] call _fn_sampleHeightsArr;
        private _mm = [_hs] call _fn_minMax;
        private _dH = (_mm#1) - (_mm#0);

        if (_dH < _bestDH) then { _bestDH = _dH; _best = _cand; };
        if (_dH <= _deltaLimit) exitWith { _best };
    };

    _best
};

private _hqPos = [];

_hqPos = [300, _deltaStrict, 0.85] call _fn_findHQ;
if (_hqPos isEqualTo []) then { _hqPos = [220, _deltaStrict, 0.85] call _fn_findHQ; };
if (_hqPos isEqualTo []) then { _hqPos = [150, _deltaRelax,  0.95] call _fn_findHQ; };
if (_hqPos isEqualTo []) then { _hqPos = [0,   _deltaRelax,  1.05] call _fn_findHQ; };

// Fallback — still constrained to AO
if (_hqPos isEqualTo []) then {
    for "_i" from 1 to 260 do {
        private _cand = [_aoPos, 0, _searchMax, 30, 1, 0.50, 0] call BIS_fnc_findSafePos;
        if (
            [_cand, _footR] call _fn_footprintDry
            && {[_cand] call _fn_insideAO}
            && {(_cand distance2D _aoPos) <= (_aoHardLimit - _footR)}
            && {[_cand] call _fn_farEnough}
        ) exitWith { _hqPos = _cand; };
    };
};

// Last resort — drop farEnough requirement but STILL stay inside AO
if (_hqPos isEqualTo []) then {
    diag_log "[HQ] WARNING: Could not find position 600m from other objectives, dropping distance requirement";
    for "_i" from 1 to 200 do {
        private _cand = [_aoPos, 0, _searchMax, 20, 1, 0.50, 0] call BIS_fnc_findSafePos;
        if (
            [_cand, _footR] call _fn_footprintDry
            && {[_cand] call _fn_insideAO}
            && {(_cand distance2D _aoPos) <= (_aoHardLimit - _footR)}
        ) exitWith { _hqPos = _cand; };
    };
};

if (_hqPos isEqualTo [] || {!([_hqPos, _footR] call _fn_footprintDry)}) exitWith {
    diag_log "[HQ] ERROR: Could not find valid HQ position inside AO, aborting";
};

// FINAL SAFETY CHECK — if somehow still outside AO, abort
if ((_hqPos distance2D _aoPos) > _aoRadius) exitWith {
    diag_log format ["[HQ] ERROR: HQ position %1 is %2m from AO center (limit %3m), aborting", _hqPos, _hqPos distance2D _aoPos, _aoRadius];
};

diag_log format ["[HQ] HQ position found at %1, %2m from AO center (limit %3m)", _hqPos, round (_hqPos distance2D _aoPos), _aoHardLimit];

missionNamespace setVariable ["DYN_HQPos", _hqPos, true];

// Register this objective's position for distance checks
DYN_OBJ_centers pushBack _hqPos;

private _hsFinal = [_hqPos, _footR] call _fn_sampleHeightsArr;
private _mmFinal = [_hsFinal] call _fn_minMax;
private _baseASLNew = (_mmFinal select 0) + _zOffset;

// Hide terrain
{
    if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
        _x setVariable ["DYN_hiddenByAO", true, false];
        _x hideObjectGlobal true;
        DYN_AO_hiddenTerrain pushBack _x;
    };
} forEach (nearestTerrainObjects [_hqPos, ["BUSH","SMALL TREE","TREE","ROCK","ROCKS"], 95, false, true]);

// Task
[
    west,
    _hqTaskId,
    [
        "Enemy command has established a fortified headquarters inside the AO. Kill or capture the enemy officer. If captured, restrain him (ACE) and deliver him to the prison at base.",
        "Attack Enemy HQ",
        ""
    ],
    _hqPos,
    "ASSIGNED",
    1,
    true,
    "attack"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_AO_sideTasks pushBack _hqTaskId;

// =====================================================
// BARRIER CLASSNAMES — for surface snap + disable sim
// =====================================================
private _barrierClasses = [
    "Land_HBarrierWall_corner_F",
    "Land_HBarrierWall6_F",
    "Land_HBarrierWall4_F",
    "Land_HBarrierTower_F"
];

// Prefab placement
private _origCenter = [6949.94, 2664.69];
private _origBaseZ  = 5.76341;

private _fn_rot2D = {
    params ["_x","_y","_deg"];
    private _c = cos _deg;
    private _s = sin _deg;
    [(_x*_c - _y*_s), (_x*_s + _y*_c)]
};

private _fn_rotVec = {
    params ["_v","_deg","_fnRot"];
    private _r = [_v#0, _v#1, _deg] call _fnRot;
    [_r#0, _r#1, (_v param [2,0])]
};

private _fn_place = {
    params ["_class","_origX","_origY","_vecDir","_origZ"];

    private _offX = _origX - (_origCenter#0);
    private _offY = _origY - (_origCenter#1);
    private _rOff = [_offX, _offY, _hqDir] call _fn_rot2D;

    private _newXY = [(_hqPos#0) + (_rOff#0), (_hqPos#1) + (_rOff#1)];

    private _localTerrain = getTerrainHeightASL _newXY;
    private _zRel = _origZ - _origBaseZ;
    private _newASL = [_newXY#0, _newXY#1, _localTerrain + _zRel + _zOffset];

    private _obj = createVehicle [_class, [_newXY#0,_newXY#1,0], [], 0, "CAN_COLLIDE"];
    private _dirRot = [_vecDir, _hqDir, _fn_rot2D] call _fn_rotVec;

    _obj allowDamage false;
    _obj setDamage 0;

    // Check if this is a barrier — snap to surface and disable simulation
    private _isBarrier = (_class in _barrierClasses);

    if (_isBarrier) then {
        // Surface snap: place at terrain + zOffset, let engine handle surface alignment
        private _surfaceZ = getTerrainHeightASL _newXY;
        _obj setPosASL [_newXY#0, _newXY#1, _surfaceZ + _zOffset];
        _obj setVectorDirAndUp [_dirRot, [0,0,1]];
        _obj setVelocity [0,0,0];
        _obj enableSimulationGlobal false;
    } else {
        _obj setPosWorld _newASL;
        _obj setVectorDirAndUp [_dirRot, [0,0,1]];
        _obj setVelocity [0,0,0];
    };

    _obj
};

private _prefab = [
    ["Land_Cargo_HQ_V3_F",         6949.94,2664.69,[0.0347378,0.999396,0], 8.8754],
    ["Land_HBarrierWall_corner_F", 6935.13,2681.13,[-0.998393,0.0566689,0], 5.76641],
    ["Land_HBarrierWall6_F",       6948.95,2681.76,[0,1,0],                 5.76341],
    ["Land_HBarrierTower_F",       6971.08,2671.97,[-0.998637,0.0522004,0], 7.18501],
    ["Land_HBarrierWall6_F",       6940.75,2681.56,[0,1,0],                 5.76341],
    ["Land_HBarrierWall6_F",       6965.33,2682.37,[0,1,0],                 5.76341],
    ["Land_HBarrierWall6_F",       6957.13,2682.17,[0,1,0],                 5.76341],
    ["Land_HBarrierWall_corner_F", 6971.84,2682.46,[0.0724379,0.997373,0],  5.76641],
    ["Land_HBarrierWall4_F",       6972.21,2677.89,[0.999792,-0.020392,0],  5.76991],
    ["Land_HBarrierWall6_F",       6971.67,2656.63,[0.999895,-0.0144754,0], 5.76341],
    ["Land_HBarrierWall6_F",       6971.53,2664.77,[0.999895,-0.0144754,0], 5.76341],
    ["Land_HBarrierWall6_F",       6934.36,2651.25,[-0.997893,0.0648772,0], 5.76341],
    ["Land_HBarrierTower_F",       6940.6, 2646.06,[0.0397021,0.999212,0],  7.18501],
    ["Land_HBarrierWall6_F",       6957.94,2649.73,[-0.0831516,-0.996537,0],5.76341],
    ["Land_HBarrierWall6_F",       6966.03,2649.62,[-0.0831516,-0.996537,0],5.76341],
    ["Land_HBarrierWall_corner_F", 6971.61,2649.96,[0.998788,-0.0492098,0], 5.76641],
    ["Land_HBarrierWall6_F",       6948.03,2644.95,[-0.0831516,-0.996537,0],5.76341],
    ["Land_HBarrierWall6_F",       6934.86,2674.14,[-0.996666,0.0815886,0], 5.76341],
    ["Land_HBarrierWall6_F",       6934.63,2665.96,[-0.996666,0.0815886,0], 5.76341],
    ["Land_HBarrierWall_corner_F", 6954.16,2644.92,[0.998788,-0.0492098,0], 5.76641],
    ["Land_HBarrierWall_corner_F", 6934.54,2645.55,[-0.0183327,-0.999832,0],5.76641],
    ["Land_Cargo_Patrol_V3_F",     6965.57,2656.12,[0,1,0],                 9.905],
    ["Land_Cargo_Patrol_V3_F",     6940.92,2675.47,[0.999946,-0.0103506,0], 9.905]
];

private _hqBuilding = objNull;
private _spawnedObjs = [];

{
    _x params ["_cls","_xw","_yw","_vec","_z"];
    private _o = [_cls,_xw,_yw,_vec,_z] call _fn_place;
    DYN_AO_objects pushBack _o;
    _spawnedObjs pushBack _o;
    if (_cls isEqualTo "Land_Cargo_HQ_V3_F") then { _hqBuilding = _o; };
} forEach _prefab;

[_spawnedObjs, _barrierClasses] spawn {
    params ["_objs", "_barriers"];
    sleep 2;
    {
        if (!isNull _x) then {
            // Only re-enable damage on non-barrier objects; barriers stay allowDamage false
            if !((typeOf _x) in _barriers) then {
                _x allowDamage true;
            };
        };
    } forEach _objs;
};

if (isNull _hqBuilding) exitWith {};

// OFFICER SPAWN
private _posArr = [_hqBuilding] call BIS_fnc_buildingPositions;
_posArr = _posArr select { !(_x isEqualTo [0,0,0]) };

if (_posArr isEqualTo []) then {
    private _bldPos = getPosATL _hqBuilding;
    for "_i" from 0 to 7 do { _posArr pushBack (_bldPos getPos [3 + random 5, _i * 45]); };
};

private _sorted = [_posArr, [], { _x select 2 }, "ASCEND"] call BIS_fnc_sortBy;
private _safePool = _sorted select [0, ((count _sorted) min 12) max 1];

if (_safePool isEqualTo []) then {
    _safePool = [_hqPos, _hqPos getPos [3, 0], _hqPos getPos [3, 90], _hqPos getPos [3, 180]];
};

private _officerGrp = createGroup east;
DYN_AO_enemyGroups pushBack _officerGrp;
_officerGrp setBehaviour "AWARE";
_officerGrp setCombatMode "RED";

private _offPos = selectRandom _safePool;
if (isNil "_offPos" || {_offPos isEqualTo []}) then { _offPos = _hqPos getPos [5, random 360]; };

private _officer = _officerGrp createUnit [_officerClass, _offPos, [], 0, "NONE"];
if (isNull _officer) then { _officer = _officerGrp createUnit ["O_officer_F", _offPos, [], 0, "NONE"]; };
if (isNull _officer) then { _officer = _officerGrp createUnit ["O_Soldier_F", _offPos, [], 0, "NONE"]; };
if (isNull _officer) exitWith {};

_officer setPosATL _offPos;
_officer setDir (random 360);
_officer disableAI "PATH";
_officer setUnitPos "UP";
_officer allowFleeing 0;

_officer setVariable ["hqTaskId", _hqTaskId, true];
_officer setVariable ["hqCaptured", false, true];
_officer setVariable ["hqTaskDone", false, true];
_officer setVariable ["DYN_HQPos", _hqPos, true];
_officer setVariable ["DYN_reinforcementTrucks", _reinforcementTrucks, true];
_officer setVariable ["DYN_captureReinforcementChance", _captureReinforcementChance, true];

DYN_AO_enemies pushBack _officer;

// KILLED = task completes + 100% reinforcements
_officer addEventHandler ["Killed", {
    params ["_unit"];

    if (_unit getVariable ["hqTaskDone", false]) exitWith {};
    _unit setVariable ["hqTaskDone", true, true];

    if (_unit getVariable ["DYN_prisonDelivered", false]) exitWith {};

    private _tid = _unit getVariable ["hqTaskId", ""];
    if (_tid != "") then { [_tid, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, true]; };

    ["TaskSucceeded", ["Officer Neutralized", "Enemy HQ leadership removed."]]
        remoteExecCall ["BIS_fnc_showNotification", 0];

    private _hqPos = _unit getVariable ["DYN_HQPos", [0,0,0]];
    private _trucks = _unit getVariable ["DYN_reinforcementTrucks", 2];
    [_hqPos, _trucks] spawn DYN_fnc_spawnHQReinforcements;
}];

// CAPTURED = 40% CHANCE (task completes when delivered by prison system)
if (!isNil "DYN_fnc_registerAceCapture") then {
    [_officer, _hqTaskId, "Enemy Officer", "hqCaptured"] call DYN_fnc_registerAceCapture;

    [_officer, _hqPos, _reinforcementTrucks, _captureReinforcementChance] spawn {
        params ["_officer", "_hqPos", "_trucks", "_chance"];

        waitUntil {
            sleep 1;
            isNull _officer
            || {!alive _officer}
            || {_officer getVariable ["hqCaptured", false]}
            || {_officer getVariable ["ace_captives_isHandcuffed", false]}
            || {_officer getVariable ["ACE_isHandcuffed", false]}
        };

        if (isNull _officer || !alive _officer) exitWith {};
        if (_officer getVariable ["hqTaskDone", false]) exitWith {};

        if ((random 1) < _chance) then {
            [_hqPos, _trucks] spawn DYN_fnc_spawnHQReinforcements;
        } else {
            ["TaskUpdated", ["Officer Captured", "No enemy reinforcements detected."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
        };
    };
};

// Inside defenders
private _insideGrp = createGroup east;
DYN_AO_enemyGroups pushBack _insideGrp;
_insideGrp setBehaviour "AWARE";
_insideGrp setCombatMode "RED";

for "_i" from 1 to (10 + floor (random 5)) do {
    private _p = selectRandom _safePool;
    if (isNil "_p" || {_p isEqualTo []}) then { _p = _hqPos getPos [5, random 360]; };

    private _u = _insideGrp createUnit [selectRandom _defenderPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u disableAI "PATH";
        _u setUnitPos (selectRandom ["UP","MIDDLE"]);
        _u allowFleeing 0;
        DYN_AO_enemies pushBack _u;
    };
};

// Outside defenders
private _outerGrp = createGroup east;
DYN_AO_enemyGroups pushBack _outerGrp;
_outerGrp setBehaviour "AWARE";
_outerGrp setCombatMode "RED";

for "_i" from 1 to (14 + floor (random 7)) do {
    private _p = [_hqPos, 25, 200, 8, 0, 0.6, 0] call BIS_fnc_findSafePos;
    if (_p isEqualTo [0,0,0] || {surfaceIsWater _p}) then { _p = _hqPos getPos [50, random 360]; };

    private _u = _outerGrp createUnit [selectRandom _infantryPool, _p, [], 0, "FORM"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        DYN_AO_enemies pushBack _u;
    };
};

for "_w" from 1 to 5 do {
    private _wpPos = [_hqPos, 40, 240, 10, 0, 0.6, 0] call BIS_fnc_findSafePos;
    if (_wpPos isEqualTo [0,0,0]) then { _wpPos = _hqPos getPos [100, _w * 72]; };
    private _wp = _outerGrp addWaypoint [_wpPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
};
(_outerGrp addWaypoint [_hqPos, 0]) setWaypointType "CYCLE";

// Tower garrisons
private _towerGrp = createGroup east;
DYN_AO_enemyGroups pushBack _towerGrp;
_towerGrp setBehaviour "AWARE";
_towerGrp setCombatMode "RED";

private _patrolTowers = nearestObjects [_hqPos, ["Land_Cargo_Patrol_V3_F"], 250];
private _hbTowers = nearestObjects [_hqPos, ["Land_HBarrierTower_F"], 250];

private _fn_garrisonTower = {
    params ["_towerObj", "_units", "_pool"];
    private _tPosArr = [_towerObj] call BIS_fnc_buildingPositions;
    if (_tPosArr isEqualTo []) exitWith {};
    private _sortedP = [_tPosArr, [], { _x select 2 }, "DESCEND"] call BIS_fnc_sortBy;
    private _use = (_units min (count _sortedP));
    for "_i" from 0 to (_use - 1) do {
        private _p = _sortedP select _i;
        private _u = _towerGrp createUnit [selectRandom _pool, _p, [], 0, "NONE"];
        if (!isNull _u) then {
            _u disableAI "PATH";
            _u setUnitPos "UP";
            _u allowFleeing 0;
            DYN_AO_enemies pushBack _u;
        };
    };
};

{ [_x, 3, _towerPool] call _fn_garrisonTower; } forEach _patrolTowers;
{ [_x, 2, _towerPool] call _fn_garrisonTower; } forEach _hbTowers;
