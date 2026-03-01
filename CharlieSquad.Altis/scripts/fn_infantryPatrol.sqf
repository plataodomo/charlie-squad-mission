/*
    scripts\fn_infantryPatrol.sqf
    v2: Added building defenders, hilltop fire teams, road checkpoints
    - Building occupation across wider AO radius
    - Elevated fire teams with sandbag cover
    - Road checkpoints with static weapons
    - Original patrols, vehicles, snipers, QRF unchanged
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

diag_log "[PATROL] Spawning Ambient Patrols + Static Defenders...";

// =====================================================
// 0. AO BOUNDARY CHECK FUNCTION
// =====================================================
private _fn_insideAO = {
    params ["_testPos", "_center", "_radius"];
    if (_testPos isEqualTo [] || {_testPos isEqualTo [0,0,0]}) exitWith { false };
    (_testPos distance2D _center) <= _radius
};

// =====================================================
// 1. UNIT POOLS (CUP Russian)
// =====================================================
private _infPool = [
    "CUP_O_RU_Soldier_SL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Medic_Ratnik_Autumn"
];

private _defenderPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

private _mgClass = "CUP_O_RU_Soldier_MG_Ratnik_Autumn";

private _vehPool = [
    "CUP_O_UAZ_MG_RU",
    "CUP_O_UAZ_AGS30_RU",
    "CUP_O_UAZ_SPG9_RU",
    "CUP_O_GAZ_Vodnik_PK_RU",
    "CUP_O_GAZ_Vodnik_AGS_RU",
    "CUP_O_GAZ_Vodnik_BPPU_RU",
    "CUP_O_BTR80_GREEN_RU",
    "CUP_O_BTR80A_GREEN_RU",
    "CUP_O_BTR90_RU",
    "CUP_O_BRDM2_RUS",
    "CUP_O_BRDM2_ATGM_RUS",
    "CUP_O_Ural_ZU23_RU"
];

private _tankClass = "CFP_O_RUARMY_T72_DES_01";
private _tankChance = 0.50;

private _sniperClass = "CUP_O_RU_Sniper_Ratnik_Autumn";
private _spotterClass = "CUP_O_RU_Spotter_Ratnik_Autumn";

if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_AO_enemyVehs") then { DYN_AO_enemyVehs = []; };

// =====================================================
// 2. PATROL FUNCTION (CLAMPED TO AO)
// =====================================================
DYN_fnc_patrolCycle = {
    params ["_group", "_center", "_radius"];

    _group setBehaviour "SAFE";
    _group setSpeedMode "LIMITED";
    _group setCombatMode "YELLOW";

    while { ({alive _x} count (units _group)) > 0 } do {
        private _dest = [];

        if (random 1 < 0.70) then {
            private _searchDist = random (_radius * 0.85);
            private _searchPos = _center getPos [_searchDist, random 360];
            private _roads = _searchPos nearRoads 100;
            _roads = _roads select { (getPos _x) distance2D _center <= _radius };

            if (count _roads > 0) then {
                _dest = getPos (selectRandom _roads);
            };
        };

        if (_dest isEqualTo []) then {
            _dest = [_center, 0, _radius * 0.9, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;
        };
        if (_dest isEqualTo [0,0,0]) then { _dest = _center getPos [random (_radius * 0.7), random 360]; };

        if ((_dest distance2D _center) > _radius) then {
            private _dirToPos = _center getDir _dest;
            _dest = _center getPos [_radius * 0.85, _dirToPos];
        };

        for "_i" from (count waypoints _group - 1) to 0 step -1 do { deleteWaypoint [_group, _i]; };
        private _wp = _group addWaypoint [_dest, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCompletionRadius 20;

        private _tOut = diag_tickTime + 500;
        waitUntil {
            sleep 5;
            (unitReady (leader _group)) || (behaviour (leader _group) == "COMBAT") || (diag_tickTime > _tOut)
        };

        if (behaviour (leader _group) == "COMBAT") then {
            _group setCombatMode "RED";
            _group setSpeedMode "FULL";

            private _ldr = leader _group;
            private _knownEnemies = _ldr targets [true, 500];
            {
                if (alive _x && {side _x == west}) then {
                    _ldr doSuppressiveFire (getPos _x);
                };
            } forEach _knownEnemies;

            waitUntil {
                sleep 5;
                ({alive _x} count (units _group)) == 0
                || {behaviour (leader _group) != "COMBAT"}
            };

            if (({alive _x} count (units _group)) > 0) then {
                sleep (20 + random 30);
                _group setBehaviour "SAFE";
                _group setSpeedMode "LIMITED";
                _group setCombatMode "YELLOW";
            };
        };

        if (random 1 > 0.6) then { sleep (15 + random 45); };
    };
};

// =====================================================
// 3. COMBAT COORDINATOR (QRF + FLANKING) - CLAMPED
// =====================================================
[_aoPos, _aoRadius] spawn {
    params ["_pos", "_rad"];
    while { true } do {
        sleep 12;

        private _groupsInCombat = DYN_AO_enemyGroups select {
            (side _x == east) && {({alive _x} count units _x) > 1} && {behaviour (leader _x) == "COMBAT"}
        };

        if (count _groupsInCombat == 0) then { continue; };

        private _troubledGroup = selectRandom _groupsInCombat;
        private _contactPos = getPos (leader _troubledGroup);

        if ((_contactPos distance2D _pos) > _rad) then { continue; };

        private _nearPlayers = allPlayers select { alive _x && (side (group _x) == west) && ((_x distance2D _contactPos) < 500) };
        private _playerPos = if (_nearPlayers isEqualTo []) then {
            _contactPos getPos [50, random 360]
        } else {
            private _closest = objNull; private _cDist = 1e9;
            { private _d = _x distance2D _contactPos; if (_d < _cDist) then { _cDist = _d; _closest = _x; }; } forEach _nearPlayers;
            getPos _closest
        };

        private _contactDir = _playerPos getDir _contactPos;

        private _availGroups = DYN_AO_enemyGroups select {
            (side _x == east) &&
            {_x != _troubledGroup} &&
            {({alive _x} count units _x) > 2} &&
            {behaviour (leader _x) != "COMBAT"} &&
            {(leader _x) distance2D _contactPos < 600}
        };

        if (count _availGroups == 0) then { continue; };

        private _grpDists = _availGroups apply { [(leader _x) distance2D _contactPos, _x] };
        _grpDists sort true;
        _availGroups = _grpDists apply { _x#1 };

        private _sendCount = (count _availGroups) min 3;

        for "_i" from 0 to (_sendCount - 1) do {
            private _grp = _availGroups select _i;

            private _offsetAngle = switch (_i) do {
                case 0: { _contactDir + 80 + random 40 };
                case 1: { _contactDir - 80 - random 40 };
                default { _contactDir };
            };

            private _flankDist = 30 + random 30;
            private _flankPos = _playerPos getPos [_flankDist, _offsetAngle];

            if ((_flankPos distance2D _pos) > _rad) then {
                private _dirBack = _pos getDir _flankPos;
                _flankPos = _pos getPos [_rad * 0.85, _dirBack];
            };

            _grp setCombatMode "RED";
            _grp setBehaviour "AWARE";
            _grp setSpeedMode "FULL";

            for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

            private _wp1 = _grp addWaypoint [_flankPos, 0];
            _wp1 setWaypointType "MOVE";
            _wp1 setWaypointSpeed "FULL";
            _wp1 setWaypointBehaviour "AWARE";
            _wp1 setWaypointCombatMode "RED";
            _wp1 setWaypointCompletionRadius 20;

            private _wp2 = _grp addWaypoint [_contactPos, 0];
            _wp2 setWaypointType "SAD";
            _wp2 setWaypointSpeed "NORMAL";
            _wp2 setWaypointCombatMode "RED";
        };

        sleep 40;
    };
};

// =====================================================
// 3.5 COMBAT AGGRESSION ENHANCER
// =====================================================
[_aoPos, _aoRadius] spawn {
    params ["_pos", "_rad"];
    while { true } do {
        sleep 15;

        private _combatGroups = DYN_AO_enemyGroups select {
            (side _x == east) && {({alive _x} count units _x) > 0} && {behaviour (leader _x) == "COMBAT"}
        };
        if (_combatGroups isEqualTo []) then { continue };

        private _processCount = (count _combatGroups) min 5;
        for "_idx" from 0 to (_processCount - 1) do {
            private _grp = _combatGroups select _idx;
            private _ldr = leader _grp;
            if (isNull _ldr || {!alive _ldr}) then { continue };

            _grp setCombatMode "RED";

            private _knownTargets = (_ldr targets [true, 400]) select { alive _x && (side (group _x) == west) };
            if (_knownTargets isEqualTo []) then { continue };

            private _primaryTarget = objNull;
            private _minDist = 1e9;
            { private _d = _x distance2D _ldr; if (_d < _minDist) then { _minDist = _d; _primaryTarget = _x; }; } forEach _knownTargets;
            if (isNull _primaryTarget) then { continue };

            private _targetPos = getPos _primaryTarget;
            private _aliveUnits = (units _grp) select { alive _x };

            _ldr reveal [_primaryTarget, 4];
            { _x doSuppressiveFire _targetPos; } forEach _aliveUnits;

            private _vehTargets = _knownTargets select { vehicle _x != _x };
            if !(_vehTargets isEqualTo []) then {
                {
                    if (secondaryWeapon _x != "") then {
                        private _vt = selectRandom _vehTargets;
                        _x doTarget _vt;
                        _x doFire _vt;
                    };
                } forEach _aliveUnits;
            };
        };
    };
};

// =====================================================
// 4. BUILDING DEFENDERS — spread across WIDE AO
// Fills buildings from inner city out to 0.80 of AO radius
// 2-4 soldiers per building, holding windows and rooftops
// These are STATIC — they don't patrol, they hold position
// =====================================================
private _allHouses = nearestObjects [_aoPos, ["House"], _aoRadius * 0.80];
_allHouses = _allHouses call BIS_fnc_arrayShuffle;

// Filter to buildings with at least 3 positions (multi-story or decent size)
private _goodHouses = _allHouses select { count ([_x] call BIS_fnc_buildingPositions) >= 3 };

// Split into zones: inner (0-40%), mid (40-65%), outer (65-80%)
private _innerHouses = _goodHouses select { (_x distance2D _aoPos) <= (_aoRadius * 0.40) };
private _midHouses   = _goodHouses select { (_x distance2D _aoPos) > (_aoRadius * 0.40) && (_x distance2D _aoPos) <= (_aoRadius * 0.65) };
private _outerHouses = _goodHouses select { (_x distance2D _aoPos) > (_aoRadius * 0.65) };

// Occupy more inner, fewer outer — density gradient
private _innerUse = (12 min count _innerHouses);
private _midUse   = (10 min count _midHouses);
private _outerUse = (6 min count _outerHouses);

private _housesToOccupy = [];
for "_i" from 0 to (_innerUse - 1) do { if (_i < count _innerHouses) then { _housesToOccupy pushBack (_innerHouses select _i); }; };
for "_i" from 0 to (_midUse - 1) do { if (_i < count _midHouses) then { _housesToOccupy pushBack (_midHouses select _i); }; };
for "_i" from 0 to (_outerUse - 1) do { if (_i < count _outerHouses) then { _housesToOccupy pushBack (_outerHouses select _i); }; };

private _buildingDefCount = 0;

{
    private _building = _x;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    if (_positions isEqualTo []) then { continue };

    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";

    // 2-4 soldiers per building
    private _count = 2 + floor (random 3);
    _count = _count min (count _positions);

    _positions = _positions call BIS_fnc_arrayShuffle;

    for "_u" from 0 to (_count - 1) do {
        private _bPos = _positions select _u;
        private _unit = _grp createUnit [selectRandom _defenderPool, _bPos, [], 0, "NONE"];
        if (isNull _unit) then { continue };

        _unit setPosATL _bPos;
        _unit disableAI "PATH";
        _unit setUnitPos (selectRandom ["UP", "MIDDLE"]);
        _unit allowFleeing 0;
        _unit setSkill 0.35 + (random 0.15);

        DYN_AO_enemies pushBack _unit;
        _buildingDefCount = _buildingDefCount + 1;
    };
} forEach _housesToOccupy;

diag_log format ["[PATROL] Building defenders: %1 soldiers in %2 buildings", _buildingDefCount, count _housesToOccupy];

// =====================================================
// 4.5 HILLTOP FIRE TEAMS — elevated overwatch positions
// 3-4 soldiers with sandbag cover on high terrain
// Hold position, engage at range
// =====================================================
private _baseHeight = getTerrainHeightASL _aoPos;
private _hilltopCount = 4 + floor (random 3);  // 4-6 positions
private _hilltopPositions = [];
private _hilltopTeamCount = 0;

for "_i" from 1 to _hilltopCount do {
    private _bestPos = [];
    private _bestHeight = -9999;

    for "_k" from 1 to 60 do {
        private _dist = (_aoRadius * 0.3) + random (_aoRadius * 0.5);
        private _dir = random 360;
        private _testPos = _aoPos getPos [_dist, _dir];

        if (surfaceIsWater _testPos) then { continue };
        if ((_testPos distance2D _aoPos) > (_aoRadius * 0.85)) then { continue };

        // Not too close to another hilltop team
        private _tooClose = false;
        { if (_testPos distance2D _x < 200) exitWith { _tooClose = true }; } forEach _hilltopPositions;
        if (_tooClose) then { continue };

        // Field positions — avoid buildings
        if ((count (nearestObjects [_testPos, ["House", "Building"], 30])) > 0) then { continue };

        private _h = getTerrainHeightASL _testPos;

        if (_h > (_baseHeight + 8) && {_h > _bestHeight}) then {
            _bestHeight = _h;
            _bestPos = _testPos;
        };
    };

    if (_bestPos isEqualTo []) then { continue };

    _hilltopPositions pushBack _bestPos;

    // Sandbag cover facing OUTWARD — watching for players approaching the AO
    private _coverDir = _aoPos getDir _bestPos;

    private _bag1 = createVehicle ["Land_BagFence_Long_F", _bestPos getPos [2, _coverDir], [], 0, "CAN_COLLIDE"];
    _bag1 setDir _coverDir;
    _bag1 enableSimulationGlobal false;
    DYN_AO_objects pushBack _bag1;

    private _bag2 = createVehicle ["Land_BagFence_Long_F", _bestPos getPos [2, _coverDir + 60], [], 0, "CAN_COLLIDE"];
    _bag2 setDir (_coverDir + 60);
    _bag2 enableSimulationGlobal false;
    DYN_AO_objects pushBack _bag2;

    private _bag3 = createVehicle ["Land_BagFence_Long_F", _bestPos getPos [2, _coverDir - 60], [], 0, "CAN_COLLIDE"];
    _bag3 setDir (_coverDir - 60);
    _bag3 enableSimulationGlobal false;
    DYN_AO_objects pushBack _bag3;

    // Fire team
    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";

    private _teamSize = 3 + floor (random 2);
    for "_u" from 1 to _teamSize do {
        private _spawnPos = _bestPos getPos [1 + random 2, random 360];
        private _cls = if (_u == 1) then { _mgClass } else { selectRandom _defenderPool };
        private _unit = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
        if (isNull _unit) then { continue };

        _unit setPosATL _spawnPos;
        _unit setUnitPos "MIDDLE";
        _unit allowFleeing 0;
        _unit setSkill 0.40 + (random 0.15);
        _unit setSkill ["spotDistance", 0.60];

        DYN_AO_enemies pushBack _unit;
        _hilltopTeamCount = _hilltopTeamCount + 1;
    };

    // Overwatch behavior — hold and engage
    [_grp, _bestPos] spawn {
        params ["_grp", "_holdPos"];

        while { ({alive _x} count (units _grp)) > 0 } do {
            sleep 8;

            if (({alive _x} count (units _grp)) == 0) exitWith {};

            private _ldr = leader _grp;
            if (isNull _ldr || !alive _ldr) exitWith {};

            // Pull back if drifted
            if ((_ldr distance2D _holdPos) > 50) then {
                for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };
                private _wp = _grp addWaypoint [_holdPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointBehaviour "AWARE";
            };

            // Suppress known targets
            if (behaviour _ldr == "COMBAT") then {
                _grp setCombatMode "RED";
                private _targets = (_ldr targets [true, 600]) select { alive _x && side (group _x) == west };
                if !(_targets isEqualTo []) then {
                    {
                        if (alive _x) then { _x doSuppressiveFire (getPos (selectRandom _targets)); };
                    } forEach (units _grp);
                };
            };
        };
    };
};

diag_log format ["[PATROL] Hilltop fire teams: %1 soldiers in %2 positions", _hilltopTeamCount, count _hilltopPositions];



// =====================================================
// 5. SPAWN INFANTRY PATROLS (CLAMPED TO AO)
// =====================================================
private _infCount = 18 + floor (random 5);

for "_i" from 1 to _infCount do {
    private _spawnPos = [];

    private _dist = random (_aoRadius * 0.9);
    private _dir = random 360;

    private _checkPos = _aoPos getPos [_dist, _dir];

    private _roads = _checkPos nearRoads 50;
    _roads = _roads select { (getPos _x) distance2D _aoPos <= _aoRadius };

    if (count _roads > 0) then {
        _spawnPos = getPos (selectRandom _roads);
    } else {
        _spawnPos = [_checkPos, 0, 50, 3, 0, 0.4, 0] call BIS_fnc_findSafePos;
    };

    if (_spawnPos isEqualTo [0,0,0]) then { continue; };
    if ((_spawnPos distance2D _aoPos) > _aoRadius) then { continue; };

    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;

    private _squadSize = 5 + floor (random 3);
    for "_j" from 1 to _squadSize do {
        private _u = _grp createUnit [selectRandom _infPool, _spawnPos, [], 2, "NONE"];
        DYN_AO_enemies pushBack _u;
    };

    [_grp, _aoPos, _aoRadius] spawn DYN_fnc_patrolCycle;
};

// =====================================================
// 6. SPAWN VEHICLES (CLAMPED TO AO)
// =====================================================
private _vehCount = 10 + floor (random 6);

private _aoRoads = (_aoPos nearRoads _aoRadius) select { (getPos _x) distance2D _aoPos <= (_aoRadius * 0.9) };

for "_i" from 1 to _vehCount do {
    if (_aoRoads isEqualTo []) exitWith {};

    private _road = selectRandom _aoRoads;
    private _spawnPos = getPos _road;

    if ((_spawnPos distance2D _aoPos) > _aoRadius) then { continue; };

    private _vehType = selectRandom _vehPool;
    private _veh = createVehicle [_vehType, _spawnPos, [], 0, "NONE"];
    _veh setDir (getDir _road);
    _veh setVectorUp (surfaceNormal _spawnPos);

    DYN_AO_enemyVehs pushBack _veh;

    private _grp = createGroup east;
    createVehicleCrew _veh;
    (crew _veh) joinSilent _grp;

    { DYN_AO_enemies pushBack _x; } forEach (crew _veh);
    DYN_AO_enemyGroups pushBack _grp;

    [_grp, _aoPos, _aoRadius] spawn DYN_fnc_patrolCycle;
};

// =====================================================
// 6.5 T-72 TANK PATROL (50% CHANCE - CLAMPED TO AO)
// =====================================================
private _tankSpawned = false;

if ((random 1) < _tankChance && {!(_aoRoads isEqualTo [])}) then {

    private _tankRoads = _aoRoads select { (getPos _x) distance2D _aoPos > (_aoRadius * 0.3) };
    if (_tankRoads isEqualTo []) then { _tankRoads = _aoRoads; };

    private _road = selectRandom _tankRoads;
    private _spawnPos = getPos _road;

    if ((_spawnPos distance2D _aoPos) <= _aoRadius) then {
        private _tank = createVehicle [_tankClass, _spawnPos, [], 0, "NONE"];
        _tank setDir (getDir _road);
        _tank setVectorUp (surfaceNormal _spawnPos);

        createVehicleCrew _tank;

        DYN_AO_enemyVehs pushBack _tank;

        private _grp = group (driver _tank);
        DYN_AO_enemyGroups pushBack _grp;

        {
            DYN_AO_enemies pushBack _x;
            _x allowFleeing 0;
            _x setSkill 0.55;
            _x setSkill ["aimingAccuracy", 0.50];
            _x setSkill ["aimingSpeed", 0.45];
            _x setSkill ["spotDistance", 0.60];
            _x setSkill ["courage", 0.65];
        } forEach crew _tank;

        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _grp setSpeedMode "LIMITED";

        [_grp, _aoPos, _aoRadius, _aoRoads] spawn {
            params ["_grp", "_center", "_rad", "_roads"];

            while { ({alive _x} count (units _grp)) > 0 } do {
                private _validRoads = _roads select { (getPos _x) distance2D _center <= (_rad * 0.85) };
                if (_validRoads isEqualTo []) then { _validRoads = _roads; };

                private _dest = getPos (selectRandom _validRoads);

                if ((_dest distance2D _center) > _rad) then {
                    private _d = _center getDir _dest;
                    _dest = _center getPos [_rad * 0.8, _d];
                };

                for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

                private _wp = _grp addWaypoint [_dest, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "AWARE";
                _wp setWaypointCombatMode "RED";
                _wp setWaypointCompletionRadius 30;

                private _tOut = diag_tickTime + 600;
                waitUntil {
                    sleep 5;
                    (unitReady (leader _grp))
                    || (behaviour (leader _grp) == "COMBAT")
                    || (diag_tickTime > _tOut)
                };

                if (behaviour (leader _grp) == "COMBAT") then {
                    _grp setSpeedMode "NORMAL";
                    waitUntil {
                        sleep 5;
                        ({alive _x} count (units _grp)) == 0
                        || {behaviour (leader _grp) != "COMBAT"}
                    };
                    if (({alive _x} count (units _grp)) > 0) then {
                        sleep (15 + random 20);
                        _grp setBehaviour "AWARE";
                        _grp setSpeedMode "LIMITED";
                    };
                } else {
                    sleep (10 + random 30);
                };
            };
        };

        _tankSpawned = true;
        diag_log "PATROL: T-72 tank spawned (50% chance hit)";
    };
};

if (!_tankSpawned) then {
    diag_log "PATROL: T-72 tank not spawned (50% chance miss)";
};

// =====================================================
// 7. ELITE SNIPER TEAMS (CLAMPED TO AO)
// =====================================================
private _sniperSquadCount = 1 + floor (random 3);

for "_i" from 1 to _sniperSquadCount do {

    private _bestPos = [];
    private _highest = -9999;

    for "_k" from 1 to 50 do {
        private _testPos = [_aoPos, (_aoRadius * 0.4), (_aoRadius * 0.85), 5, 0, 0.6, 0] call BIS_fnc_findSafePos;
        if !(_testPos isEqualTo [0,0,0]) then {
            if ((_testPos distance2D _aoPos) > _aoRadius) then { continue };

            private _h = getTerrainHeightASL _testPos;
            if (_h > (_baseHeight + 15)) then {
                if (_h > _highest) then {
                    _highest = _h;
                    _bestPos = _testPos;
                };
            };
        };
    };

    if (_bestPos isEqualTo []) then {
        _bestPos = [_aoPos, (_aoRadius * 0.5), (_aoRadius * 0.9), 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
    };
    if (_bestPos isEqualTo [0,0,0]) then { continue; };
    if ((_bestPos distance2D _aoPos) > _aoRadius) then { continue; };

    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;
    _grp setBehaviour "STEALTH";
    _grp setCombatMode "RED";
    _grp setSpeedMode "LIMITED";

    private _sn = _grp createUnit [_sniperClass, _bestPos, [], 0, "NONE"];
    private _sp = _grp createUnit [_spotterClass, _bestPos, [], 0, "NONE"];

    {
        DYN_AO_enemies pushBack _x;
        _x setSkill 0.55;
        _x setUnitPos "DOWN";
        _x allowFleeing 0;
        _x setSkill ["spotDistance", 0.65];
        _x setSkill ["camouflage", 0.15];
    } forEach units _grp;

    [_grp, _aoPos, _aoRadius] spawn {
        params ["_grp", "_center", "_rad"];
        while { ({alive _x} count (units _grp)) > 0 } do {
            private _movePos = [_center, _rad * 0.5, _rad * 0.85, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;

            if (_movePos isEqualTo [0,0,0] || {(_movePos distance2D _center) > _rad}) then {
                _movePos = _center getPos [random (_rad * 0.7), random 360];
            };

            _grp setBehaviour "STEALTH";
            _grp setSpeedMode "LIMITED";
            for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

            private _wp = _grp addWaypoint [_movePos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointBehaviour "STEALTH";

            private _timeOut = diag_tickTime + 900;
            waitUntil { sleep 10; unitReady (leader _grp) || behaviour (leader _grp) == "COMBAT" || diag_tickTime > _timeOut };

            if (behaviour (leader _grp) == "COMBAT") then {
                { _x setUnitPos "MIDDLE"; } forEach units _grp;
                sleep 120;
                { _x setUnitPos "DOWN"; } forEach units _grp;
            } else {
                sleep (300 + random 300);
            };
        };
    };
};

// =====================================================
// 8. LONE WOLF SNIPERS - HIGH GROUND AMBUSH (CLAMPED TO AO)
// =====================================================
private _loneWolfCount = 2 + floor (random 5);
private _loneWolfClass = "CUP_O_RU_Sniper_Ratnik_Autumn";

for "_i" from 1 to _loneWolfCount do {

    private _bestPos = [];
    private _bestHeight = -9999;

    for "_k" from 1 to 80 do {
        private _dist = (_aoRadius * 0.25) + random (_aoRadius * 0.60);
        private _dir = random 360;
        private _testPos = _aoPos getPos [_dist, _dir];

        if (surfaceIsWater _testPos) then { continue };
        if ((_testPos distance2D _aoPos) > _aoRadius) then { continue };

        if ((count (nearestObjects [_testPos, ["House","Building"], 40])) > 0) then { continue };
        if ((count (_testPos nearRoads 30)) > 0) then { continue };

        private _trees = count (nearestTerrainObjects [_testPos, ["TREE", "SMALL TREE"], 25, false]);
        private _treeBonus = if (_trees > 3 && _trees < 15) then { 5 } else { 0 };

        private _h = (getTerrainHeightASL _testPos) + _treeBonus;
        if (_h > _bestHeight) then {
            _bestHeight = _h;
            _bestPos = _testPos;
        };
    };

    if (_bestPos isEqualTo []) then {
        _bestPos = [_aoPos, _aoRadius * 0.3, _aoRadius * 0.85, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
    };
    if (_bestPos isEqualTo [0,0,0]) then { continue };
    if ((_bestPos distance2D _aoPos) > _aoRadius) then { continue };

    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;

    private _sniper = _grp createUnit [_loneWolfClass, _bestPos, [], 0, "NONE"];
    if (isNull _sniper) then { continue };

    DYN_AO_enemies pushBack _sniper;

    _sniper setSkill 0.60;
    _sniper setSkill ["aimingAccuracy", 0.60];
    _sniper setSkill ["aimingShake", 0.55];
    _sniper setSkill ["aimingSpeed", 0.50];
    _sniper setSkill ["spotDistance", 0.70];
    _sniper setSkill ["spotTime", 0.55];
    _sniper setSkill ["courage", 0.60];
    _sniper setSkill ["commanding", 0.45];
    _sniper setSkill ["general", 0.55];
    _sniper setSkill ["reloadSpeed", 0.65];
    _sniper setSkill ["camouflage", 0.10];

    _sniper setUnitPos "DOWN";
    _sniper allowFleeing 0;
    _sniper enableStamina false;

    _grp setBehaviour "STEALTH";
    _grp setCombatMode "RED";
    _grp setSpeedMode "LIMITED";

    [_grp, _aoPos, _aoRadius, _baseHeight] spawn {
        params ["_grp", "_center", "_rad", "_baseH"];

        while { ({alive _x} count (units _grp)) > 0 } do {
            sleep (600 + random 600);

            if (({alive _x} count (units _grp)) == 0) exitWith {};

            if (behaviour (leader _grp) == "COMBAT") then {
                { _x setUnitPos "MIDDLE"; } forEach units _grp;
                sleep 180;
                { _x setUnitPos "DOWN"; } forEach units _grp;
                continue;
            };

            private _newPos = [];
            private _newBest = -9999;

            for "_k" from 1 to 40 do {
                private _cand = _center getPos [(_rad * 0.25) + random (_rad * 0.60), random 360];
                if (surfaceIsWater _cand) then { continue };
                if ((_cand distance2D _center) > _rad) then { continue };
                if ((count (nearestObjects [_cand, ["House","Building"], 40])) > 0) then { continue };

                private _h = getTerrainHeightASL _cand;
                if (_h > (_baseH + 10) && {_h > _newBest}) then {
                    _newBest = _h;
                    _newPos = _cand;
                };
            };

            if (_newPos isEqualTo []) then { continue };

            _grp setBehaviour "STEALTH";
            _grp setSpeedMode "LIMITED";
            for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

            private _wp = _grp addWaypoint [_newPos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointBehaviour "STEALTH";
            _wp setWaypointCompletionRadius 10;

            private _timeOut = diag_tickTime + 600;
            waitUntil { sleep 10; unitReady (leader _grp) || behaviour (leader _grp) == "COMBAT" || diag_tickTime > _timeOut };

            { _x setUnitPos "DOWN"; } forEach units _grp;
        };
    };
};

diag_log format ["[PATROL] Complete. Buildings:%1 Hilltops:%2 Patrols:%3 Vehicles:%4 T-72=%5 SniperTeams:%6 LoneWolves:%7",
    count _housesToOccupy, count _hilltopPositions,
    _infCount, _vehCount, _tankSpawned, _sniperSquadCount, _loneWolfCount];
