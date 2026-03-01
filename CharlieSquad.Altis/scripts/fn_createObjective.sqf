/*
    scripts\fn_createObjective.sqf
    CUP RUSSIAN FORCES VERSION
    v2: Road IEDs, individual civilian walkers, cleanup fixes
*/

params ["_pos", "_cityName"];
if (!isServer) exitWith {};

missionNamespace setVariable ["DYN_AO_lock", true, true];
missionNamespace setVariable ["DYN_AO_cleanupDone", false, false];

// =====================
// POOLS
// =====================
private _infantryPool = ["CUP_O_RU_Soldier_Ratnik_Autumn","CUP_O_RU_Soldier_AR_Ratnik_Autumn","CUP_O_RU_Soldier_GL_Ratnik_Autumn","CUP_O_RU_Soldier_LAT_Ratnik_Autumn","CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"];
private _garrisonPool = ["CUP_O_RU_Soldier_Ratnik_Autumn","CUP_O_RU_Soldier_AR_Ratnik_Autumn","CUP_O_RU_Soldier_GL_Ratnik_Autumn"];
private _aaInfantry = "CUP_O_RU_Soldier_AA_Ratnik_Autumn";
private _vehPool = ["CUP_O_Tigr_M_RU","CUP_O_GAZ_Vodnik_PK_RU","CUP_O_GAZ_Vodnik_AGS_RU","CUP_O_BTR80_GREEN_RU","CUP_O_BTR80A_GREEN_RU","CUP_O_BMP2_RU"];
private _civPool = ["C_man_1","C_man_polo_1_F","C_man_polo_2_F","C_man_polo_4_F"];

// =====================
// SETTINGS
// =====================
private _aoRadius = 1100;
private _spawnRadius = _aoRadius * 0.90;
private _aoStartT = diag_tickTime;

DYN_AO_active      = true;
DYN_AO_center      = _pos;
DYN_AO_radius      = _aoRadius;
DYN_AO_startT      = _aoStartT;

DYN_AO_enemies          = [];
DYN_AO_enemyGroups      = [];
DYN_AO_enemyVehs        = [];
DYN_AO_objects          = [];
DYN_AO_mines            = [];
DYN_AO_sideTasks        = [];
DYN_AO_bonusTasks       = [];
DYN_AO_civUnits         = [];
DYN_AO_civVehs          = [];
DYN_AO_hiddenTerrain    = [];
DYN_OBJ_centers         = [];
DYN_AO_hiddenObjectives = [];  // [[taskId, title, pos], ...] — revealed by resistance intel

publicVariable "DYN_AO_active";
publicVariable "DYN_AO_center";
publicVariable "DYN_AO_radius";
publicVariable "DYN_AO_hiddenObjectives";

missionNamespace setVariable ["DYN_gpsJammerDisabled", true, true];
missionNamespace setVariable ["DYN_dataLinkDisabled", true, true];

// =====================
// MARKER & TASK
// =====================
private _markerName = format ["AO_%1", round (diag_tickTime * 1000)];
createMarker [_markerName, _pos];
_markerName setMarkerShape "ELLIPSE";
_markerName setMarkerSize [_aoRadius, _aoRadius];
_markerName setMarkerColor "ColorRed";
_markerName setMarkerBrush "SolidBorder";

private _taskId = format ["task_%1", round (diag_tickTime * 1000)];
[west, _taskId, [format ["Clear enemy forces in %1.", _cityName], format ["Liberate %1", _cityName], ""], _pos, "ASSIGNED", 1, true, "attack"] remoteExec ["BIS_fnc_taskCreate", 0, true];

// Helpers
private _fn_setMaxSkill = { params ["_u"]; if (isNull _u) exitWith {}; _u setSkill 1; { _u setSkill [_x, 1.0]; } forEach ["aimingAccuracy","aimingShake","aimingSpeed","spotDistance","spotTime","courage","reloadSpeed","commanding","general"]; };
private _fn_findWaterPos = { params ["_center", "_min", "_max", ["_tries", 80]]; private _out = []; for "_t" from 1 to _tries do { private _cand = _center getPos [_min + random (_max - _min), random 360]; if (surfaceIsWater _cand) exitWith { _out = _cand; }; }; _out };

// ==================================================
// OBJECTIVES
// ==================================================
[_pos, _aoRadius] execVM "scripts\fn_fuelDepot.sqf";
[_pos, _spawnRadius] execVM "scripts\fn_radioTower.sqf";
[_pos, _aoRadius] execVM "scripts\fn_mortarPit.sqf";
[_pos, _aoRadius] execVM "scripts\fn_enemyHQ.sqf";
[_pos, _aoRadius] execVM "scripts\fn_spawnSideObjectives.sqf";
[_pos, _aoRadius] execVM "scripts\fn_dataLink.sqf";
[_pos, _aoRadius] execVM "scripts\fn_infantryPatrol.sqf";
if ((random 1) < 0.40) then { [_pos, _aoRadius] execVM "scripts\fn_gpsJammer.sqf"; };
[_pos, _aoRadius] execVM "scripts\fn_aaPits.sqf";
[_pos, _aoRadius] execVM "scripts\fn_airPatrols.sqf";
[_pos, _aoRadius] execVM "scripts\fn_resistanceAreas.sqf";

// =====================
// GARRISON
// =====================
private _houses = nearestObjects [_pos, ["House"], _aoRadius * 0.55];
_houses = _houses call BIS_fnc_arrayShuffle;
private _useCount = 18 min (count _houses);

for "_i" from 0 to (_useCount - 1) do {
    private _b = _houses select _i;
    private _positions = [_b] call BIS_fnc_buildingPositions;
    if (_positions isEqualTo []) then { continue };
    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;
    _grp setBehaviour "AWARE"; _grp setCombatMode "RED";
    for "_u" from 1 to (3 + floor (random 3)) do {
        private _p = selectRandom _positions;
        private _unit = _grp createUnit [selectRandom _garrisonPool, _p, [], 0, "NONE"];
        _unit disableAI "PATH"; _unit setUnitPos (selectRandom ["UP","MIDDLE"]); _unit allowFleeing 0;
        DYN_AO_enemies pushBack _unit;
    };
};



// =====================
// WOUNDED CIVILIANS - Spawn after rep system is ready
// =====================
[_pos, _aoRadius, _houses] spawn {
    params ["_aoPos", "_aoRad", "_nearHouses"];

    private _waitStart = diag_tickTime;
    waitUntil {
        sleep 0.5;
        !isNil "DYN_fnc_spawnWoundedCivilian" || (diag_tickTime - _waitStart) > 30
    };

    if (isNil "DYN_fnc_spawnWoundedCivilian") exitWith {
        diag_log "[CIV] ERROR: Reputation system not loaded, cannot spawn wounded civilians";
    };

    sleep 3;

    private _woundedCount = 2 + floor (random 2);
    diag_log format ["[CIV] Spawning %1 wounded civilians in AO", _woundedCount];

    for "_i" from 1 to _woundedCount do {
        private _woundPos = [];

        if (count _nearHouses > 0 && random 1 < 0.7) then {
            private _house = selectRandom _nearHouses;
            _woundPos = (getPos _house) getPos [5 + random 15, random 360];
        } else {
            _woundPos = [_aoPos, 50, _aoRad * 0.5, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
        };

        if (_woundPos isEqualTo [0,0,0]) then { continue };
        if (surfaceIsWater _woundPos) then { continue };

        private _civ = [_woundPos] call DYN_fnc_spawnWoundedCivilian;

        if (!isNull _civ) then {
            diag_log format ["[CIV] Wounded civilian %1 spawned at %2", _i, _woundPos];
        };

        sleep 1;
    };

    diag_log "[CIV] Finished spawning wounded civilians";
};

// =====================
// WALKING CIVILIANS — each walks independently, no groups
// =====================
private _civWalkerCount = 5 + floor (random 3);  // 5-7 individual civilians

for "_c" from 1 to _civWalkerCount do {
    // Each civilian gets their own group — walks alone
    private _grp = createGroup civilian;

    private _startPos = [_pos, 50, _aoRadius * 0.5, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_startPos isEqualTo [0,0,0]) then { _startPos = _pos getPos [100 + random 200, random 360]; };
    if (surfaceIsWater _startPos) then { continue };

    private _u = _grp createUnit [selectRandom _civPool, _startPos, [], 0, "NONE"];

    _u setVariable ["DYN_isCivilian", true, true];
    DYN_AO_civUnits pushBack _u;

    _u setBehaviour "CARELESS";
    _u setSpeedMode "LIMITED";
    _u disableAI "AUTOCOMBAT";
    _u disableAI "TARGET";
    _u disableAI "AUTOTARGET";
    _u setCaptive true;
    _u allowFleeing 0;

    // Each civ gets their own random waypoint route
    for "_w" from 1 to 5 do {
        private _wpPos = [_pos, 30, _aoRadius * 0.45, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_wpPos isEqualTo [0,0,0]) then { _wpPos = _pos getPos [50 + random 200, random 360]; };
        private _wp = _grp addWaypoint [_wpPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "CARELESS";
    };
    (_grp addWaypoint [_startPos, 0]) setWaypointType "CYCLE";

    // Track group for cleanup
    DYN_AO_enemyGroups pushBack _grp;
};

// =====================
// CIVILIAN VEHICLES
// =====================
private _roads2 = _pos nearRoads _aoRadius;
if !(_roads2 isEqualTo []) then {
    for "_i" from 1 to 2 do {
        private _road = selectRandom _roads2;
        private _roadPos = getPosATL _road;

        private _vehClass = selectRandom ["C_Offroad_01_F","C_Hatchback_01_F","C_SUV_01_F"];
        private _veh = createVehicle [_vehClass, _roadPos, [], 0, "NONE"];
        DYN_AO_civVehs pushBack _veh;
        _veh setDir (getDir _road);

        private _grp = createGroup civilian;
        private _driver = _grp createUnit ["C_man_1", _roadPos, [], 0, "NONE"];
        _driver setVariable ["DYN_isCivilian", true, true];
        DYN_AO_civUnits pushBack _driver;

        _driver moveInDriver _veh;
        _driver setBehaviour "CARELESS";
        _driver setSpeedMode "LIMITED";
        _driver disableAI "AUTOCOMBAT";
        _driver disableAI "TARGET";
        _driver setCaptive true;

        for "_w" from 1 to 6 do {
            private _r = selectRandom _roads2;
            private _wp = _grp addWaypoint [getPosATL _r, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "CARELESS";
        };
        (_grp addWaypoint [_roadPos, 0]) setWaypointType "CYCLE";
    };
};

// =====================
// AA INFANTRY
// =====================
for "_i" from 1 to 4 do {
    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;
    private _aaPos = [_pos, 120, _spawnRadius, 10, 0, 0.4, 0] call BIS_fnc_findSafePos;
    private _aa = _grp createUnit [_aaInfantry, _aaPos, [], 0, "FORM"];
    _aa allowFleeing 0;
    DYN_AO_enemies pushBack _aa;
    (_grp addWaypoint [_pos, 0]) setWaypointType "GUARD";
};

// =====================
// VEHICLES
// =====================
private _vehCount = 3 + floor (random 4);
for "_i" from 1 to _vehCount do {
    private _vehClass = selectRandom _vehPool;
    private _vehPos = [_pos, _aoRadius * 0.55, _aoRadius * 1.05, 10, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _vehPos) then { continue };

    private _veh = createVehicle [_vehClass, _vehPos, [], 0, "NONE"];
    createVehicleCrew _veh;

    DYN_AO_enemyVehs pushBack _veh;
    { DYN_AO_enemies pushBack _x; _x allowFleeing 0; } forEach crew _veh;

    private _grp = group (driver _veh);
    DYN_AO_enemyGroups pushBack _grp;

    for "_w" from 1 to 3 do {
        private _wpPos = [_pos, 150, _spawnRadius, 10, 0, 0.4, 0] call BIS_fnc_findSafePos;
        private _wp = _grp addWaypoint [_wpPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
    };
    (_grp addWaypoint [_vehPos, 0]) setWaypointType "CYCLE";
};

// =====================
// NAVAL PATROLS
// =====================
private _waterProbe = [_pos, 250, _aoRadius * 1.20, 90] call _fn_findWaterPos;
if !(_waterProbe isEqualTo []) then {
    for "_i" from 1 to (1 + floor (random 4)) do {
        private _spawnW = [_pos, 300, _aoRadius * 1.25, 120] call _fn_findWaterPos;
        if (_spawnW isEqualTo []) then { continue };
        private _boat = createVehicle ["O_Boat_Armed_01_hmg_F", _spawnW, [], 0, "NONE"];
        _boat setDir (random 360);
        _boat setPosASL [(_spawnW # 0), (_spawnW # 1), 0];
        createVehicleCrew _boat;
        DYN_AO_enemyVehs pushBack _boat;
        { DYN_AO_enemies pushBack _x; [_x] call _fn_setMaxSkill; } forEach (crew _boat);
        private _grp = group (driver _boat);
        DYN_AO_enemyGroups pushBack _grp;
        _grp setBehaviour "AWARE"; _grp setCombatMode "RED"; _grp setSpeedMode "FULL";
        for "_w" from 1 to 5 do {
            private _wpPos = [_pos, 350, _aoRadius * 1.35, 120] call _fn_findWaterPos;
            if (_wpPos isEqualTo []) then { continue };
            private _wp = _grp addWaypoint [_wpPos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
            _wp setWaypointBehaviour "AWARE";
        };
        (_grp addWaypoint [_spawnW, 0]) setWaypointType "CYCLE";
    };
};

// =====================
// COMPLETION & CLEANUP
// =====================
[_taskId, _markerName, _pos, _aoRadius, _aoStartT, _cityName] spawn {
    params ["_taskId", "_markerName", "_pos", "_aoRadius", "_aoStartT", "_cityName"];

    // Auto-reveal hidden objectives after 20 minutes so the AO can always complete
    // even if players skip resistance areas entirely.
    [] spawn {
        sleep 1200;
        if (!(missionNamespace getVariable ["DYN_AO_active", false])) exitWith {};
        private _hidden = missionNamespace getVariable ["DYN_AO_hiddenObjectives", []];
        if (_hidden isEqualTo []) exitWith {};
        {
            _x params ["_tid", "_ttitle", "_tpos"];
            [_tid, "ASSIGNED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        } forEach _hidden;
        missionNamespace setVariable ["DYN_AO_hiddenObjectives", [], true];
        ["TaskUpdated", ["Intel declassified", "All AO objectives have been revealed on the map."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[RESISTANCE] 20-min timer: auto-revealed all remaining hidden AO objectives";
    };

    waitUntil {
        sleep 5;
        if ((diag_tickTime - _aoStartT) < 20) exitWith { false };
        if ((count DYN_AO_sideTasks) < 3) exitWith { false };
        private _sideDone = ({ [_x] call BIS_fnc_taskCompleted } count DYN_AO_sideTasks) == count DYN_AO_sideTasks;
        private _jamDone = missionNamespace getVariable ["DYN_gpsJammerDisabled", true];
        private _killReq = missionNamespace getVariable ["DYN_AO_killRequired", 0.60];
        private _total = count DYN_AO_enemies;
        private _neutralized = { isNull _x || {!alive _x} || {_x getVariable ["DYN_prisonDelivered", false]} } count DYN_AO_enemies;
        private _killOk = (_total == 0) || ((_neutralized / _total) >= _killReq);
        _sideDone && _jamDone && _killOk
    };

    if (missionNamespace getVariable ["DYN_AO_cleanupDone", false]) exitWith { missionNamespace setVariable ["DYN_AO_lock", false, true]; };
    missionNamespace setVariable ["DYN_AO_cleanupDone", true, false];

    DYN_AO_active = false;
    publicVariable "DYN_AO_active";

    [_taskId, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
    _markerName setMarkerColor "ColorGreen";

    // Award reputation for liberating the city
    private _liberationRep = 30 + floor (random 21);
    [_liberationRep, format ["%1 Liberated", _cityName]] call DYN_fnc_changeReputation;

    { if !([_x] call BIS_fnc_taskCompleted) then { [_x, "CANCELED"] remoteExec ["BIS_fnc_taskSetState", 0, true]; }; } forEach DYN_AO_bonusTasks;
    { if (!isNull _x) then { _x hideObjectGlobal false; _x setVariable ["DYN_hiddenByAO", false, false]; }; } forEach DYN_AO_hiddenTerrain;
    DYN_AO_hiddenTerrain = [];

    { if (!isNull _x) then { deleteVehicle _x; }; } forEach DYN_AO_mines;
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach DYN_AO_objects;

    { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x; }; } forEach crew _x; deleteVehicle _x; }; } forEach DYN_AO_enemyVehs;
    { if (!isNull _x) then { if (_x getVariable ["DYN_prisonDelivered", false]) then { continue }; deleteVehicle _x; }; } forEach DYN_AO_enemies;

    { if (!isNull _x) then { deleteVehicle _x; }; } forEach DYN_AO_civVehs;
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach DYN_AO_civUnits;

    { if (!isNull _x) then { deleteGroup _x; }; } forEach DYN_AO_enemyGroups;
    DYN_AO_enemyGroups = [];

    sleep 10;
    deleteMarker _markerName;

    sleep 5;
    missionNamespace setVariable ["DYN_AO_lock", false, true];

    execVM "scripts\fn_spawnObjectives.sqf";
};
