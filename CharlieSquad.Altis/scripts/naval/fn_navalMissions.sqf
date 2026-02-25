/*
    scripts\naval\fn_navalMissions.sqf
    NAVAL SIDE MISSIONS - Controller
    Server only. Launches naval missions outside the AO on a timer.
    Runs independently of the main AO cycle.
*/
if (!isServer) exitWith {};

// Wait for systems to be ready
sleep 15;
waitUntil { sleep 5; !isNil "DYN_fnc_changeReputation" };

diag_log "[NAVAL] Naval mission system initializing...";

// =====================================================
// TRACKING VARIABLES
// =====================================================
DYN_naval_active        = false;
DYN_naval_objects       = [];
DYN_naval_enemies       = [];
DYN_naval_enemyGroups   = [];
DYN_naval_enemyVehs     = [];
DYN_naval_tasks         = [];
DYN_naval_markers       = [];
DYN_naval_hiddenTerrain = [];
DYN_naval_missionCount  = 0;

// =====================================================
// COMPILE EXTERNAL HELPERS
// =====================================================
DYN_fnc_clearCompositionArea = compile preprocessFileLineNumbers "scripts\naval\fn_clearCompositionArea.sqf";

// =====================================================
// HELPER: Find open-water position away from base & AO
// =====================================================
DYN_fnc_findNavalWaterPos = {
    params [["_minFromBase", 2000], ["_minFromAO", 1500]];

    private _basePos  = getMarkerPos "respawn_west";
    private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];
    private _mapSz    = worldSize;
    private _result   = [];

    for "_i" from 1 to 200 do {
        private _x = 200 + random (_mapSz - 400);
        private _y = 200 + random (_mapSz - 400);
        private _landTest = [_x, _y, 0];

        if (surfaceIsWater _landTest) then { continue };
        if (_landTest distance2D _basePos < _minFromBase) then { continue };
        if !(_aoCenter isEqualTo [0,0,0]) then {
            if (_landTest distance2D _aoCenter < _minFromAO) then { continue };
        };

        private _waterNearby = [];
        for "_d" from 0 to 350 step 15 do {
            for "_r" from 30 to 200 step 15 do {
                private _chk = [_landTest, _r, _d] call DYN_fnc_posOffset;
                if (surfaceIsWater _chk) exitWith { _waterNearby = _chk };
            };
            if !(_waterNearby isEqualTo []) exitWith {};
        };

        if (_waterNearby isEqualTo []) then { continue };

        _result = _waterNearby;
        break;
    };

    diag_log format ["[NAVAL] findNavalWaterPos result: %1", _result];
    _result
};

// =====================================================
// HELPER: Find coastal land position (IMPROVED)
// =====================================================
DYN_fnc_findCoastalLandPos = {
    params ["_waterPos", ["_maxSearch", 800], ["_minDist", 60]];

    private _compRadius = 40;
    private _maxSlope = 0.15;
    private _maxTries = 80;
    private _bestPos = [];
    private _bestScore = -999;

    private _goodSurfaces = [
        "concrete", "asphalt", "rock", "dirt", "gravel", "sand",
        "gdt_concrete", "gdt_asphalt", "gdt_rock", "gdt_dirt",
        "gdt_gravel", "gdt_sand"
    ];

    private _badSurfaces = [
        "gdt_forest", "gdt_lush_grass", "forest", "gdt_swamp", "swamp"
    ];

    for "_attempt" from 1 to _maxTries do {
        private _dir = random 360;
        private _dist = _minDist + random (_maxSearch - _minDist);
        private _testPos = [_waterPos, _dist, _dir] call DYN_fnc_posOffset;

        if (surfaceIsWater _testPos) then { continue };
        if (_testPos#0 < 50 || _testPos#1 < 50) then { continue };

        private _alt = getTerrainHeightASL _testPos;
        if (_alt > 25 || _alt < 0.5) then { continue };

        // Must actually be coastal
        private _hasWater = false;
        for "_d" from 1 to 12 do {
            private _chk = [_testPos, 30 + random 80, _d * 30] call DYN_fnc_posOffset;
            if (surfaceIsWater _chk) exitWith { _hasWater = true };
        };
        if (!_hasWater) then { continue };

        // Check slope across composition area
        private _heights = [];
        private _slopeOK = true;
        {
            private _checkPos = [_testPos, _compRadius, _x] call DYN_fnc_posOffset;
            if (surfaceIsWater _checkPos) then { _slopeOK = false };
            _heights pushBack (getTerrainHeightASL _checkPos);
        } forEach [0, 45, 90, 135, 180, 225, 270, 315];

        if (!_slopeOK) then { continue };

        _heights pushBack _alt;
        private _slopeRange = (selectMax _heights) - (selectMin _heights);

        if (_slopeRange > (_compRadius * _maxSlope)) then { continue };

        // Count obstructions
        private _treeCount = count (nearestTerrainObjects [_testPos, ["TREE", "SMALL TREE", "BUSH", "BUILDING", "HOUSE", "ROCK", "ROCKS"], _compRadius, false]);
        private _placedCount = count (_testPos nearObjects ["Building", _compRadius]);

        // Check surface type
        private _surfType = toLower (surfaceType _testPos);
        if ((_surfType select [0,1]) == "#") then {
            _surfType = _surfType select [1];
        };

        private _surfaceScore = 0;
        { if (_surfType find (toLower _x) >= 0) exitWith { _surfaceScore = 10 }; } forEach _goodSurfaces;
        { if (_surfType find (toLower _x) >= 0) exitWith { _surfaceScore = -20 }; } forEach _badSurfaces;

        // Road bonus
        private _roadBonus = if (count (_testPos nearRoads 80) > 0) then { 15 } else { 0 };

        // Distance to water score
        private _distToWater = _testPos distance2D _waterPos;
        private _distScore = 0;
        if (_distToWater >= 100 && _distToWater <= 300) then { _distScore = 10 };
        if (_distToWater > 300) then { _distScore = -5 };

        // Inner tree check
        private _innerTrees = 0;
        {
            private _ip = [_testPos, _compRadius * 0.5, _x] call DYN_fnc_posOffset;
            _innerTrees = _innerTrees + count (nearestTerrainObjects [_ip, ["TREE", "SMALL TREE", "BUSH"], 8, false]);
        } forEach [0, 90, 180, 270];

        // Composite score
        private _score = 0
            - (_treeCount * 3)
            - (_placedCount * 10)
            - (_slopeRange * 5)
            + _surfaceScore
            + _roadBonus
            + _distScore
            - (_innerTrees * 2);

        if (_score > _bestScore) then {
            _bestScore = _score;
            _bestPos = _testPos;
        };

        if (_score > 25) exitWith {
            diag_log format ["[NAVAL] Excellent position on attempt %1 (score: %2)", _attempt, _score];
        };
    };

    if (_bestPos isEqualTo []) then {
        diag_log "[NAVAL] WARNING: No suitable coastal land position found!";
    } else {
        private _nearbyTrees = count (nearestTerrainObjects [_bestPos, ["TREE","SMALL TREE","BUSH"], _compRadius, false]);
        diag_log format ["[NAVAL] Best position score: %1 (trees: %2)", _bestScore, _nearbyTrees];
    };

    _bestPos
};

// =====================================================
// HELPER: Find direction toward nearest water from pos
// =====================================================
DYN_fnc_dirToWater = {
    params ["_pos"];
    private _bestDir = 0;
    private _bestDist = 99999;

    for "_d" from 0 to 350 step 10 do {
        for "_r" from 10 to 300 step 10 do {
            private _chk = [_pos, _r, _d] call DYN_fnc_posOffset;
            if (surfaceIsWater _chk) exitWith {
                if (_r < _bestDist) then { _bestDist = _r; _bestDir = _d; };
            };
        };
    };

    _bestDir
};

// =====================================================
// HELPER: Find water positions near a center
// =====================================================
DYN_fnc_findNearbyWater = {
    params ["_center", "_min", "_max", ["_tries", 80]];
    private _out = [];

    for "_i" from 1 to _tries do {
        private _p = [_center, _min + random (_max - _min), random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _p) exitWith { _out = _p };
    };

    _out
};

// =====================================================
// CLEANUP FUNCTION
// =====================================================
DYN_fnc_navalCleanup = {
    diag_log "[NAVAL] Running cleanup...";

    // Clean vehicles and their crews
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            deleteVehicle _x;
        };
    } forEach DYN_naval_enemyVehs;

    // Clean enemy units
    { if (!isNull _x) then { deleteVehicle _x } } forEach DYN_naval_enemies;

    // Clean objects — restore hidden terrain, delete spawned objects
    {
        if (!isNull _x) then {
            if (isObjectHidden _x) then {
                _x hideObjectGlobal false;
            } else {
                deleteVehicle _x;
            };
        };
    } forEach DYN_naval_objects;

    // Restore hidden terrain objects
    {
        if (!isNull _x) then {
            _x hideObjectGlobal false;
        };
    } forEach DYN_naval_hiddenTerrain;

    // Clean groups
    { if (!isNull _x) then { deleteGroup _x } } forEach DYN_naval_enemyGroups;

    // Clean markers
    { deleteMarker _x } forEach DYN_naval_markers;

    // Clean tasks
    { [_x] call BIS_fnc_deleteTask } forEach DYN_naval_tasks;

    DYN_naval_objects       = [];
    DYN_naval_enemies       = [];
    DYN_naval_enemyGroups   = [];
    DYN_naval_enemyVehs     = [];
    DYN_naval_tasks         = [];
    DYN_naval_markers       = [];
    DYN_naval_hiddenTerrain = [];
    DYN_naval_active        = false;

    diag_log "[NAVAL] Cleanup complete.";
};

// =====================================================
// MAIN LOOP
// =====================================================
sleep 10;

diag_log "[NAVAL] Naval mission system active. Entering main loop.";

while {true} do {
    if (DYN_naval_active) then {
        sleep 30;
        continue;
    };

    private _missions = [
        "scripts\naval\fn_destroyPatrolBoats.sqf",
        "scripts\naval\fn_coastalOutpost.sqf",
        "scripts\naval\fn_coastalArtillery.sqf",
        "scripts\naval\fn_blackBoxRecovery.sqf"
    ];

    private _pick = selectRandom _missions;
    DYN_naval_missionCount = DYN_naval_missionCount + 1;

    diag_log format ["[NAVAL] Launching mission #%1: %2", DYN_naval_missionCount, _pick];

    DYN_naval_active = true;

    DYN_naval_objects       = [];
    DYN_naval_enemies       = [];
    DYN_naval_enemyGroups   = [];
    DYN_naval_enemyVehs     = [];
    DYN_naval_tasks         = [];
    DYN_naval_markers       = [];
    DYN_naval_hiddenTerrain = [];

    execVM _pick;

    // Give the mission script enough time to either succeed or fail
    sleep 30;

    if (!DYN_naval_active) then {
        diag_log "[NAVAL] Mission failed to spawn. Cleaning up and retrying in 60 seconds...";
        call DYN_fnc_navalCleanup;
        sleep 60;
        continue;
    };

    waitUntil { sleep 10; !DYN_naval_active };

    private _cooldown = 1800;
    diag_log format ["[NAVAL] Cooldown: %1 seconds", round _cooldown];
    sleep _cooldown;
};