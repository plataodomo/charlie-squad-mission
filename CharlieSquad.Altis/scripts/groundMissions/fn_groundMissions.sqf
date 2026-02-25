/*
    scripts\groundMissions\fn_groundMissions.sqf
    GROUND SIDE MISSIONS - Controller
    Server only. Launches ground missions outside the AO on a timer.
    
    FIXES APPLIED:
    - getPos on position arrays replaced with DYN_fnc_posOffset
    - Increased spawn wait time for convoy route building
    - Cleanup calls DYN_fnc_groundCleanup on failed spawn
    - Tasks cleaned up in cleanup function
*/
if (!isServer) exitWith {};

sleep 15;
waitUntil { sleep 5; !isNil "DYN_fnc_changeReputation" };
waitUntil { sleep 1; !isNil "DYN_fnc_posOffset" };

diag_log "[GROUND] Ground mission system initializing...";

// =====================================================
// TRACKING VARIABLES
// =====================================================
DYN_ground_active       = false;
DYN_ground_objects      = [];
DYN_ground_enemies      = [];
DYN_ground_enemyGroups  = [];
DYN_ground_enemyVehs    = [];
DYN_ground_tasks        = [];
DYN_ground_markers      = [];
DYN_ground_missionCount = 0;

// =====================================================
// HELPER: Find forested position away from base & AO
// =====================================================
DYN_fnc_findForestPos = {
    params [
        ["_minFromBase", 2000],
        ["_minFromAO", 1500],
        ["_minTrees", 15],
        ["_searchRadius", 50]
    ];

    private _basePos  = getMarkerPos "respawn_west";
    private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];
    private _mapSz    = worldSize;
    private _bestPos  = [];
    private _bestTrees = 0;

    for "_i" from 1 to 300 do {
        private _x = 200 + random (_mapSz - 400);
        private _y = 200 + random (_mapSz - 400);
        private _p = [_x, _y, 0];

        if (surfaceIsWater _p) then { continue };
        if (_p distance2D _basePos < _minFromBase) then { continue };
        if !(_aoCenter isEqualTo [0,0,0]) then {
            if (_p distance2D _aoCenter < _minFromAO) then { continue };
        };
        if (count (_p nearObjects ["House", 100]) > 3) then { continue };
        if (count (_p nearRoads 50) > 0) then { continue };

        private _trees = count (nearestTerrainObjects [_p, ["TREE", "SMALL TREE"], _searchRadius, false]);
        if (_trees < _minTrees) then { continue };

        private _alt = getTerrainHeightASL _p;
        if (_alt < 1 || _alt > 300) then { continue };

        // Slope check — fixed getPos calls
        private _heights = [];
        {
            private _chkPos = [_p, 20, _x] call DYN_fnc_posOffset;
            _heights pushBack (getTerrainHeightASL _chkPos);
        } forEach [0, 90, 180, 270];
        private _slopeRange = (selectMax _heights) - (selectMin _heights);
        if (_slopeRange > 8) then { continue };

        if (_trees > _bestTrees) then {
            _bestTrees = _trees;
            _bestPos = _p;
        };

        if (_trees >= 25) exitWith {
            diag_log format ["[GROUND] Excellent forest position found: %1 trees at %2", _trees, _p];
        };
    };

    if !(_bestPos isEqualTo []) then {
        diag_log format ["[GROUND] Best forest position: %1 trees at %2", _bestTrees, _bestPos];
    } else {
        diag_log "[GROUND] WARNING: No suitable forest position found";
    };

    _bestPos
};

// =====================================================
// CLEANUP FUNCTION
// =====================================================
DYN_fnc_groundCleanup = {
    diag_log "[GROUND] Running cleanup...";

    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            deleteVehicle _x;
        };
    } forEach DYN_ground_enemyVehs;

    { if (!isNull _x) then { deleteVehicle _x } } forEach DYN_ground_enemies;
    { if (!isNull _x) then { deleteVehicle _x } } forEach DYN_ground_objects;
    { if (!isNull _x) then { deleteGroup _x } } forEach DYN_ground_enemyGroups;
    { deleteMarker _x } forEach DYN_ground_markers;
    { [_x] call BIS_fnc_deleteTask } forEach DYN_ground_tasks;

    DYN_ground_objects     = [];
    DYN_ground_enemies     = [];
    DYN_ground_enemyGroups = [];
    DYN_ground_enemyVehs   = [];
    DYN_ground_tasks       = [];
    DYN_ground_markers     = [];
    DYN_ground_active      = false;

    diag_log "[GROUND] Cleanup complete.";
};

// =====================================================
// MAIN LOOP
// =====================================================
sleep 10;

diag_log "[GROUND] Ground mission system active. Entering main loop.";

while {true} do {
    if (DYN_ground_active) then {
        sleep 30;
        continue;
    };

    private _missions = [
        "scripts\groundMissions\fn_sniperHunt.sqf",
        "scripts\groundMissions\fn_convoyIntercept.sqf",
        "scripts\groundMissions\fn_captureArmsDealer.sqf"
    ];

    private _pick = selectRandom _missions;
    DYN_ground_missionCount = DYN_ground_missionCount + 1;

    diag_log format ["[GROUND] Launching mission #%1: %2", DYN_ground_missionCount, _pick];

    DYN_ground_active = true;

    DYN_ground_objects     = [];
    DYN_ground_enemies     = [];
    DYN_ground_enemyGroups = [];
    DYN_ground_enemyVehs   = [];
    DYN_ground_tasks       = [];
    DYN_ground_markers     = [];

    execVM _pick;

    // Convoy route building can take 30+ seconds
    sleep 45;

    if (!DYN_ground_active) then {
        diag_log "[GROUND] Mission failed to spawn. Cleaning up and retrying in 60 seconds...";
        call DYN_fnc_groundCleanup;
        sleep 60;
        continue;
    };

    waitUntil { sleep 10; !DYN_ground_active };

    private _cooldown = 1800;
    diag_log format ["[GROUND] Cooldown: %1 seconds", round _cooldown];
    sleep _cooldown;
};
