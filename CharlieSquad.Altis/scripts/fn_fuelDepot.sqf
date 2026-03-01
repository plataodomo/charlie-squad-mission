/*
    scripts\fn_fuelDepot.sqf
    v3: Fixed target settling — no more random explosions
    - Fuel pods now get full vehicle-level settling (they explode too)
    - Uses surfaceNormal instead of forcing [0,0,1] on slopes
    - Higher terrain offset prevents ground clipping
    - Staggered sim enable so objects don't collide with each other
    - Trucks stay at fuel 0 (they're destruction targets, not refuel stations)
*/

params ["_pos", "_aoRadius"];
if (!isServer) exitWith {};

private _sniperClass = "CUP_O_RU_Sniper_Ratnik_Autumn";

private _guardPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn"
];

private _towerPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_MG_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn"
];

private _depotTaskId = format ["task_depot_%1", round (diag_tickTime * 1000)];

if (isNil "DYN_AO_hiddenTerrain") then { DYN_AO_hiddenTerrain = []; };
if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_AO_sideTasks") then { DYN_AO_sideTasks = []; };
if (isNil "DYN_OBJ_centers") then { DYN_OBJ_centers = []; };
if (isNil "DYN_AO_hiddenObjectives") then { DYN_AO_hiddenObjectives = []; };

// -----------------------------------------------------
// Wait briefly for HQ pos
// -----------------------------------------------------
private _hqPos = missionNamespace getVariable ["DYN_HQPos", []];
private _tEnd = diag_tickTime + 20;
waitUntil {
    sleep 0.25;
    _hqPos = missionNamespace getVariable ["DYN_HQPos", []];
    !(_hqPos isEqualTo []) || (diag_tickTime > _tEnd)
};

private _minFromHQ  = 750;
private _minFromObj = 600;
private _aoHardLimit = _aoRadius * 0.85;

// -----------------------------------------------------
// Position finding
// -----------------------------------------------------
private _compoundR = 45;
private _maxDeltaH = 4.5;
private _flatGrad  = 0.35;

private _fn_sampleHeights = {
    params ["_p", "_r"];
    private _hs = [getTerrainHeightASL _p];
    { _hs pushBack (getTerrainHeightASL (_p getPos [_r, _x])); } forEach [0,45,90,135,180,225,270,315];
    [selectMin _hs, selectMax _hs]
};

private _fn_farEnough = {
    params ["_p"];
    private _tooClose = false;
    private _hqP = missionNamespace getVariable ["DYN_HQPos", []];
    if !(_hqP isEqualTo []) then {
        if ((_p distance2D _hqP) < _minFromHQ) then { _tooClose = true; };
    };
    if (!_tooClose) then {
        {
            if (_x isEqualTo [] || {_x isEqualTo [0,0,0]}) then { continue };
            if ((_p distance2D _x) < _minFromObj) then { _tooClose = true; };
        } forEach DYN_OBJ_centers;
    };
    !_tooClose
};

private _fn_insideAO = {
    params ["_p"];
    if (_p isEqualTo [] || {_p isEqualTo [0,0,0]}) exitWith { false };
    (_p distance2D _pos) <= _aoHardLimit
};

private _fn_goodDepotSite = {
    params ["_p"];
    if (_p isEqualTo [0,0,0]) exitWith {false};
    if (surfaceIsWater _p) exitWith {false};
    if !([_p] call _fn_insideAO) exitWith {false};
    if !([_p] call _fn_farEnough) exitWith {false};
    if ((_p distance2D _pos) > (_aoHardLimit - _compoundR)) exitWith {false};
    private _flat = _p isFlatEmpty [_compoundR, -1, _flatGrad, _compoundR, 0, false, objNull];
    if (_flat isEqualTo []) exitWith {false};
    private _hh = [_p, _compoundR] call _fn_sampleHeights;
    ((_hh#1) - (_hh#0)) <= _maxDeltaH
};

private _depotPos = [];
private _depotDir = random 360;

private _searchMax = (_aoHardLimit - _compoundR) max 100;
private _minDist = 150;
private _maxDist = _searchMax;

if (_maxDist < (_minDist + 100)) then {
    _minDist = _searchMax * 0.3;
    _maxDist = _searchMax;
};

for "_attempt" from 1 to 260 do {
    private _testPos = [_pos, _minDist, _maxDist, 20, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _testPos) then { continue };
    if ((count (nearestObjects [_testPos, ["House","Building"], 80])) > 0) then { continue };
    if ((count (_testPos nearRoads 40)) > 0) then { continue };
    if ([_testPos] call _fn_goodDepotSite) exitWith { _depotPos = _testPos; };
};

if (_depotPos isEqualTo []) then {
    for "_attempt" from 1 to 320 do {
        private _testPos = [_pos, 50, _searchMax, 15, 0, 0.45, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _testPos) then { continue };
        if ((count (nearestObjects [_testPos, ["House","Building"], 60])) > 0) then { continue };
        if ((count (_testPos nearRoads 25)) > 0) then { continue };
        if ([_testPos] call _fn_goodDepotSite) exitWith { _depotPos = _testPos; };
    };
};

if (_depotPos isEqualTo [] || {surfaceIsWater _depotPos}) then {
    diag_log "[FUEL] WARNING: Dropping 600m objective distance requirement";
    for "_i" from 1 to 500 do {
        private _cand = [_pos, 0, _searchMax, 10, 0, 0.50, 0] call BIS_fnc_findSafePos;
        if (_cand isEqualTo [0,0,0] || {surfaceIsWater _cand}) then { continue };
        if !([_cand] call _fn_insideAO) then { continue };
        if ((count (nearestObjects [_cand, ["House","Building"], 50])) > 0) then { continue };
        if ((count (_cand nearRoads 20)) > 0) then { continue };
        _depotPos = _cand;
        break;
    };
};

if (_depotPos isEqualTo [] || _depotPos isEqualTo [0,0,0]) exitWith {
    diag_log "ERROR: Fuel Depot Objective failed to spawn - No suitable position found.";
};

if ((_depotPos distance2D _pos) > _aoRadius) exitWith {
    diag_log format ["[FUEL] ERROR: Depot position %1 is %2m from AO center (limit %3m), aborting", _depotPos, _depotPos distance2D _pos, _aoRadius];
};

diag_log format ["[FUEL] Depot position found at %1, %2m from AO center (limit %3m)", _depotPos, round (_depotPos distance2D _pos), _aoHardLimit];

DYN_OBJ_centers pushBack _depotPos;

// -----------------------------------------------------
// Task
// -----------------------------------------------------
[
    west,
    _depotTaskId,
    [
        "Locate and destroy the enemy fuel depot. Destroy all fuel trucks and fuel containers.",
        "Destroy Fuel Depot",
        ""
    ],
    _depotPos,
    "CREATED",
    1,
    true,
    "destroy"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_AO_sideTasks pushBack _depotTaskId;
DYN_AO_hiddenObjectives pushBack [_depotTaskId, "Fuel Depot", _depotPos];
publicVariable "DYN_AO_hiddenObjectives";

// Hide terrain
{
    if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
        _x setVariable ["DYN_hiddenByAO", true, false];
        _x hideObjectGlobal true;
        DYN_AO_hiddenTerrain pushBack _x;
    };
} forEach (nearestTerrainObjects [_depotPos, ["BUSH","SMALL TREE","TREE","ROCK","ROCKS"], 45, false, true]);

// -----------------------------------------------------
// Placement helpers
// -----------------------------------------------------
private _origCenter = [23351.5, 17381.3];

private _barrierClasses = [
    "Land_HBarrier_Big_F"
];

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

private _fn_placeExportGround = {
    params [
        "_class", "_origX", "_origY",
        "_vecDir", "_origZASL",
        ["_alignUpToTerrain", true],
        ["_special", "CAN_COLLIDE"]
    ];

    private _offX = _origX - (_origCenter#0);
    private _offY = _origY - (_origCenter#1);

    private _rOff  = [_offX, _offY, _depotDir] call _fn_rot2D;
    private _newXY = [(_depotPos#0) + (_rOff#0), (_depotPos#1) + (_rOff#1)];

    private _origTerr = getTerrainHeightASL [_origX, _origY];
    private _zRel     = _origZASL - _origTerr;

    private _newTerr  = getTerrainHeightASL _newXY;
    private _newASL   = [_newXY#0, _newXY#1, (_newTerr + _zRel)];

    private _obj = createVehicle [_class, [_newXY#0, _newXY#1, 0], [], 0, _special];

    private _dirRot = [_vecDir, _depotDir, _fn_rot2D] call _fn_rotVec;

    private _isBarrier = (_class in _barrierClasses);

    if (_isBarrier) then {
        private _surfaceZ = getTerrainHeightASL _newXY;
        _obj setPosASL [_newXY#0, _newXY#1, _surfaceZ + 0.1];
        private _up = surfaceNormal _newXY;
        _obj setVectorDirAndUp [_dirRot, _up];
        _obj setVelocity [0,0,0];
        _obj allowDamage false;
        _obj setDamage 0;
        _obj enableSimulationGlobal false;
    } else {
        private _up = if (_alignUpToTerrain) then { surfaceNormal _newXY } else { [0,0,1] };
        _obj setPosWorld _newASL;
        _obj setVectorDirAndUp [_dirRot, _up];
        _obj setVelocity [0,0,0];

        [_obj, _newASL, _dirRot, _up] spawn {
            params ["_o","_pW","_d","_u"];
            sleep 0.1;
            if (!isNull _o) then {
                _o setPosWorld _pW;
                _o setVectorDirAndUp [_d, _u];
                _o setVelocity [0,0,0];
            };
        };
    };

    _obj
};

// -----------------------------------------------------
// TARGET SETTLING v3 — simple, no physics fighting
// Place on terrain, sim OFF, wait, enable sim,
// just zero velocity + hitpoints, NO repositioning.
// Let gravity do its thing — a 0.5m drop won't hurt.
// -----------------------------------------------------
private _fn_settleTarget = {
    params ["_obj", ["_staggerDelay", 0]];

    _obj allowDamage false;
    _obj enableSimulationGlobal false;
    _obj setDamage 0;
    _obj setVelocity [0,0,0];

    if (_obj isKindOf "LandVehicle") then {
        _obj setFuel 0;
        _obj lock 2;
    };

    private _hpData = getAllHitPointsDamage _obj;
    if !(_hpData isEqualTo []) then {
        { _obj setHitPointDamage [_x, 0, false]; } forEach (_hpData#0);
    };

    [_obj, _staggerDelay] spawn {
        params ["_v", "_delay"];
        if (isNull _v) exitWith {};

        if (_delay > 0) then { sleep _delay; };

        // Place on terrain with surfaceNormal — sits naturally on slopes
        private _posXY = getPos _v;
        private _dir = vectorDir _v;
        private _upVec = surfaceNormal _posXY;
        private _terrZ = getTerrainHeightASL _posXY;

        _v setPosASL [_posXY#0, _posXY#1, _terrZ + 0.35];
        _v setVectorDirAndUp [_dir, _upVec];
        _v setVelocity [0,0,0];

        // Let engine register the position
        sleep 2;
        if (isNull _v) exitWith {};

        // Cache hitpoint names once (avoids calling getAllHitPointsDamage repeatedly)
        _v setDamage 0;
        private _hpData = getAllHitPointsDamage _v;
        private _hpNames = if (_hpData isEqualTo []) then { [] } else { _hpData#0 };
        if !(_hpNames isEqualTo []) then {
            { _v setHitPointDamage [_x, 0, false]; } forEach _hpNames;
        };

        // Enable sim — gravity will settle it the last few cm
        _v enableSimulationGlobal true;
        _v setVelocity [0,0,0];

        // Zero velocity and wipe damage for 5 seconds, reduced to 10 iterations at 0.5s
        for "_i" from 1 to 10 do {
            sleep 0.5;
            if (isNull _v) exitWith {};
            _v setVelocity [0,0,0];
            _v setDamage 0;
            { _v setHitPointDamage [_x, 0, false]; } forEach _hpNames;
        };

        // Final cleanup
        sleep 2;
        if (isNull _v) exitWith {};

        _v setVelocity [0,0,0];
        _v setDamage 0;
        { _v setHitPointDamage [_x, 0, false]; } forEach _hpNames;

        if (_v isKindOf "LandVehicle") then {
            _v lock 0;
        };

        // NOW enable damage — object is fully at rest
        _v allowDamage true;

        diag_log format ["[FUEL] Target %1 settled at %2", typeOf _v, getPos _v];
    };
};

// -----------------------------------------------------
// STRUCTURE
// -----------------------------------------------------
private _protectedClasses = [
    "Land_Shed_Small_F",
    "Land_Shed_Big_F",
    "Land_Cargo_Tower_V3_F"
];

private _struct = [
    ["Land_Cargo_Tower_V3_F", 23343.3,17370.4, [0.120445,-0.99272,0], 16.0762, false],

    ["Land_HBarrier_Big_F", 23338.8,17360.8, [ 0.0689602,-0.997619,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23347.1,17361.6, [ 0.0689602,-0.997619,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23355.4,17362.4, [ 0.0689602,-0.997619,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23363.8,17363.4, [ 0.0689602,-0.997619,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23371.7,17364.3, [ 0.0689602,-0.997619,0], 4.4, true],

    ["Land_HBarrier_Big_F", 23375.2,17367.9, [-0.997448,-0.0714004,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23374.5,17376.0, [-0.999426,-0.033868,0],  4.4, true],
    ["Land_HBarrier_Big_F", 23373.9,17384.2, [-0.997448,-0.0714004,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23373.2,17392.6, [-0.997448,-0.0714004,0], 4.4, true],

    ["Land_HBarrier_Big_F", 23359.4,17394.6, [ 0.0689602,-0.997619,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23367.8,17395.4, [ 0.0689602,-0.997619,0], 4.4, true],

    ["Land_HBarrier_Big_F", 23335.1,17363.6, [-0.99584,-0.0911162,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23333.9,17371.9, [-0.99584,-0.0911162,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23332.8,17380.3, [-0.99584,-0.0911162,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23331.8,17388.7, [-0.99584,-0.0911162,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23330.8,17397.0, [-0.99584,-0.0911162,0], 4.4, true],

    ["Land_HBarrier_Big_F", 23335.6,17400.7, [ 0.0689602,-0.997619,0], 4.4, true],
    ["Land_HBarrier_Big_F", 23341.9,17401.3, [ 0.0689602,-0.997619,0], 4.4, true],

    ["Land_HBarrier_Big_F", 23354.1,17367.4, [-0.999591,-0.028612,0],  4.4, true],
    ["Land_HBarrier_Big_F", 23355.7,17399.4, [-0.999591,-0.028612,0],  4.4, true],
    ["Land_HBarrier_Big_F", 23345.4,17396.7, [-0.999591,-0.028612,0],  4.4, true],
    ["Land_HBarrier_Big_F", 23338.4,17378.0, [-0.142454, 0.989801,0],  4.4, true],
    ["Land_HBarrier_Big_F", 23346.8,17379.3, [-0.104767, 0.994497,0],  4.4, true],

    ["Land_Shed_Small_F", 23368.5,17381.6, [ 0.0923531,-0.995726,0], 5.32135, true],
    ["Land_Shed_Big_F",   23338.9,17389.7, [-0.104077,  0.994569,0], 6.56814, true],
    ["Land_BarGate_F",    23350.5,17403.6, [-0.103099,  0.994671,0], 7.24028, true]
];

private _tower = objNull;
private _structObjs = [];
private _protectedObjs = [];

{
    _x params ["_cls","_xw","_yw","_vec","_zAsl","_align"];
    private _o = [_cls, _xw, _yw, _vec, _zAsl, _align, "CAN_COLLIDE"] call _fn_placeExportGround;

    if !(_cls in _barrierClasses) then {
        _o allowDamage false;
        _o setDamage 0;
    };

    _structObjs pushBack _o;
    DYN_AO_objects pushBack _o;

    if (_cls isEqualTo "Land_Cargo_Tower_V3_F") then { _tower = _o; };

    if (_cls in _protectedClasses) then {
        _protectedObjs pushBack _o;
    };
} forEach _struct;

[_structObjs, _protectedObjs, _barrierClasses] spawn {
    params ["_objs", "_protected", "_barriers"];
    sleep 2;
    {
        if (!isNull _x) then {
            private _type = typeOf _x;
            if (!(_type in _barriers) && !(_x in _protected)) then {
                _x allowDamage true;
            };
        };
    } forEach _objs;
};

// -----------------------------------------------------
// TARGETS — staggered settling, all treated equally
// FIX: Pods and trucks BOTH get full settling treatment
// FIX: Each target gets a stagger delay so they don't
//      collide with each other during sim enable
// -----------------------------------------------------
private _depotTargets = [];

private _podSpots = [
    ["Land_Pod_Heli_Transport_04_fuel_F", 23341.0,17397.3, [ 0.994823,  0.101622,0], 4.5098],
    ["Land_Pod_Heli_Transport_04_fuel_F", 23341.5,17393.4, [ 0.992603,  0.121408,0], 4.5098],
    ["Land_Pod_Heli_Transport_04_fuel_F", 23369.6,17389.9, [ 0.0959322,-0.995388,0], 4.5098],
    ["Land_Pod_Heli_Transport_04_fuel_F", 23365.3,17389.3, [ 0.0959322,-0.995388,0], 4.5098],
    ["Land_Pod_Heli_Transport_04_fuel_F", 23368.8,17374.4, [-0.999069, -0.0431304,0], 4.5098],
    ["Land_Pod_Heli_Transport_04_fuel_F", 23369.2,17370.9, [-0.996757, -0.0804717,0], 4.5098],
    ["Land_Pod_Heli_Transport_04_fuel_F", 23368.5,17377.8, [-0.998849, -0.0479624,0], 4.5098]
] call BIS_fnc_arrayShuffle;

private _truckSpots = [
    ["CUP_O_Kamaz_6396_fuel_RUS_M", 23335.5,17392.6, [ 0.131387,-0.991331,0],  5.33867],
    ["CUP_O_Kamaz_6396_fuel_RUS_M", 23365.4,17382.0, [-0.996611,-0.0822577,0], 5.33867],
    ["CUP_O_Kamaz_6396_fuel_RUS_M", 23341.9,17382.0, [ 0.99145,  0.130486,0],  5.33867]
] call BIS_fnc_arrayShuffle;

private _podCount   = (4 + floor (random 4)) min (count _podSpots);
private _truckCount = (2 + floor (random 2)) min (count _truckSpots);

private _targetIndex = 0;

for "_i" from 0 to (_podCount - 1) do {
    (_podSpots select _i) params ["_cls","_xw","_yw","_vec","_zAsl"];
    private _pod = [_cls, _xw, _yw, _vec, _zAsl, true, "CAN_COLLIDE"] call _fn_placeExportGround;
    // FIX: Pods get full settling (they CAN explode) + stagger delay
    [_pod, _targetIndex * 0.5] call _fn_settleTarget;
    DYN_AO_objects pushBack _pod;
    _depotTargets pushBack _pod;
    _targetIndex = _targetIndex + 1;
};

for "_i" from 0 to (_truckCount - 1) do {
    (_truckSpots select _i) params ["_cls","_xw","_yw","_vec","_zAsl"];
    private _truck = [_cls, _xw, _yw, _vec, _zAsl, false, "CAN_COLLIDE"] call _fn_placeExportGround;
    // FIX: Stagger delay continues from pods
    [_truck, _targetIndex * 0.5] call _fn_settleTarget;
    DYN_AO_objects pushBack _truck;
    _depotTargets pushBack _truck;
    _targetIndex = _targetIndex + 1;
};

// -----------------------------------------------------
// SNIPERS
// -----------------------------------------------------
private _sniperGrp = createGroup east;
DYN_AO_enemyGroups pushBack _sniperGrp;
_sniperGrp setBehaviour "AWARE";
_sniperGrp setCombatMode "RED";

private _towerPositions = if (!isNull _tower) then { [_tower] call BIS_fnc_buildingPositions } else { [] };
_towerPositions = _towerPositions select { !(_x isEqualTo [0,0,0]) };
_towerPositions = [_towerPositions, [], { _x#2 }, "DESCEND"] call BIS_fnc_sortBy;
if (_towerPositions isEqualTo []) then { _towerPositions = [getPosATL _tower]; };

private _sniperCount = 3 + floor (random 2);
private _usedTowerPositions = [];

for "_i" from 0 to (_sniperCount - 1) do {
    private _p = _towerPositions select (_i min ((count _towerPositions) - 1));
    private _sn = _sniperGrp createUnit [_sniperClass, _p, [], 0, "NONE"];
    _sn setPosATL _p;
    _sn disableAI "PATH";
    _sn setUnitPos "UP";
    _sn setSkill 0.55;
    _sn allowFleeing 0;
    _sn setDir (random 360);
    DYN_AO_enemies pushBack _sn;
    _usedTowerPositions pushBack _p;
};

// -----------------------------------------------------
// TOWER GUARDS
// -----------------------------------------------------
if (!isNull _tower) then {
    private _towerGuardGrp = createGroup east;
    DYN_AO_enemyGroups pushBack _towerGuardGrp;
    _towerGuardGrp setBehaviour "AWARE";
    _towerGuardGrp setCombatMode "RED";

    private _allTowerPos = [_tower] call BIS_fnc_buildingPositions;
    _allTowerPos = _allTowerPos select {
        !(_x isEqualTo [0,0,0])
        && {!(_x in _usedTowerPositions)}
    };

    private _towerGuardCount = (6 + floor (random 5)) min (count _allTowerPos);
    private _shuffled = _allTowerPos call BIS_fnc_arrayShuffle;

    for "_i" from 0 to (_towerGuardCount - 1) do {
        private _p = _shuffled select _i;
        private _u = _towerGuardGrp createUnit [selectRandom _towerPool, _p, [], 0, "NONE"];
        _u setPosATL _p;
        _u disableAI "PATH";
        _u setUnitPos "UP";
        _u allowFleeing 0;
        _u setSkill (0.40 + random 0.15);
        _u setDir (random 360);
        DYN_AO_enemies pushBack _u;
    };

    diag_log format ["[FUEL] Spawned %1 snipers + %2 tower guards on Land_Cargo_Tower_V3_F", _sniperCount, _towerGuardCount];
};

// -----------------------------------------------------
// GROUND PATROLS / GUARDS
// -----------------------------------------------------
private _guardGrp = createGroup east;
DYN_AO_enemyGroups pushBack _guardGrp;
_guardGrp setBehaviour "AWARE";
_guardGrp setCombatMode "RED";
_guardGrp setSpeedMode "LIMITED";

private _guardCount = 10 + floor (random 6);
for "_i" from 1 to _guardCount do {
    private _p = [_depotPos, 10, 65, 6, 0, 0.6, 0] call BIS_fnc_findSafePos;
    if (_p isEqualTo [0,0,0] || {surfaceIsWater _p}) then { _p = _depotPos getPos [25 + random 30, random 360]; };
    private _u = _guardGrp createUnit [selectRandom _guardPool, _p, [], 0, "FORM"];
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

for "_w" from 1 to 6 do {
    private _wpPos = [_depotPos, 25, 140, 10, 0, 0.6, 0] call BIS_fnc_findSafePos;
    if (_wpPos isEqualTo [0,0,0]) then { _wpPos = _depotPos getPos [80, _w * 60]; };
    private _wp = _guardGrp addWaypoint [_wpPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
};
(_guardGrp addWaypoint [_depotPos, 0]) setWaypointType "CYCLE";

// -----------------------------------------------------
// COMPLETION CHECK
// -----------------------------------------------------
private _targetsKey = format ["DYN_depotTargets_%1", _depotTaskId];
missionNamespace setVariable [_targetsKey, _depotTargets, false];

{
    _x setVariable ["depotTaskId", _depotTaskId, true];
    _x addEventHandler ["Killed", {
        params ["_killed"];
        private _tid = _killed getVariable ["depotTaskId", ""];
        if (_tid isEqualTo "") exitWith {};
        private _key = format ["DYN_depotTargets_%1", _tid];
        private _targets = missionNamespace getVariable [_key, []];
        if (_targets isEqualTo []) exitWith {};
        if (({ !isNull _x && alive _x } count _targets) == 0) then {
            [_tid, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        };
    }];
} forEach _depotTargets;

diag_log format ["[FUEL] Depot spawned at %1, %2m from AO center, with %3 pods, %4 trucks, snipers+guards on tower", _depotPos, round (_depotPos distance2D _pos), _podCount, _truckCount];
