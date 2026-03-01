/*
    scripts\fn_aaPits.sqf
    CUP RUSSIAN AA - Tunguska
    FIX v2: Radio tower avoidance + terrain embedding prevention
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

diag_log "[AA] SPAWNING AA PITS (CUP Russian - Tunguska)";

private _aaClass = "CUP_O_2S6_RU";
private _crewClass = "CUP_O_RU_Crew_Ratnik_Autumn";

private _pitCount = 4 + floor (random 5);

missionNamespace setVariable ["DYN_AA_remaining", _pitCount, true];

if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_AO_enemyVehs") then { DYN_AO_enemyVehs = []; };
if (isNil "DYN_AO_hiddenTerrain") then { DYN_AO_hiddenTerrain = []; };
if (isNil "DYN_AO_active") then { DYN_AO_active = true; };
if (isNil "DYN_OBJ_centers") then { DYN_OBJ_centers = []; };
if (isNil "DYN_radioTowerPositions") then { DYN_radioTowerPositions = []; };

private _minFromObj = 600;
private _minFromRadioTower = 80;  // FIX: Exclusion radius from radio towers

private _fn_farEnough = {
    params ["_p"];
    private _ok = true;
    {
        if (!(_x isEqualTo []) && {!(_x isEqualTo [0,0,0])}) then {
            if ((_p distance2D _x) < _minFromObj) then { _ok = false; };
        };
    } forEach DYN_OBJ_centers;
    _ok
};

// FIX: Check distance from radio towers
private _fn_farFromRadioTowers = {
    params ["_p"];
    private _ok = true;
    {
        if ((_p distance2D _x) < _minFromRadioTower) exitWith { _ok = false; };
    } forEach DYN_radioTowerPositions;
    _ok
};

private _fn_dirFromVec = {
    params ["_v"];
    private _d = (_v select 0) atan2 (_v select 1);
    if (_d < 0) then { _d = _d + 360 };
    _d
};

// =====================================================
// Comprehensive terrain flatness check
// =====================================================
private _fn_isFlat = {
    params ["_pos", ["_radius", 14], ["_maxGradient", 0.10]];
    private _centerZ = getTerrainHeightASL _pos;
    private _ok = true;

    {
        private _dir = _x;
        {
            private _dist = _x;
            private _checkPos = _pos getPos [_dist, _dir];
            private _edgeZ = getTerrainHeightASL _checkPos;
            private _gradient = abs(_edgeZ - _centerZ) / _dist;
            if (_gradient > _maxGradient) exitWith { _ok = false };
        } forEach [4, 8, 12, _radius];
        if (!_ok) exitWith {};
    } forEach [0, 45, 90, 135, 180, 225, 270, 315];

    if (_ok) then {
        {
            private _checkPos = _pos getPos [_radius, _x];
            private _z = getTerrainHeightASL _checkPos;
            if ((_z - _centerZ) > 1.2) exitWith { _ok = false };
        } forEach [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];
    };

    _ok
};

// =====================================================
// FIX: Get highest terrain height across vehicle footprint
// Samples center + 12 points around it at vehicle radius
// Returns the MAX height so vehicle sits ON TOP of terrain
// instead of sinking into the high side on uneven ground
// =====================================================
private _fn_getFootprintMaxASL = {
    params ["_pos", ["_sampleRadius", 6]];
    private _maxZ = getTerrainHeightASL _pos;

    // Sample 12 points around the vehicle footprint
    {
        private _samplePos = _pos getPos [_sampleRadius, _x];
        private _z = getTerrainHeightASL _samplePos;
        if (_z > _maxZ) then { _maxZ = _z; };
    } forEach [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];

    // Also check close ring (3m) for immediate terrain bumps
    {
        private _samplePos = _pos getPos [3, _x];
        private _z = getTerrainHeightASL _samplePos;
        if (_z > _maxZ) then { _maxZ = _z; };
    } forEach [0, 90, 180, 270];

    _maxZ
};

// Barrier prefab — these spawn with sim OFF and never interact with the vehicle
private _origCenter = [697.108, 5033.89];
private _prefab = [
    ["Land_HBarrier_Big_F", 701.198, 5032.71, [0.999923, -0.0124318, 0], 0],
    ["Land_HBarrier_Big_F", 692.724, 5032.57, [0.999923, -0.0124318, 0], 0],
    ["Land_HBarrier_Big_F", 692.703, 5032.58, [0.999923, -0.0124318, 0], 1.05],
    ["Land_HBarrier_Big_F", 701.290, 5032.65, [0.999923, -0.0124318, 0], 1.10],
    ["Land_HBarrier_Big_F", 697.108, 5027.19, [-0.0212676, -0.999774, 0], 0],
    ["Land_HBarrier_Big_F", 697.077, 5027.23, [-0.0212676, -0.999774, 0], 1.00],
    ["Land_HBarrier_Big_F", 696.976, 5040.87, [-0.0159231, 0.999873, 0], 0],
    ["Land_HBarrier_Big_F", 696.966, 5040.87, [-0.0159231, 0.999873, 0], 1.42]
];

private _fn_placePrefabObj = {
    params ["_pitPos", "_pitDir", "_cls", "_origX", "_origY", "_vecDir", "_zOff"];
    private _offX = _origX - (_origCenter select 0);
    private _offY = _origY - (_origCenter select 1);
    private _dist = sqrt (_offX * _offX + _offY * _offY);
    private _dirToObj = _offX atan2 _offY;
    private _newPos = _pitPos getPos [_dist, _dirToObj + _pitDir];

    private _obj = createVehicle [_cls, _newPos, [], 0, "CAN_COLLIDE"];

    private _terrainZ = getTerrainHeightASL _newPos;
    _obj setPosASL [_newPos#0, _newPos#1, _terrainZ + _zOff];

    private _baseDir = [_vecDir] call _fn_dirFromVec;
    private _finalDir = _baseDir + _pitDir;
    private _dirVecComputed = [sin _finalDir, cos _finalDir, 0];

    private _surfNormal = surfaceNormal _newPos;
    private _sideVec = _dirVecComputed vectorCrossProduct _surfNormal;
    private _upVec = _surfNormal;
    private _fwdVec = _upVec vectorCrossProduct _sideVec;

    _obj setVectorDirAndUp [_fwdVec, _upVec];
    _obj enableSimulationGlobal false;
    _obj enableDynamicSimulation false;
    _obj allowDamage false;
    _obj setVelocity [0,0,0];
    _obj
};

private _placed = [];
private _aoHardLimit = _aoRadius * 0.85;
private _minDist = 150;
private _maxDist = (_aoHardLimit - 50) max 200;

if (_maxDist < (_minDist + 50)) then {
    _minDist = 50;
    _maxDist = (_aoHardLimit - 50) max 150;
};

diag_log format ["[AA] Spawning %1 AA pits (min: %2m, max: %3m, AO radius: %4m)", _pitCount, _minDist, _maxDist, _aoRadius];

for "_p" from 1 to _pitCount do {

    private _pitPos = [];

    // Attempt 1: Perfect spot — strict flatness
    for "_attempt" from 1 to 60 do {
        private _dir = random 360;
        private _dist = _minDist + random (_maxDist - _minDist);
        private _testPos = _aoPos getPos [_dist, _dir];

        if ((_testPos distance2D _aoPos) > _aoHardLimit) then { continue };
        if (surfaceIsWater _testPos) then { continue };

        private _tooClose = false;
        { if (_testPos distance2D _x < 150) exitWith { _tooClose = true }; } forEach _placed;
        if (_tooClose) then { continue };

        if !([_testPos] call _fn_farEnough) then { continue };

        // FIX: Check radio tower proximity
        if !([_testPos] call _fn_farFromRadioTowers) then { continue };

        if ((count (nearestObjects [_testPos, ["House", "Building", "Wall"], 25])) > 0) then { continue };
        if ((count (_testPos nearRoads 25)) > 0) then { continue };
        if (count (nearestTerrainObjects [_testPos, ["TREE", "SMALL TREE", "ROCK", "ROCKS"], 12, false]) > 0) then { continue };
        if ((count (nearestObjects [_testPos, ["AllVehicles", "Thing"], 15])) > 0) then { continue };

        if !([_testPos, 14, 0.10] call _fn_isFlat) then { continue };

        private _safe = [_testPos, 0, 25, 10, 0, 0.10, 0] call BIS_fnc_findSafePos;
        if (!(_safe isEqualTo []) && !(_safe isEqualTo [0,0,0])) then {
            if ((_safe distance2D _aoPos) <= _aoHardLimit) then {
                if ([_safe, 14, 0.10] call _fn_isFlat) then {
                    // FIX: Re-check radio tower at adjusted position
                    if ([_safe] call _fn_farFromRadioTowers) then {
                        _pitPos = _safe;
                    };
                };
            };
        };
        if !(_pitPos isEqualTo []) exitWith {};
    };

    // Attempt 2: Relaxed
    if (_pitPos isEqualTo []) then {
        for "_attempt" from 1 to 60 do {
            private _testPos = [_aoPos, _minDist, _maxDist, 10, 0, 0.15, 0] call BIS_fnc_findSafePos;
            if (_testPos isEqualTo [0,0,0]) then { continue };
            if (surfaceIsWater _testPos) then { continue };
            if ((_testPos distance2D _aoPos) > _aoHardLimit) then { continue };

            private _tooClose = false;
            { if (_testPos distance2D _x < 120) exitWith { _tooClose = true }; } forEach _placed;
            if (_tooClose) then { continue };

            if !([_testPos] call _fn_farEnough) then { continue };
            if !([_testPos] call _fn_farFromRadioTowers) then { continue };
            if ((count (nearestObjects [_testPos, ["AllVehicles", "Thing"], 12])) > 0) then { continue };

            if !([_testPos, 12, 0.15] call _fn_isFlat) then { continue };

            _pitPos = _testPos;
            if !(_pitPos isEqualTo []) exitWith {};
        };
    };

    // Attempt 3: Last resort
    if (_pitPos isEqualTo []) then {
        diag_log format ["[AA] Pit %1: Using forced fallback position", _p];
        for "_i" from 1 to 150 do {
            private _rndPos = _aoPos getPos [_minDist + random (_maxDist - _minDist), random 360];
            if (!surfaceIsWater _rndPos
                && {(_rndPos distance2D _aoPos) <= _aoHardLimit}
                && {(count (nearestObjects [_rndPos, ["AllVehicles"], 10])) == 0}
                && {[_rndPos] call _fn_farFromRadioTowers}
                && {[_rndPos, 10, 0.18] call _fn_isFlat}
            ) exitWith {
                _pitPos = _rndPos;
            };
        };
    };

    if (_pitPos isEqualTo [] || _pitPos isEqualTo [0,0,0]) then {
        diag_log format ["[AA] CRITICAL: Could not find ANY flat land for pit %1. Skipping.", _p];
        continue;
    };

    if ((_pitPos distance2D _aoPos) > _aoHardLimit) then {
        private _dirToCenter = _pitPos getDir _aoPos;
        _pitPos = _aoPos getPos [(_aoHardLimit * 0.7), (_dirToCenter + 180)];
        if !([_pitPos, 12, 0.15] call _fn_isFlat) then {
            diag_log format ["[AA] Pit %1: Clamped position not flat enough, skipping", _p];
            continue;
        };
        if !([_pitPos] call _fn_farFromRadioTowers) then {
            diag_log format ["[AA] Pit %1: Clamped position too close to radio tower, skipping", _p];
            continue;
        };
        diag_log format ["[AA] Pit %1: Position was outside AO, clamped to %2", _p, _pitPos];
    };

    _placed pushBack _pitPos;
    DYN_OBJ_centers pushBack _pitPos;

    private _pitDir = random 360;

    // Clear terrain — wide radius
    {
        if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
            _x setVariable ["DYN_hiddenByAO", true, false];
            _x hideObjectGlobal true;
            DYN_AO_hiddenTerrain pushBack _x;
        };
    } forEach (nearestTerrainObjects [_pitPos, ["TREE","SMALL TREE","BUSH","ROCK","ROCKS","HIDE"], 20, false]);

    {
        if (!isNull _x && {!(_x isKindOf "Man")}) then {
            _x hideObjectGlobal true;
            DYN_AO_hiddenTerrain pushBack _x;
        };
    } forEach (nearestObjects [_pitPos, ["Thing", "Static"], 10]);

    // =========================================================
    // SPAWN VEHICLE AND PIT
    // =========================================================
    [_pitPos, _pitDir, _aaClass, _crewClass, _aoPos, _aoRadius, _p, _aoHardLimit, _prefab, _origCenter, _fn_placePrefabObj, _fn_dirFromVec, _fn_getFootprintMaxASL] spawn {
        params ["_pitPos", "_pitDir", "_aaClass", "_crewClass", "_aoPos", "_aoRadius", "_pitNum", "_aoHardLimit", "_prefab", "_origCenter", "_fn_placePrefabObj", "_fn_dirFromVec", "_fn_getFootprintMaxASL"];

        sleep 1;

        private _aaVeh = createVehicle [_aaClass, _pitPos, [], 0, "NONE"];

        if (isNull _aaVeh) then {
            diag_log format ["[AA] ERROR: Failed to create vehicle for pit %1", _pitNum];
            if (true) exitWith {};
        };

        _aaVeh allowDamage false;
        _aaVeh enableSimulationGlobal false;
        _aaVeh setVelocity [0, 0, 0];

        // FIX: Use highest terrain point across entire vehicle footprint
        // Tunguska is ~6m wide, sample at 6m radius to catch all edges
        private _groundASL = [_pitPos, 6] call _fn_getFootprintMaxASL;
        private _vehOffset = 0.45;  // Increased from 0.2 — prevents any edge sinking

        _aaVeh setPosASL [_pitPos#0, _pitPos#1, _groundASL + _vehOffset];
        _aaVeh setDir _pitDir;

        private _surfNormal = surfaceNormal _pitPos;
        private _dirVec = [sin _pitDir, cos _pitDir, 0];
        private _sideVec = _dirVec vectorCrossProduct _surfNormal;
        private _upVec = _surfNormal;
        private _fwdVec = _upVec vectorCrossProduct _sideVec;
        _aaVeh setVectorDirAndUp [_fwdVec, _upVec];
        _aaVeh setVelocity [0, 0, 0];

        sleep 0.5;

        // Spawn barriers
        {
            _x params ["_cls", "_xw", "_yw", "_vec", "_z"];
            private _o = [_pitPos, _pitDir, _cls, _xw, _yw, _vec, _z] call _fn_placePrefabObj;
            DYN_AO_objects pushBack _o;
        } forEach _prefab;

        sleep 1;

        // FIX: Re-snap with footprint height (not just center point)
        _groundASL = [_pitPos, 6] call _fn_getFootprintMaxASL;
        _aaVeh setPosASL [_pitPos#0, _pitPos#1, _groundASL + _vehOffset];
        _aaVeh setVectorDirAndUp [_fwdVec, _upVec];
        _aaVeh setVelocity [0, 0, 0];

        sleep 0.5;

        _aaVeh enableSimulationGlobal true;
        _aaVeh setVelocity [0, 0, 0];

        sleep 0.05;
        _aaVeh setVelocity [0, 0, 0];
        sleep 0.05;
        _aaVeh setVelocity [0, 0, 0];
        sleep 0.1;
        _aaVeh setVelocity [0, 0, 0];

        // Post-settle stabilization — checks at longer intervals to reduce load
        [_aaVeh, _pitPos, _fwdVec, _upVec, _vehOffset, _fn_getFootprintMaxASL] spawn {
            params ["_v", "_pos", "_fwd", "_up", "_offset", "_fnFootprint"];
            for "_i" from 1 to 6 do {
                if (isNull _v || !alive _v) exitWith {};
                _v setVelocity [0, 0, 0];

                private _curPos = getPosASL _v;
                private _expectedZ = ([_pos, 6] call _fnFootprint) + _offset;

                if (_curPos#2 < (_expectedZ - 0.15) || {(_curPos distance [_pos#0, _pos#1, _curPos#2]) > 1}) then {
                    _v setPosASL [_pos#0, _pos#1, _expectedZ];
                    _v setVectorDirAndUp [_fwd, _up];
                };
                sleep 0.5;
            };
            sleep 7;
            if (!isNull _v) then { _v allowDamage true; };
        };

        DYN_AO_enemyVehs pushBack _aaVeh;

        _aaVeh setVehicleLock "LOCKED";
        _aaVeh engineOn false;
        _aaVeh setFuel 0;
        _aaVeh setVehicleAmmo 1;
        _aaVeh lockDriver true;

        _aaVeh setVariable ["aaCharges", 0, true];
        _aaVeh setVariable ["aaLastHitT", -999, false];
        _aaVeh setVariable ["aaKilled", false, true];

        _aaVeh addEventHandler ["HandleDamage", {
            params ["_veh", "_selection", "_damage", "_source", "_projectile"];
            if (_veh getVariable ["aaKilled", false]) exitWith { _damage };
            if (_projectile isEqualTo "") exitWith { 0 };
            private _cfg = (configFile >> "CfgAmmo" >> _projectile);
            private _isExpl = (getNumber (_cfg >> "explosive") > 0) || (getNumber (_cfg >> "indirectHit") > 0);
            if (!_isExpl) exitWith { 0 };

            private _t = diag_tickTime;
            private _last = _veh getVariable ["aaLastHitT", -999];
            if ((_t - _last) < 0.1) exitWith { 0 };
            _veh setVariable ["aaLastHitT", _t, false];

            private _c = (_veh getVariable ["aaCharges", 0]) + 1;
            _veh setVariable ["aaCharges", _c, true];

            if (_c >= 2) then {
                _veh setVariable ["aaKilled", true, true];
                _veh setDamage 1;
            };
            0
        }];

        _aaVeh addEventHandler ["Killed", {
            params ["_veh"];
            private _rem = (missionNamespace getVariable ["DYN_AA_remaining", 0]) - 1;
            if (_rem < 0) then { _rem = 0 };
            missionNamespace setVariable ["DYN_AA_remaining", _rem, true];
        }];

        sleep 1;

        private _grp = createGroup east;
        DYN_AO_enemyGroups pushBack _grp;
        _grp setBehaviour "COMBAT";
        _grp setCombatMode "RED";

        private _gunnerSpawnPos = _pitPos getPos [15, _pitDir + 90];
        private _gunner = _grp createUnit [_crewClass, _gunnerSpawnPos, [], 0, "NONE"];
        if (isNull _gunner) then { _gunner = _grp createUnit ["O_crew_F", _gunnerSpawnPos, [], 0, "NONE"]; };

        if (!isNull _gunner) then {
            _gunner allowDamage false;
            _gunner enableSimulationGlobal false;
            _gunner setPosATL _gunnerSpawnPos;

            sleep 0.3;

            _gunner enableSimulationGlobal true;
            _gunner assignAsGunner _aaVeh;
            _gunner moveInGunner _aaVeh;

            sleep 0.5;
            if (vehicle _gunner != _aaVeh) then {
                _gunner moveInGunner _aaVeh;
                sleep 0.3;
            };

            if (vehicle _gunner != _aaVeh) then {
                _gunner moveInGunner _aaVeh;
                sleep 0.3;
            };

            if (vehicle _gunner != _aaVeh) then {
                _gunner moveInAny _aaVeh;
                sleep 0.3;
            };

            _gunner setSkill 0.50;
            _gunner allowFleeing 0;
            { _gunner disableAI _x; } forEach ["PATH", "MOVE", "FSM", "AUTOCOMBAT"];

            [_gunner] spawn {
                params ["_g"];
                sleep 10;
                if (!isNull _g) then { _g allowDamage true; };
            };

            DYN_AO_enemies pushBack _gunner;
            _aaVeh setVariable ["aaGunner", _gunner, false];
        };

        // Targeting loop
        [_aaVeh, _aoPos, _aoRadius, _pitNum] spawn {
            params ["_veh", "_aoPos", "_aoRadius", "_pitNum"];
            sleep 5;
            private _gunner = _veh getVariable ["aaGunner", objNull];
            if (isNull _gunner) exitWith {};

            private _maxRange = _aoRadius * 2.5;
            private _lastTarget = objNull;

            while { (missionNamespace getVariable ["DYN_AO_active", true]) && {alive _veh} && {alive _gunner} && {vehicle _gunner == _veh} } do {
                sleep 3;

                // Pre-filter to only air vehicles near this AA
                private _nearVehs = _veh nearEntities [["Helicopter", "Plane"], _maxRange];
                private _target = objNull;
                private _minD = 1e9;

                {
                    if (alive _x && {(getPosATL _x) select 2 > 10}) then {
                        private _cmdr = effectiveCommander _x;
                        if (!isNull _cmdr && {side (group _cmdr) isEqualTo west}) then {
                            private _d = _x distance _veh;
                            if (_d < _minD) then { _minD = _d; _target = _x; };
                        };
                    };
                } forEach _nearVehs;

                if (isNull _target) then {
                    if (!isNull _lastTarget) then {
                        _gunner doTarget objNull;
                        _gunner doWatch objNull;
                        _lastTarget = objNull;
                    };
                    continue;
                };

                _lastTarget = _target;
                _gunner reveal [_target, 4];
                _gunner doWatch _target;
                _gunner doTarget _target;
                _gunner doFire _target;
                _veh doWatch _target;
                _veh doTarget _target;
            };
        };

        diag_log format ["[AA] Pit %1: Spawn successful at %2 (dist from AO center: %3m)", _pitNum, _pitPos, round (_pitPos distance2D _aoPos)];
    };
};

diag_log format ["[AA] COMPLETE: Placed %1/%2 Tunguska positions", count _placed, _pitCount];
