/*
    scripts\groundMissions\fn_convoyIntercept.sqf
    GROUND MISSION: High-Value Convoy Intercept
    
    DRIVING IMPROVEMENTS:
    - forceFollowRoad on all convoy vehicles — AI sticks to road surface
    - Dense route sampling (25m spacing) — curves get 2-3x more guide points
    - Tight waypoint completion radius (12m) — no more corner cutting
    - 10-point / 200m turn lookahead with proximity weighting
    - 6-tier graduated speed (8/14/22/32/55/150 km/h)
    
    FIXES APPLIED:
    - All getPos on position arrays replaced with DYN_fnc_posOffset
    - ZSU class fallback if CFP not loaded
    - Water safety check in vehicle spawner
    - Chase vehicles get anti-ram + godmode protection
    - Driver swap mutex prevents race condition
    - GAZ spawn lateral offset prevents stacking
    - DESTROY success: !canMove OR damage >= 0.9
    - Standardized all log prefixes to [GROUND-CONVOY]
    - Surgical cleanup pattern
    
    Smart AI Driving:
    - Turn-aware speed control (slows before curves)
    - Catch-up speed: vehicles far behind truck speed up automatically
    - Direction-aware waypoint assignment per vehicle
    - 3-level stuck recovery (L1:25s L2:45s L3:70s)
    - Anti-ram: convoy vehicles ignore collision damage from each other
    - Convoy spacing: vehicles slow down when too close to vehicle ahead
    
    Post-Combat Recovery:
    - If escort vehicle destroyed after combat, 2 GAZ pickups spawn
    - GAZ vehicles load stranded troops and drive to catch up with convoy
    - Only triggers when combat over + no players nearby
    
    Convoy: ZSU + 2-4 Tigrs + BTR-80A(50%) + Objective + Rear guard
    AMMO=destroy(20-25rep) | DEVICE=capture to base(35-45rep)
    Task marker at start city only (players must find convoy)
    ACE dead body eject + 2min corpse cleanup
    Per-vehicle independent combat | NPC truck reclaim | GAZ chase squad
    MP safe
*/
if (!isServer) exitWith {};

diag_log "[GROUND-CONVOY] Setting up Convoy Intercept mission...";

if (isNil "DYN_ground_enemies") then { DYN_ground_enemies = [] };
if (isNil "DYN_ground_enemyVehs") then { DYN_ground_enemyVehs = [] };
if (isNil "DYN_ground_enemyGroups") then { DYN_ground_enemyGroups = [] };
if (isNil "DYN_ground_tasks") then { DYN_ground_tasks = [] };

private _basePos = getMarkerPos "respawn_west";
private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

// =====================================================
// HELPERS
// =====================================================

private _fn_routeOnLand = {
    params ["_posA","_posB","_steps"];
    private _valid = true;
    for "_s" from 0 to _steps do {
        private _f = _s / _steps;
        private _cx = (_posA select 0) + ((_posB select 0) - (_posA select 0)) * _f;
        private _cy = (_posA select 1) + ((_posB select 1) - (_posA select 1)) * _f;
        if (surfaceIsWater [_cx,_cy,0]) exitWith { _valid = false };
    };
    _valid
};

private _fn_ejectDead = {
    params ["_veh"];
    if (isNull _veh || !alive _veh) exitWith {0};
    private _out = 0; private _kick = [];
    {
        private _dead = !alive _x;
        if (!_dead) then {
            if (_x getVariable ["ACE_isUnconscious",false]) then {_dead=true};
            if (_x getVariable ["ace_medical_iDead",false]) then {_dead=true};
            if (_x getVariable ["ace_medical_status_isDead",false]) then {_dead=true};
        };
        if (_dead) then {_kick pushBack _x};
    } forEach crew _veh;
    {
        private _ep = [getPos _veh, 4+random 4, random 360] call DYN_fnc_posOffset;
        unassignVehicle _x; moveOut _x; _x setPosATL _ep; _out = _out + 1;
    } forEach _kick;
    _out
};

private _fn_findAheadIdx = {
    params ["_veh","_rt"];
    private _vPos = getPos _veh; private _vDir = getDir _veh;
    private _closest = 0; private _closestD = 999999;
    { private _d = _vPos distance2D _x; if (_d < _closestD) then {_closestD=_d; _closest=_forEachIndex} } forEach _rt;
    private _ahead = -1;
    for "_i" from _closest to ((count _rt)-1) do {
        private _pt = _rt select _i; private _d = _vPos distance2D _pt;
        if (_d < 15) then { continue };
        private _bearing = _vPos getDir _pt;
        private _diff = abs(_bearing - _vDir);
        if (_diff > 180) then {_diff = 360 - _diff};
        if (_diff < 120) exitWith {_ahead = _i};
    };
    if (_ahead < 0) then { _ahead = (_closest + 2) min ((count _rt)-1) };
    _ahead
};

// IMPROVED: 12m completion radius — forces vehicles through each curve point instead of cutting corners at 40m
private _fn_refreshWPs = {
    params ["_grp","_rt","_fromIdx","_bhv","_cbt","_spd"];
    while {count waypoints _grp > 0} do {deleteWaypoint [_grp,0]};
    for "_w" from _fromIdx to ((count _rt)-1) do {
        private _wp = _grp addWaypoint [_rt select _w, 5];
        _wp setWaypointType "MOVE"; _wp setWaypointSpeed _spd;
        _wp setWaypointBehaviour _bhv; _wp setWaypointCombatMode _cbt;
        _wp setWaypointCompletionRadius (if (_w == ((count _rt)-1)) then {200} else {12});
    };
    private _h = _grp addWaypoint [_rt select ((count _rt)-1), 5];
    _h setWaypointType "HOLD"; _h setWaypointBehaviour _bhv; _h setWaypointCompletionRadius 200;
};

// IMPROVED: 12m completion radius for initial assignment too
private _fn_assignInitialWPs = {
    params ["_grp","_veh","_rt","_bhv","_cbt","_spd"];
    private _vPos = getPos _veh; private _vDir = getDir _veh;
    private _closest = 0; private _closestD = 999999;
    { private _d = _vPos distance2D _x; if (_d < _closestD) then {_closestD=_d; _closest=_forEachIndex} } forEach _rt;
    private _startIdx = _closest; private _foundAhead = false;
    for "_i" from _closest to ((count _rt)-1) do {
        private _pt = _rt select _i; private _d = _vPos distance2D _pt;
        if (_d < 15) then {continue};
        private _bearing = _vPos getDir _pt;
        private _diff = abs(_bearing - _vDir);
        if (_diff > 180) then {_diff = 360 - _diff};
        if (_diff < 120) exitWith {_startIdx = _i; _foundAhead = true};
    };
    if (!_foundAhead) then { _startIdx = (_closest + 2) min ((count _rt)-1) };
    while {count waypoints _grp > 0} do {deleteWaypoint [_grp,0]};
    for "_w" from _startIdx to ((count _rt)-1) do {
        private _wp = _grp addWaypoint [_rt select _w, 5];
        _wp setWaypointType "MOVE"; _wp setWaypointSpeed _spd;
        _wp setWaypointBehaviour _bhv; _wp setWaypointCombatMode _cbt;
        _wp setWaypointCompletionRadius (if (_w == ((count _rt)-1)) then {200} else {12});
    };
    private _h = _grp addWaypoint [_rt select ((count _rt)-1), 5];
    _h setWaypointType "HOLD"; _h setWaypointBehaviour _bhv; _h setWaypointCompletionRadius 200;
    _startIdx
};

// IMPROVED: 10-point / 200m lookahead, proximity-weighted, 6-tier graduated speed
private _fn_getTurnSpeed = {
    params ["_veh","_rt","_angles"];
    private _vPos = getPos _veh;
    private _closest = 0; private _closestD = 999999;
    { private _d = _vPos distance2D _x; if (_d < _closestD) then {_closestD=_d; _closest=_forEachIndex} } forEach _rt;
    private _maxTurn = 0;
    private _weightedTurn = 0;
    for "_t" from _closest to ((_closest + 10) min ((count _angles)-1)) do {
        private _ptDist = _vPos distance2D (_rt select _t);
        if (_ptDist > 200) then { continue };
        if (_ptDist < 5) then { continue };
        private _a = _angles select _t;
        if (_a > _maxTurn) then { _maxTurn = _a };
        // Nearby turns weighted more heavily — brake earlier for close curves
        private _weight = 1 - (_ptDist / 200);
        private _weighted = _a * _weight;
        if (_weighted > _weightedTurn) then { _weightedTurn = _weighted };
    };
    private _effectiveTurn = _maxTurn max _weightedTurn;
    // 6-tier graduated speed: hairpin → gentle curve → straight
    if (_effectiveTurn > 100) exitWith { 8 };
    if (_effectiveTurn > 75) exitWith { 14 };
    if (_effectiveTurn > 55) exitWith { 22 };
    if (_effectiveTurn > 40) exitWith { 32 };
    if (_effectiveTurn > 25) exitWith { 55 };
    150
};

// Returns a speed limit based on how close the nearest vehicle ahead is
// -1 means no vehicle ahead (no spacing needed)
private _fn_convoySpacing = {
    params ["_veh"];
    private _vPos = getPos _veh;
    private _vDir = getDir _veh;
    private _closestDist = 999;
    {
        if (_x != _veh && {alive _x} && {_x getVariable ["DYN_convoyVehicle",false]}) then {
            private _d = _vPos distance2D (getPos _x);
            if (_d < 80) then {
                private _toBearing = _vPos getDir (getPos _x);
                private _angDiff = abs(_toBearing - _vDir);
                if (_angDiff > 180) then { _angDiff = 360 - _angDiff };
                if (_angDiff < 70 && _d < _closestDist) then { _closestDist = _d };
            };
        };
    } forEach DYN_ground_enemyVehs;
    // Graduated: <15m=5kph, 15-25m=12kph, 25-40m=22kph, 40-60m=40kph, >60m=no limit
    if (_closestDist < 15) exitWith { 5 };
    if (_closestDist < 25) exitWith { 12 };
    if (_closestDist < 40) exitWith { 22 };
    if (_closestDist < 60) exitWith { 40 };
    -1
};

private _fn_antiRamEH = {
    params ["_unit","_sel","_damage","_source","_projectile","_hitIndex"];
    if (_projectile isEqualTo "") then {
        private _blocked = false;
        if (!isNull _source && {_source getVariable ["DYN_convoyVehicle",false]}) then { _blocked = true };
        if (!_blocked) then {
            { if (_x != _unit && {_x getVariable ["DYN_convoyVehicle",false]} && {_x distance _unit < 15}) exitWith { _blocked = true } } forEach DYN_ground_enemyVehs;
        };
        if (_blocked) exitWith { if (_hitIndex >= 0) then {_unit getHitIndex _hitIndex} else {damage _unit} };
    };
    _damage
};

private _fn_spawnGazPickup = {
    params ["_nearPos","_dirToFace","_infPool"];
    private _gazClasses = ["CUP_O_GAZ_Vodnik_PK_RU","CUP_O_GAZ_Vodnik_AGS_RU","CUP_O_GAZ_Vodnik_BPPU_RU"];
    private _spawnPos = _nearPos;
    private _roads = _nearPos nearRoads 200;
    if (count _roads > 0) then {
        private _bestRd = _roads select 0; private _bestD = 999999;
        { private _rp = getPos _x; if (surfaceIsWater _rp) then {continue};
            if (count(_rp nearObjects ["LandVehicle",10]) > 0) then {continue};
            private _d = _rp distance2D _nearPos;
            if (_d < _bestD) then { _bestD = _d; _bestRd = _x };
        } forEach _roads;
        _spawnPos = getPos _bestRd;
    };
    if (surfaceIsWater _spawnPos) exitWith { [objNull, grpNull] };
    private _gaz = createVehicle [selectRandom _gazClasses, [0,0,0], [], 0, "NONE"];
    _gaz allowDamage false; _gaz enableSimulation false;
    sleep 0.3; { deleteVehicle _x } forEach crew _gaz;
    _gaz setDir _dirToFace;
    _gaz setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
    sleep 0.5; _gaz enableSimulation true;
    sleep 1; _gaz setVelocityModelSpace [0,0,0];
    _gaz forceFollowRoad true;
    _gaz setVariable ["DYN_convoyVehicle",true,true];
    _gaz addEventHandler ["HandleDamage", {
        params ["_unit","_sel","_damage","_source","_projectile","_hitIndex"];
        if (_projectile isEqualTo "") then {
            private _blocked = false;
            if (!isNull _source && {_source getVariable ["DYN_convoyVehicle",false]}) then { _blocked = true };
            if (!_blocked) then {
                { if (_x != _unit && {_x getVariable ["DYN_convoyVehicle",false]} && {_x distance _unit < 15}) exitWith { _blocked = true } } forEach DYN_ground_enemyVehs;
            };
            if (_blocked) exitWith { if (_hitIndex >= 0) then {_unit getHitIndex _hitIndex} else {damage _unit} };
        };
        _damage
    }];
    [_gaz] spawn { params ["_vehicle"]; sleep 30;
        if (!isNull _vehicle && alive _vehicle) then { _vehicle allowDamage true; diag_log format ["[GROUND-CONVOY] Godmode ended for GAZ %1", typeOf _vehicle] };
    };
    private _gazGrp = createGroup east; DYN_ground_enemyGroups pushBack _gazGrp;
    private _gDrv = _gazGrp createUnit [selectRandom _infPool, _spawnPos, [], 0, "NONE"];
    _gDrv moveInDriver _gaz; _gDrv allowFleeing 0; _gDrv setSkill 0.85; DYN_ground_enemies pushBack _gDrv;
    if ((_gaz emptyPositions "gunner") > 0) then {
        private _gGnr = _gazGrp createUnit [selectRandom _infPool, _spawnPos, [], 0, "NONE"];
        _gGnr moveInGunner _gaz; _gGnr allowFleeing 0; _gGnr setSkill 0.90;
        _gGnr setSkill ["aimingAccuracy",0.85]; DYN_ground_enemies pushBack _gGnr;
    };
    if ((_gaz emptyPositions "commander") > 0) then {
        private _gCdr = _gazGrp createUnit [selectRandom _infPool, _spawnPos, [], 0, "NONE"];
        _gCdr moveInCommander _gaz; _gCdr allowFleeing 0; _gCdr setSkill 0.85; DYN_ground_enemies pushBack _gCdr;
    };
    sleep 0.3;
    { DYN_ground_enemies deleteAt (DYN_ground_enemies find _x); deleteVehicle _x } forEach ((units _gazGrp) select {vehicle _x != _gaz});
    DYN_ground_enemyVehs pushBack _gaz;
    diag_log format ["[GROUND-CONVOY] GAZ pickup spawned: %1 at %2", typeOf _gaz, _spawnPos];
    [_gaz, _gazGrp]
};

// IMPROVED: 25m minimum spacing (was 60m) — curves get 2-3x more waypoints for accurate cornering
private _fn_buildRoadRoute = {
    params ["_startPos","_endPos"];
    private _route = [];
    private _startRds = _startPos nearRoads 300;
    private _endRds = _endPos nearRoads 300;
    if (count _startRds == 0 || count _endRds == 0) exitWith {[_startPos,_endPos]};
    private _cur = _startRds select 0; private _curP = getPos _cur;
    private _visited = []; private _maxS = 400; private _s = 0;
    _route pushBack _curP; _visited pushBack _cur;
    while {_s < _maxS && {_curP distance2D _endPos > 150}} do {
        _s = _s + 1;
        private _conn = roadsConnectedTo _cur;
        if (count _conn == 0) then { _conn = (_curP nearRoads 100) select {!(_x in _visited) && !surfaceIsWater(getPos _x)} };
        if (count _conn == 0) then {
            private _jp = [_curP, 200, _curP getDir _endPos] call DYN_fnc_posOffset;
            private _jr = (_jp nearRoads 200) select {!(_x in _visited) && !surfaceIsWater(getPos _x)};
            if (count _jr > 0) then { _cur = _jr select 0; _curP = getPos _cur; _visited pushBack _cur; _route pushBack _curP }
            else { _s = _maxS };
        } else {
            private _cands = _conn select {!(_x in _visited) && !surfaceIsWater(getPos _x)};
            if (count _cands == 0) then { _cands = (_curP nearRoads 150) select {!(_x in _visited) && !surfaceIsWater(getPos _x)} };
            if (count _cands == 0) then { _s = _maxS } else {
                private _bestR = _cands select 0; private _bestD = 999999;
                { private _rp = getPos _x; private _d = _rp distance2D _endPos;
                    private _nc = roadsConnectedTo _x; private _bnd = _d;
                    { private _nd = (getPos _x) distance2D _endPos; if (_nd < _bnd) then {_bnd=_nd} } forEach _nc;
                    if (_bnd < _bestD) then {_bestD=_bnd; _bestR=_x};
                } forEach _cands;
                _cur = _bestR; _curP = getPos _cur; _visited pushBack _cur;
                if (_curP distance2D (_route select (count _route - 1)) > 25) then { _route pushBack _curP };
            };
        };
        if (_s % 15 == 0) then { sleep 0.05 };
    };
    private _endRd = _endPos nearRoads 200;
    if (count _endRd > 0) then {
        private _erp = getPos (_endRd select 0);
        if (_erp distance2D (_route select (count _route-1)) > 20) then { _route pushBack _erp };
    } else { _route pushBack _endPos };
    diag_log format ["[GROUND-CONVOY] Route: %1 wp, %2 steps, %3m", count _route, _s, round(_startPos distance2D _endPos)];
    _route
};

// =====================================================
// FIND CITIES
// =====================================================
private _allCities = [];
{
    private _pos = locationPosition _x; private _type = type _x;
    if (_type in ["NameCity","NameCityCapital","NameVillage"]) then {
        if !(surfaceIsWater _pos) then {
            if (_pos distance2D _basePos > 1500) then {
                private _aoOk = true;
                if !(_aoCenter isEqualTo [0,0,0]) then { if (_pos distance2D _aoCenter < 1000) then {_aoOk=false} };
                if (_aoOk && {count(_pos nearRoads 150) > 0}) then { _allCities pushBack [_pos, text _x, _type] };
            };
        };
    };
} forEach nearestLocations [getArray(configFile >> "CfgWorlds" >> worldName >> "centerPosition"), ["NameCity","NameCityCapital","NameVillage"], worldSize];

if (count _allCities < 2) exitWith { diag_log "[GROUND-CONVOY] Not enough cities"; DYN_ground_active = false };

_allCities = _allCities call BIS_fnc_arrayShuffle;
private _startCity = []; private _endCity = []; private _found = false;
for "_i" from 0 to ((count _allCities)-1) do {
    if (_found) exitWith {};
    for "_j" from (_i+1) to ((count _allCities)-1) do {
        private _pA = (_allCities select _i) select 0; private _pB = (_allCities select _j) select 0;
        private _d = _pA distance2D _pB;
        if (_d > 4000 && _d < 15000) then {
            if ([_pA,_pB,20] call _fn_routeOnLand) then { _startCity = _allCities select _i; _endCity = _allCities select _j; _found = true };
        };
        if (_found) exitWith {};
    };
};
if (_startCity isEqualTo [] || _endCity isEqualTo []) exitWith { diag_log "[GROUND-CONVOY] No city pair"; DYN_ground_active = false };

private _startPos = _startCity select 0; private _startName = _startCity select 1;
private _endPos = _endCity select 0; private _endName = _endCity select 1;
private _startRoads = _startPos nearRoads 200; private _endRoads = _endPos nearRoads 200;
if (count _startRoads == 0 || count _endRoads == 0) exitWith { diag_log "[GROUND-CONVOY] No roads"; DYN_ground_active = false };
private _startRoadPos = getPos(selectRandom _startRoads); private _endRoadPos = getPos(selectRandom _endRoads);

// =====================================================
// SETTINGS
// =====================================================
private _timeout = 7200;
private _objectiveType = selectRandom ["AMMO","DEVICE"];
private _objectiveTruckClass = ""; private _objectiveAction = ""; private _repReward = 0; private _taskDescription = "";
if (_objectiveType == "AMMO") then {
    _objectiveTruckClass = "O_Truck_03_ammo_F"; _objectiveAction = "DESTROY";
    _repReward = 20 + floor random 6;
    _taskDescription = format ["Intelligence reports an enemy ammunition convoy departing from the vicinity of %1. The convoy carries high-priority munitions bound for frontline resupply operations.<br/><br/>The convoy's exact route and destination are unknown. You will not receive GPS tracking or route markers. Locate the convoy through reconnaissance, road patrols, and map knowledge.<br/><br/>Intercept and destroy the ammunition truck before it reaches its destination. If the convoy completes its delivery, the mission will automatically fail.<br/><br/>Last known position: near %1.", _startName];
} else {
    _objectiveTruckClass = "O_T_Truck_03_device_ghex_F"; _objectiveAction = "CAPTURE";
    _repReward = 35 + floor random 11;
    _taskDescription = format ["Intelligence indicates an enemy convoy departing from the vicinity of %1 is transporting a classified electronic device containing critical encryption hardware.<br/><br/>The convoy's exact route and destination are unknown. You will not receive GPS tracking or route markers. Locate the convoy through reconnaissance, road patrols, and map knowledge.<br/><br/>Intercept the convoy, eliminate the crew, and capture the device truck intact. Drive it back to the delivery point at base.<br/><br/>Warning: enemy reinforcements will pursue if the truck is captured. If the convoy completes its delivery, the mission will automatically fail.<br/><br/>Last known position: near %1.", _startName];
};

private _infPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn","CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn","CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn","CUP_O_RU_Soldier_AT_Ratnik_Autumn"
];

private _spawnBTR = random 1 < 0.5;
diag_log format ["[GROUND-CONVOY] %1(%2) Rep:%3 BTR:%4 | %5->%6", _objectiveType, _objectiveAction, _repReward, _spawnBTR, _startName, _endName];

// =====================================================
// BUILD ROUTE + TURN ANGLES
// =====================================================
private _routePoints = [_startRoadPos, _endRoadPos] call _fn_buildRoadRoute;
_routePoints = _routePoints select { !(surfaceIsWater _x) };
if (count _routePoints < 2) then { _routePoints = [_startRoadPos, _endRoadPos] };

private _turnAngles = [];
{
    if (_forEachIndex == 0 || _forEachIndex >= (count _routePoints - 1)) then { _turnAngles pushBack 0 } else {
        private _prev = _routePoints select (_forEachIndex-1); private _curr = _x;
        private _next = _routePoints select (_forEachIndex+1);
        private _dIn = _prev getDir _curr; private _dOut = _curr getDir _next;
        private _diff = abs(_dOut - _dIn); if (_diff > 180) then {_diff = 360 - _diff};
        _turnAngles pushBack _diff;
    };
} forEach _routePoints;

diag_log format ["[GROUND-CONVOY] Route: %1 wp | %2 sharp turns (>50deg)", count _routePoints, { _x > 50 } count _turnAngles];

// =====================================================
// ROUTE SMOOTHING — insert curve guide points at sharp turns
// This makes AI follow arcs instead of sharp angles
// =====================================================
private _smoothedRoute = [];
{
    private _idx = _forEachIndex;
    private _pt = _x;
    private _angle = _turnAngles select _idx;

    if (_idx > 0 && _idx < (count _routePoints - 1) && _angle > 40) then {
        private _prev = _routePoints select (_idx - 1);
        private _next = _routePoints select (_idx + 1);

        // Distance to pull control points back from the corner
        private _pullback = if (_angle > 80) then {25} else {if (_angle > 60) then {18} else {12}};
        private _distPrev = _pt distance2D _prev;
        private _distNext = _pt distance2D _next;
        _pullback = _pullback min (_distPrev * 0.4) min (_distNext * 0.4);

        if (_pullback > 5) then {
            // Entry point — on the line from prev toward corner
            private _dirFromPrev = _prev getDir _pt;
            private _entryPt = [_pt, _pullback, _dirFromPrev + 180] call DYN_fnc_posOffset;

            // Exit point — on the line from corner toward next
            private _dirToNext = _pt getDir _next;
            private _exitPt = [_pt, _pullback, _dirToNext] call DYN_fnc_posOffset;

            // Midpoint — averaged curve apex (Bezier midpoint)
            private _midX = ((_entryPt select 0) + (_pt select 0) + (_exitPt select 0)) / 3;
            private _midY = ((_entryPt select 1) + (_pt select 1) + (_exitPt select 1)) / 3;
            private _midPt = [_midX, _midY, 0];

            // Snap guide points to nearest road if possible
            {
                private _rds = _x nearRoads 15;
                if (count _rds > 0) then { _x = getPos (_rds select 0) };
            } forEach [_entryPt, _midPt, _exitPt];

            _smoothedRoute pushBack _entryPt;
            if (_angle > 60) then { _smoothedRoute pushBack _midPt };
            _smoothedRoute pushBack _exitPt;
        } else {
            _smoothedRoute pushBack _pt;
        };
    } else {
        _smoothedRoute pushBack _pt;
    };
} forEach _routePoints;

// Rebuild turn angles for the smoothed route
_routePoints = _smoothedRoute;
_turnAngles = [];
{
    if (_forEachIndex == 0 || _forEachIndex >= (count _routePoints - 1)) then { _turnAngles pushBack 0 } else {
        private _prev = _routePoints select (_forEachIndex-1); private _curr = _x;
        private _next = _routePoints select (_forEachIndex+1);
        private _dIn = _prev getDir _curr; private _dOut = _curr getDir _next;
        private _diff = abs(_dOut - _dIn); if (_diff > 180) then {_diff = 360 - _diff};
        _turnAngles pushBack _diff;
    };
} forEach _routePoints;

diag_log format ["[GROUND-CONVOY] Smoothed route: %1 wp (was %2) | max remaining turn: %3 deg",
    count _routePoints, count _smoothedRoute, selectMax _turnAngles];

// =====================================================
// SPAWN VEHICLE (30s godmode + anti-ram + water safety + forceFollowRoad)
// =====================================================
private _convoyDir = _startRoadPos getDir _endRoadPos;

private _fn_spawnConvoyVehicle = {
    params ["_class","_pos","_dir"];
    private _safePos = _pos; private _foundRoad = false;
    for "_r" from 10 to 100 step 10 do {
        { private _rp = getPos _x; if (surfaceIsWater _rp) then {continue};
            if (count(_rp nearObjects ["House",12]) > 0) then {continue};
            if (count(_rp nearObjects ["LandVehicle",10]) > 0) then {continue};
            if (count(nearestTerrainObjects [_rp, ["TREE","SMALL TREE","ROCK"], 6, false]) > 0) then {continue};
            _safePos = _rp; _foundRoad = true;
        } forEach (_pos nearRoads _r);
        if (_foundRoad) exitWith {};
    };
    if (surfaceIsWater _safePos) then {
        for "_a" from 0 to 330 step 30 do {
            private _tryP = [_pos, 50, _a] call DYN_fnc_posOffset;
            if !(surfaceIsWater _tryP) exitWith { _safePos = _tryP };
        };
    };
    if (surfaceIsWater _safePos) exitWith { diag_log format ["[GROUND-CONVOY] WARN: water spawn blocked for %1", _class]; objNull };
    private _v = createVehicle [_class, [0,0,0], [], 0, "NONE"];
    _v allowDamage false; _v enableSimulation false;
    sleep 0.3; { deleteVehicle _x } forEach crew _v;
    _v setDir _dir;
    _v setPosATL [_safePos select 0, _safePos select 1, 0];
    sleep 0.5; _v enableSimulation true;
    sleep 2; _v setVelocityModelSpace [0,0,0];
    _v setVariable ["DYN_isDismounting", false, true];
    _v setVariable ["DYN_convoyVehicle", true, true];
    // IMPROVED: force AI to stay on road surface
    _v forceFollowRoad true;
    _v addEventHandler ["HandleDamage", {
        params ["_unit","_sel","_damage","_source","_projectile","_hitIndex"];
        if (_projectile isEqualTo "") then {
            private _blocked = false;
            if (!isNull _source && {_source getVariable ["DYN_convoyVehicle",false]}) then { _blocked = true };
            if (!_blocked) then {
                { if (_x != _unit && {_x getVariable ["DYN_convoyVehicle",false]} && {_x distance _unit < 15}) exitWith { _blocked = true } } forEach DYN_ground_enemyVehs;
            };
            if (_blocked) exitWith { if (_hitIndex >= 0) then {_unit getHitIndex _hitIndex} else {damage _unit} };
        };
        _damage
    }];
    [_v] spawn { params ["_vehicle"]; sleep 30;
        if (!isNull _vehicle && alive _vehicle) then { _vehicle allowDamage true; diag_log format ["[GROUND-CONVOY] Godmode ended for %1", typeOf _vehicle] };
    };
    _v
};

private _lineupPos = _startRoadPos;
private _lr = _startRoadPos nearRoads 150;
if (count _lr > 0) then { _lineupPos = getPos(_lr select 0) };
private _spawnPositions = []; private _lastSP = _lineupPos;
for "_i" from 0 to 14 do {
    private _tp = [_lastSP, 65, _convoyDir+180] call DYN_fnc_posOffset;
    private _nr = _tp nearRoads 80;
    if (count _nr > 0) then {
        private _br = _nr select 0; private _bb = 0;
        { private _rp = getPos _x; if (surfaceIsWater _rp) then {continue};
            private _bd = _rp distance2D _lastSP;
            if (_bd > _bb && _bd > 20) then {_bb=_bd; _br=_x};
        } forEach _nr; _tp = getPos _br;
    };
    if !(surfaceIsWater _tp) then { _spawnPositions pushBack _tp; _lastSP = _tp };
    sleep 0.05;
};
if (count _spawnPositions < 8) then {
    _spawnPositions = [];
    for "_i" from 0 to 14 do { _spawnPositions pushBack ([_lineupPos, _i*65, _convoyDir+180] call DYN_fnc_posOffset) };
};

private _fn_idx = { params["_i"]; _i min ((count _spawnPositions)-1) };
private _allCargoGroups = []; private _escortGroups = []; private _escortVehicles = [];
private _allSmartDriveVehs = []; private _nextIdx = 0;

// =====================================================
// ZSU LEAD
// =====================================================
private _zsuClass = if (isClass(configFile >> "CfgVehicles" >> "CUP_O_Ural_ZU23_RU")) then {"CUP_O_Ural_ZU23_RU"} else {"O_APC_Tracked_02_AA_F"};
private _zsu = [_zsuClass, _spawnPositions select ([_nextIdx] call _fn_idx), _convoyDir] call _fn_spawnConvoyVehicle;
_nextIdx = _nextIdx + 1;
if (isNull _zsu) exitWith { diag_log "[GROUND-CONVOY] ZSU spawn failed"; DYN_ground_active = false };
private _zsuGrp = createGroup east; DYN_ground_enemyGroups pushBack _zsuGrp;
private _zsuD = _zsuGrp createUnit [selectRandom _infPool, getPos _zsu, [], 0, "NONE"];
_zsuD moveInDriver _zsu; _zsuD allowFleeing 0; _zsuD setSkill 0.85; DYN_ground_enemies pushBack _zsuD;
private _zsuG = _zsuGrp createUnit [selectRandom _infPool, getPos _zsu, [], 0, "NONE"];
_zsuG moveInGunner _zsu; _zsuG allowFleeing 0; _zsuG setSkill 0.90;
_zsuG setSkill ["aimingAccuracy",0.90]; _zsuG setSkill ["spotDistance",1.0]; DYN_ground_enemies pushBack _zsuG;
sleep 0.5;
{ DYN_ground_enemies deleteAt (DYN_ground_enemies find _x); deleteVehicle _x } forEach ((units _zsuGrp) select {vehicle _x != _zsu});
DYN_ground_enemyVehs pushBack _zsu;
_allSmartDriveVehs pushBack [_zsu, _zsuGrp, "SAFE", "RED"];
sleep 4;

// =====================================================
// FRONT TIGRS
// =====================================================
private _tigrClasses = ["CUP_O_Tigr_M_233114_RU","CUP_O_Tigr_M_233114_KORD_RU"];
private _tigrCount = 2 + floor random 3;
private _frontTigrCount = (_tigrCount - 1) max 1;
for "_i" from 1 to _frontTigrCount do {
    private _si = [_nextIdx] call _fn_idx; _nextIdx = _nextIdx + 1;
    private _tigr = [selectRandom _tigrClasses, _spawnPositions select _si, _convoyDir] call _fn_spawnConvoyVehicle;
    if (isNull _tigr) then { continue };
    private _cGrp = createGroup east; DYN_ground_enemyGroups pushBack _cGrp; _escortGroups pushBack _cGrp;
    private _td = _cGrp createUnit [selectRandom _infPool, getPos _tigr, [], 0, "NONE"];
    _td moveInDriver _tigr; _td allowFleeing 0; _td setSkill 0.85; DYN_ground_enemies pushBack _td;
    if ((_tigr emptyPositions "gunner") > 0) then {
        private _tg = _cGrp createUnit [selectRandom _infPool, getPos _tigr, [], 0, "NONE"];
        _tg moveInGunner _tigr; _tg allowFleeing 0; _tg setSkill 0.90;
        _tg setSkill ["aimingAccuracy",0.85]; DYN_ground_enemies pushBack _tg;
    };
    private _cgGrp = createGroup east; DYN_ground_enemyGroups pushBack _cgGrp;
    _allCargoGroups pushBack [_cgGrp, _tigr, _cGrp];
    private _mc = _tigr emptyPositions "cargo";
    for "_p" from 1 to _mc do {
        private _ps = _cgGrp createUnit [selectRandom _infPool, getPos _tigr, [], 0, "NONE"];
        _ps moveInCargo _tigr; _ps allowFleeing 0; _ps setSkill 0.80; DYN_ground_enemies pushBack _ps;
    };
    DYN_ground_enemyVehs pushBack _tigr; _escortVehicles pushBack _tigr;
    _allSmartDriveVehs pushBack [_tigr, _cGrp, "SAFE", "RED"];
    _cGrp setBehaviour "SAFE"; _cGrp setCombatMode "RED";
    _cgGrp setBehaviour "SAFE"; _cgGrp setCombatMode "RED";
    _tigr setVariable ["DYN_escortVehicle",true,true];
    _tigr setVariable ["DYN_crewGroup",_cGrp,true]; _tigr setVariable ["DYN_cargoGroup",_cgGrp,true];
    sleep 4;
};

// =====================================================
// BTR-80A (50%)
// =====================================================
private _btr = objNull;
if (_spawnBTR) then {
    private _bi = [_nextIdx] call _fn_idx; _nextIdx = _nextIdx + 1;
    _btr = ["CUP_O_BTR80A_CSAT_T", _spawnPositions select _bi, _convoyDir] call _fn_spawnConvoyVehicle;
    if (!isNull _btr) then {
        private _bCG = createGroup east; DYN_ground_enemyGroups pushBack _bCG; _escortGroups pushBack _bCG;
        private _bd = _bCG createUnit [selectRandom _infPool, getPos _btr, [], 0, "NONE"];
        _bd moveInDriver _btr; _bd allowFleeing 0; _bd setSkill 0.85; DYN_ground_enemies pushBack _bd;
        if ((_btr emptyPositions "gunner") > 0) then {
            private _bg = _bCG createUnit [selectRandom _infPool, getPos _btr, [], 0, "NONE"];
            _bg moveInGunner _btr; _bg allowFleeing 0; _bg setSkill 0.92;
            _bg setSkill ["aimingAccuracy",0.90]; _bg setSkill ["spotDistance",1.0]; DYN_ground_enemies pushBack _bg;
        };
        if ((_btr emptyPositions "commander") > 0) then {
            private _bc = _bCG createUnit [selectRandom _infPool, getPos _btr, [], 0, "NONE"];
            _bc moveInCommander _btr; _bc allowFleeing 0; _bc setSkill 0.85; DYN_ground_enemies pushBack _bc;
        };
        sleep 0.5;
        { DYN_ground_enemies deleteAt (DYN_ground_enemies find _x); deleteVehicle _x } forEach ((units _bCG) select {vehicle _x != _btr});
        private _bCargo = createGroup east; DYN_ground_enemyGroups pushBack _bCargo;
        _allCargoGroups pushBack [_bCargo, _btr, _bCG];
        private _bmc = _btr emptyPositions "cargo";
        for "_p" from 1 to _bmc do {
            private _bp = _bCargo createUnit [selectRandom _infPool, getPos _btr, [], 0, "NONE"];
            _bp moveInCargo _btr; _bp allowFleeing 0; _bp setSkill 0.82; DYN_ground_enemies pushBack _bp;
        };
        DYN_ground_enemyVehs pushBack _btr; _escortVehicles pushBack _btr;
        _allSmartDriveVehs pushBack [_btr, _bCG, "SAFE", "RED"];
        _bCG setBehaviour "SAFE"; _bCG setCombatMode "RED";
        _bCargo setBehaviour "SAFE"; _bCargo setCombatMode "RED";
        _btr setVariable ["DYN_escortVehicle",true,true];
        _btr setVariable ["DYN_crewGroup",_bCG,true]; _btr setVariable ["DYN_cargoGroup",_bCargo,true];
        sleep 4;
    };
};

// =====================================================
// OBJECTIVE TRUCK
// =====================================================
private _convoyGrp = createGroup east; DYN_ground_enemyGroups pushBack _convoyGrp;
private _oi = [_nextIdx] call _fn_idx; _nextIdx = _nextIdx + 1;
private _objTruck = [_objectiveTruckClass, _spawnPositions select _oi, _convoyDir] call _fn_spawnConvoyVehicle;
if (isNull _objTruck) exitWith { diag_log "[GROUND-CONVOY] Objective truck spawn failed"; DYN_ground_active = false };
private _objDriver = _convoyGrp createUnit [selectRandom _infPool, getPos _objTruck, [], 0, "NONE"];
_objDriver moveInDriver _objTruck; _objDriver allowFleeing 0; _objDriver setSkill 0.85;
DYN_ground_enemies pushBack _objDriver;
DYN_ground_enemyVehs pushBack _objTruck;
_objTruck setVariable ["DYN_isObjectiveTruck",true,true];
_objTruck setVariable ["DYN_objectiveType",_objectiveType,true];
_objTruck setVariable ["DYN_objectiveAction",_objectiveAction,true];
_objTruck setVariable ["DYN_objDriver",_objDriver,true];
sleep 4;

// =====================================================
// REAR GUARD
// =====================================================
if (_tigrCount > 1) then {
    private _ri = [_nextIdx] call _fn_idx; _nextIdx = _nextIdx + 1;
    private _rTigr = [selectRandom _tigrClasses, _spawnPositions select _ri, _convoyDir] call _fn_spawnConvoyVehicle;
    if (!isNull _rTigr) then {
        private _rcG = createGroup east; DYN_ground_enemyGroups pushBack _rcG; _escortGroups pushBack _rcG;
        private _rd = _rcG createUnit [selectRandom _infPool, getPos _rTigr, [], 0, "NONE"];
        _rd moveInDriver _rTigr; _rd allowFleeing 0; _rd setSkill 0.85; DYN_ground_enemies pushBack _rd;
        if ((_rTigr emptyPositions "gunner") > 0) then {
            private _rg = _rcG createUnit [selectRandom _infPool, getPos _rTigr, [], 0, "NONE"];
            _rg moveInGunner _rTigr; _rg allowFleeing 0; _rg setSkill 0.90;
            _rg setSkill ["aimingAccuracy",0.85]; DYN_ground_enemies pushBack _rg;
        };
        private _rCargo = createGroup east; DYN_ground_enemyGroups pushBack _rCargo;
        _allCargoGroups pushBack [_rCargo, _rTigr, _rcG];
        private _rmc = _rTigr emptyPositions "cargo";
        for "_p" from 1 to _rmc do {
            private _rp = _rCargo createUnit [selectRandom _infPool, getPos _rTigr, [], 0, "NONE"];
            _rp moveInCargo _rTigr; _rp allowFleeing 0; _rp setSkill 0.80; DYN_ground_enemies pushBack _rp;
        };
        DYN_ground_enemyVehs pushBack _rTigr; _escortVehicles pushBack _rTigr;
        _allSmartDriveVehs pushBack [_rTigr, _rcG, "SAFE", "RED"];
        _rcG setBehaviour "SAFE"; _rcG setCombatMode "RED";
        _rCargo setBehaviour "SAFE"; _rCargo setCombatMode "RED";
        _rTigr setVariable ["DYN_escortVehicle",true,true];
        _rTigr setVariable ["DYN_crewGroup",_rcG,true]; _rTigr setVariable ["DYN_cargoGroup",_rCargo,true];
        sleep 4;
    };
};

diag_log format ["[GROUND-CONVOY] Convoy: ZSU + %1 Tigrs + %2 BTR + Obj | %3 cargo groups",
    _tigrCount, if (_spawnBTR) then {"1"} else {"0"}, count _allCargoGroups];

// =====================================================
// DIRECTION-AWARE WAYPOINTS
// =====================================================
[_convoyGrp, _objTruck, _routePoints, "CARELESS", "GREEN", "LIMITED"] call _fn_assignInitialWPs;
_convoyGrp setBehaviour "CARELESS"; _convoyGrp setCombatMode "GREEN"; _convoyGrp setSpeedMode "LIMITED";
_objDriver disableAI "AUTOCOMBAT"; _objDriver disableAI "SUPPRESSION";
_objDriver disableAI "TARGET"; _objDriver disableAI "AUTOTARGET";

[_zsuGrp, _zsu, _routePoints, "SAFE", "RED", "LIMITED"] call _fn_assignInitialWPs;
_zsuGrp setBehaviour "SAFE"; _zsuGrp setCombatMode "RED"; _zsuGrp setSpeedMode "LIMITED";

{ private _eg = _x; private _ev = objNull;
    { if (vehicle _x != _x) exitWith { _ev = vehicle _x } } forEach units _eg;
    if (!isNull _ev) then { [_eg, _ev, _routePoints, "SAFE", "RED", "LIMITED"] call _fn_assignInitialWPs };
    _eg setSpeedMode "LIMITED";
} forEach _escortGroups;

// =====================================================
// SMART DRIVING - ESCORT
// =====================================================
{ _x params ["_sdVeh","_sdGrp","_sdBhv","_sdCbt"];
    [_sdVeh, _sdGrp, _routePoints, _turnAngles, _endRoadPos, _sdBhv, _sdCbt, _objTruck, _fn_ejectDead, _fn_findAheadIdx, _fn_refreshWPs, _fn_getTurnSpeed, _fn_convoySpacing] spawn {
        params ["_veh","_grp","_route","_angles","_dest","_bhv","_cbt","_truck","_fnEject","_fnAhead","_fnRefresh","_fnTurnSpd","_fnSpacing"];
        if (!isServer) exitWith {};
        private _lastPos = getPos _veh; private _stuckTime = 0; private _recoveries = 0;
        private _label = typeOf _veh; private _l1Done = false; private _l2Done = false;
        sleep 15; _lastPos = getPos _veh;
        while {!isNull _veh && alive _veh && canMove _veh && !isNull _truck && alive _truck} do {
            sleep 3; [_veh] call _fnEject;
            private _drv = driver _veh;
            if (isNull _drv || !alive _drv || isPlayer _drv) then { _stuckTime=0; _l1Done=false; _l2Done=false; _lastPos=getPos _veh; _veh limitSpeed 150; continue };
            if (_veh getVariable ["DYN_isDismounting",false]) then { _stuckTime=0; _l1Done=false; _l2Done=false; _lastPos=getPos _veh; _veh limitSpeed 150; continue };
            private _curPos = getPos _veh;
            if (_curPos distance2D _dest < 300) then { _lastPos=_curPos; _stuckTime=0; _veh limitSpeed 150; continue };
            // Graduated convoy spacing
            private _spacingLimit = [_veh] call _fnSpacing;
            if (_spacingLimit > 0) then {
                _veh limitSpeed _spacingLimit;
                _grp setSpeedMode "LIMITED";
                _lastPos = _curPos;
                _stuckTime = 0; _l1Done = false; _l2Done = false;
                continue
            };
            private _distToTruck = _curPos distance2D (getPos _truck); private _catchingUp = false;
            if (_distToTruck > 800) then { _grp setSpeedMode "FULL"; _veh limitSpeed 150; _catchingUp = true }
            else { if (_distToTruck > 400) then { _grp setSpeedMode "NORMAL"; _veh limitSpeed 80; _catchingUp = true } else { _grp setSpeedMode "LIMITED" } };
            if (!_catchingUp) then { private _turnLimit = [_veh, _route, _angles] call _fnTurnSpd; _veh limitSpeed _turnLimit };
            private _moved = _curPos distance2D _lastPos;
            if (_moved < 3 && abs(speed _veh) < 3) then {
                _stuckTime = _stuckTime + 3;
                if (_stuckTime >= 25 && !_l1Done) then { _l1Done=true; _veh limitSpeed 150;
                    private _ai = [_veh, _route] call _fnAhead; [_grp, _route, _ai, _bhv, _cbt, "LIMITED"] call _fnRefresh;
                    _grp setBehaviour _bhv; _grp setSpeedMode "LIMITED"; _recoveries=_recoveries+1;
                    diag_log format ["[GROUND-CONVOY] %1 L1 stuck #%2", _label, _recoveries];
                };
                if (_stuckTime >= 45 && !_l2Done) then { _l2Done=true; _veh limitSpeed 150;
                    _veh setVelocityModelSpace [0,-3,0]; sleep 3; _veh setVelocityModelSpace [0,0,0]; sleep 0.5;
                    private _ai = [_veh, _route] call _fnAhead; _veh setDir ((getPos _veh) getDir (_route select _ai));
                    sleep 0.3; _veh setVelocityModelSpace [0,4,0]; sleep 2;
                    [_grp, _route, _ai, _bhv, _cbt, "LIMITED"] call _fnRefresh; _grp setBehaviour _bhv; _grp setSpeedMode "LIMITED";
                    _stuckTime=15; _recoveries=_recoveries+1; diag_log format ["[GROUND-CONVOY] %1 L2 stuck #%2", _label, _recoveries];
                };
                if (_stuckTime >= 70) then { _veh limitSpeed 150;
                    private _ai = [_veh, _route] call _fnAhead; _ai = (_ai + 3) min ((count _route)-1);
                    private _tpP = _route select _ai; private _tR = _tpP nearRoads 100;
                    if (count _tR > 0) then { private _rp = getPos(_tR select 0); if !(surfaceIsWater _rp) then {_tpP=_rp} };
                    _veh setVelocityModelSpace [0,0,0]; sleep 0.3;
                    private _nxt = _route select ((_ai+1) min ((count _route)-1));
                    _veh setDir (_tpP getDir _nxt); _veh setPosATL [_tpP select 0, _tpP select 1, 0];
                    sleep 1; _veh setVelocityModelSpace [0,3,0];
                    [_grp, _route, _ai, _bhv, _cbt, "LIMITED"] call _fnRefresh; _grp setBehaviour _bhv; _grp setSpeedMode "LIMITED";
                    _stuckTime=0; _l1Done=false; _l2Done=false; _recoveries=_recoveries+1;
                    diag_log format ["[GROUND-CONVOY] %1 L3 stuck #%2", _label, _recoveries];
                };
            } else { if (_stuckTime > 0) then { _stuckTime = (_stuckTime - 2) max 0 }; if (_stuckTime < 20) then { _l1Done = false }; if (_stuckTime < 40) then { _l2Done = false } };
            _lastPos = _curPos;
        };
        _veh limitSpeed 150; diag_log format ["[GROUND-CONVOY] %1 drive ended | recoveries:%2", _label, _recoveries];
    };
} forEach _allSmartDriveVehs;

// =====================================================
// OBJECTIVE TRUCK MONITOR
// =====================================================
[_objTruck, _convoyGrp, _routePoints, _turnAngles, _endRoadPos, _infPool, _allCargoGroups, _fn_ejectDead, _fn_findAheadIdx, _fn_refreshWPs, _fn_getTurnSpeed, _fn_convoySpacing] spawn {
    params ["_truck","_grp","_route","_angles","_dest","_pool","_cargoData","_fnEject","_fnAhead","_fnRefresh","_fnTurnSpd","_fnSpacing"];
    if (!isServer) exitWith {};
    private _takenByPlayer = false; private _lastPos = getPos _truck;
    private _stuckTime = 0; private _recoveries = 0; private _l1Done = false; private _l2Done = false;
    sleep 15; _lastPos = getPos _truck;
    while {!isNull _truck && alive _truck && canMove _truck} do {
        sleep 3; if (isNull _truck || !alive _truck) exitWith {};
        [_truck] call _fnEject;
        private _drv = driver _truck;
        if (!isNull _drv && alive _drv && (isPlayer _drv || {side group _drv == west})) then { _takenByPlayer = true };
        if (_takenByPlayer) exitWith {};
        if (isNull _drv || !alive _drv) then {
            _stuckTime=0; _l1Done=false; _l2Done=false; _truck limitSpeed 150;
            if (_truck getVariable ["DYN_driverSwapInProgress",false]) then { continue };
            _truck setVariable ["DYN_driverSwapInProgress",true,true];
            private _newD = objNull;
            { _x params ["_cg","_cv","_cc"]; if (!isNull _newD) then {continue};
                { if (alive _x && vehicle _x == _x && _x distance2D _truck < 300) exitWith {_newD=_x} } forEach units _cg;
            } forEach _cargoData;
            if (isNull _newD) then { { if (alive _x && side group _x == east && vehicle _x == _x && !isPlayer _x && _x distance2D _truck < 400) exitWith {_newD=_x} } forEach (_truck nearEntities ["Man",400]) };
            if (isNull _newD) then { { _x params ["_cg","_cv","_cc"]; if (!isNull _newD) then {continue};
                { if (alive _x && vehicle _x != _truck && _x distance2D _truck < 500) exitWith { unassignVehicle _x; moveOut _x; _newD=_x } } forEach units _cg;
            } forEach _cargoData };
            if (!isNull _newD) then {
                [_newD] joinSilent _grp; _newD doMove (getPos _truck); private _mt = 0;
                while {_newD distance2D _truck > 8 && _mt < 45 && alive _newD && alive _truck} do { _newD doMove(getPos _truck); sleep 2; _mt=_mt+2 };
                if (alive _newD && alive _truck) then {
                    _newD moveInDriver _truck; sleep 1;
                    if (driver _truck == _newD) then {
                        _newD allowFleeing 0; { _newD disableAI _x } forEach ["AUTOCOMBAT","SUPPRESSION","TARGET","AUTOTARGET"];
                        _truck setVariable ["DYN_objDriver",_newD,true];
                        private _ai = [_truck, _route] call _fnAhead;
                        [_grp, _route, _ai, "CARELESS", "GREEN", "LIMITED"] call _fnRefresh;
                        _grp setBehaviour "CARELESS"; _grp setCombatMode "GREEN"; _grp setSpeedMode "LIMITED";
                        _lastPos = getPos _truck;
                    };
                };
            };
            _truck setVariable ["DYN_driverSwapInProgress",false,true];
        } else {
            _grp setBehaviour "CARELESS"; _grp setCombatMode "GREEN"; _grp setSpeedMode "LIMITED";
            private _curPos = getPos _truck;
            if (_truck distance2D _dest < 300) then { _lastPos=_curPos; _stuckTime=0; _truck limitSpeed 150; continue };
            // Graduated convoy spacing
            private _spacingLimit = [_truck] call _fnSpacing;
            if (_spacingLimit > 0) then {
                _truck limitSpeed _spacingLimit;
                _grp setSpeedMode "LIMITED";
                _lastPos = _curPos;
                _stuckTime = 0; _l1Done = false; _l2Done = false;
                continue
            };
            private _tl = [_truck, _route, _angles] call _fnTurnSpd; _truck limitSpeed _tl;
            private _moved = _curPos distance2D _lastPos;
            if (_moved < 3 && abs(speed _truck) < 3) then {
                _stuckTime = _stuckTime + 3;
                if (_stuckTime >= 25 && !_l1Done) then { _l1Done=true; _truck limitSpeed 150;
                    private _ai = [_truck, _route] call _fnAhead;
                    [_grp, _route, _ai, "CARELESS", "GREEN", "LIMITED"] call _fnRefresh;
                    _grp setBehaviour "CARELESS"; _grp setCombatMode "GREEN"; _grp setSpeedMode "LIMITED";
                    private _d2 = driver _truck; if (!isNull _d2) then { { _d2 disableAI _x } forEach ["AUTOCOMBAT","SUPPRESSION","TARGET","AUTOTARGET"] };
                    _recoveries = _recoveries + 1;
                };
                if (_stuckTime >= 45 && !_l2Done) then { _l2Done=true; _truck limitSpeed 150;
                    _truck setVelocityModelSpace [0,-3,0]; sleep 3; _truck setVelocityModelSpace [0,0,0]; sleep 0.5;
                    private _ai = [_truck, _route] call _fnAhead; _truck setDir ((getPos _truck) getDir (_route select _ai));
                    sleep 0.3; _truck setVelocityModelSpace [0,4,0]; sleep 2;
                    [_grp, _route, _ai, "CARELESS", "GREEN", "LIMITED"] call _fnRefresh;
                    _grp setBehaviour "CARELESS"; _grp setCombatMode "GREEN"; _grp setSpeedMode "LIMITED";
                    private _d2 = driver _truck; if (!isNull _d2) then { { _d2 disableAI _x } forEach ["AUTOCOMBAT","SUPPRESSION","TARGET","AUTOTARGET"] };
                    _stuckTime = 15; _recoveries = _recoveries + 1;
                };
                if (_stuckTime >= 70) then { _truck limitSpeed 150;
                    private _ai = [_truck, _route] call _fnAhead; _ai = (_ai + 3) min ((count _route)-1);
                    private _tpP = _route select _ai; private _tR = _tpP nearRoads 100;
                    if (count _tR > 0) then { private _rp = getPos(_tR select 0); if !(surfaceIsWater _rp) then {_tpP=_rp} };
                    _truck setVelocityModelSpace [0,0,0]; sleep 0.3;
                    private _nxt = _route select ((_ai+1) min ((count _route)-1));
                    _truck setDir (_tpP getDir _nxt); _truck setPosATL [_tpP select 0, _tpP select 1, 0];
                    sleep 1; _truck setVelocityModelSpace [0,3,0];
                    [_grp, _route, _ai, "CARELESS", "GREEN", "LIMITED"] call _fnRefresh;
                    _grp setBehaviour "CARELESS"; _grp setCombatMode "GREEN"; _grp setSpeedMode "LIMITED";
                    private _d2 = driver _truck; if (!isNull _d2) then { { _d2 disableAI _x } forEach ["AUTOCOMBAT","SUPPRESSION","TARGET","AUTOTARGET"] };
                    _stuckTime=0; _l1Done=false; _l2Done=false; _recoveries = _recoveries + 1;
                };
            } else { if (_stuckTime > 0) then { _stuckTime = (_stuckTime - 2) max 0 }; if (_stuckTime < 20) then { _l1Done = false }; if (_stuckTime < 40) then { _l2Done = false } };
            _lastPos = _curPos;
        };
    };
    _truck limitSpeed 150;
};

// =====================================================
// PER-VEHICLE DISMOUNT / CREW SWAP / GAZ PICKUP / REMOUNT
// =====================================================
{ _x params ["_cargoGrp","_veh","_crewGrp"];
    [_cargoGrp, _veh, _crewGrp, _objTruck, _routePoints, _turnAngles, _fn_ejectDead, _fn_findAheadIdx, _fn_refreshWPs, _fn_spawnGazPickup, _infPool, _fn_convoySpacing] spawn {
        params ["_cargoGrp","_veh","_crewGrp","_objTruck","_route","_angles","_fnEject","_fnAhead","_fnRefresh","_fnSpawnGaz","_infPool","_fnSpacing"];
        if (!isServer) exitWith {};
        private _hasDismounted = false; private _vType = typeOf _veh; private _gazPickupSpawned = false;
        waitUntil { sleep 3;
            if (isNull _objTruck || !alive _objTruck) exitWith {true}; if (isNull _veh || !alive _veh) exitWith {true};
            [_veh] call _fnEject; private _c = false;
            if (behaviour leader _crewGrp == "COMBAT") then {_c=true};
            if (!_c && damage _veh > 0.05) then {_c=true};
            if (!_c) then { { if (alive _x && isPlayer _x && _x distance2D _veh < 300) exitWith {_c=true} } forEach allPlayers };
            if (!_c) then { { if (alive _x && behaviour _x == "COMBAT") exitWith {_c=true} } forEach units _crewGrp };
            _c
        };
        if (isNull _veh || !alive _veh || isNull _objTruck || !alive _objTruck) exitWith {};
        _hasDismounted = true; _veh setVariable ["DYN_isDismounting",true,true];
        private _cDrv = driver _veh; if (!isNull _cDrv && alive _cDrv) then { _cDrv disableAI "MOVE" };
        private _wt = 0;
        while {abs(speed _veh) > 5 && _wt < 15} do { _veh setVelocityModelSpace [0,0,0]; sleep 1; _wt=_wt+1 };
        _veh setVelocityModelSpace [0,0,0]; sleep 0.5; [_veh] call _fnEject; sleep 0.3;
        private _dc = 0;
        { if (alive _x && vehicle _x == _veh) then { unassignVehicle _x; moveOut _x; _x setUnitPos "AUTO"; _dc=_dc+1 }; sleep 0.3 } forEach units _cargoGrp;
        sleep 2; if (!isNull _cDrv && alive _cDrv) then { _cDrv enableAI "MOVE" };
        { if (alive _x && vehicle _x == _x) then { _x setBehaviour "COMBAT"; _x setCombatMode "RED" } } forEach units _cargoGrp;
        _veh setVariable ["DYN_isDismounting",false,true];
        diag_log format ["[GROUND-CONVOY] %1 dismounted %2", _vType, _dc];
        while {!isNull _objTruck && alive _objTruck} do {
            sleep 8;
            if (!isNull _veh && alive _veh) then { [_veh] call _fnEject };
            if (!isNull _veh && alive _veh && canMove _veh) then {
                private _drv = driver _veh;
                if (isNull _drv || !alive _drv) then {
                    private _r = objNull;
                    { if (alive _x && vehicle _x == _x) exitWith {_r=_x} } forEach units _cargoGrp;
                    if (isNull _r) then { { if (alive _x && vehicle _x != _veh) exitWith {_r=_x} } forEach units _crewGrp };
                    if (!isNull _r) then { _r moveInDriver _veh };
                };
                if ((isNull(gunner _veh) || !alive(gunner _veh)) && (_veh emptyPositions "gunner") > 0) then {
                    { if (alive _x && vehicle _x == _x) exitWith { _x moveInGunner _veh } } forEach units _cargoGrp;
                };
            };
            private _inCbt = false;
            if (!isNull _crewGrp && {count units _crewGrp > 0}) then { if (behaviour leader _crewGrp == "COMBAT") then {_inCbt=true} };
            if (!_inCbt && !isNull _cargoGrp && {count units _cargoGrp > 0}) then { if (behaviour leader _cargoGrp == "COMBAT") then {_inCbt=true} };
            if (!_inCbt) then { { if (alive _x && behaviour _x == "COMBAT") exitWith {_inCbt=true} } forEach (units _crewGrp + units _cargoGrp) };
            private _plrNear = false;
            if (!_inCbt) then { { if (alive _x && isPlayer _x && _x distance2D (if (!isNull _veh && alive _veh) then {getPos _veh} else {getPos leader _cargoGrp}) < 500) exitWith {_plrNear=true} } forEach allPlayers };
            if (!_inCbt && !_plrNear && _hasDismounted) then {
                private _strandedUnits = (units _cargoGrp) select { alive _x && vehicle _x == _x };
                if (!isNull _veh && alive _veh && canMove _veh) then {
                    { if ((_veh emptyPositions "cargo") > 0) then { _x moveInCargo _veh } } forEach _strandedUnits;
                    _cargoGrp setBehaviour "SAFE"; _crewGrp setBehaviour "SAFE"; _hasDismounted = false;
                    if (!isNull _objTruck && alive _objTruck) then { private _ai = [_veh, _route] call _fnAhead; [_crewGrp, _route, _ai, "SAFE", "RED", "LIMITED"] call _fnRefresh };
                    _crewGrp setSpeedMode "LIMITED"; diag_log format ["[GROUND-CONVOY] %1 remounting normally", _vType];
                } else {
                    if (!_gazPickupSpawned && count _strandedUnits > 0) then {
                        _gazPickupSpawned = true;
                        diag_log format ["[GROUND-CONVOY] %1 destroyed - spawning GAZ pickups for %2 stranded", _vType, count _strandedUnits];
                        private _troopPos = getPos (leader _cargoGrp); private _dirToTruck = _troopPos getDir (getPos _objTruck);
                        private _gazSpawnPos1 = [_troopPos, 150, _dirToTruck + 180 - 10] call DYN_fnc_posOffset;
                        private _gazSpawnPos2 = [_troopPos, 200, _dirToTruck + 180 + 10] call DYN_fnc_posOffset;
                        private _gaz1Data = [_gazSpawnPos1, _dirToTruck, _infPool] call _fnSpawnGaz; sleep 3;
                        private _gaz2Data = [_gazSpawnPos2, _dirToTruck, _infPool] call _fnSpawnGaz;
                        private _gaz1 = _gaz1Data select 0; private _gaz1Grp = _gaz1Data select 1;
                        private _gaz2 = _gaz2Data select 0; private _gaz2Grp = _gaz2Data select 1;
                        if (!isNull _gaz1 && alive _gaz1) then { _gaz1Grp setBehaviour "SAFE"; _gaz1Grp setCombatMode "RED";
                            private _wpPickup = _gaz1Grp addWaypoint [_troopPos, 20]; _wpPickup setWaypointType "MOVE"; _wpPickup setWaypointSpeed "FULL"; _wpPickup setWaypointBehaviour "SAFE"; _gaz1Grp setSpeedMode "FULL" };
                        if (!isNull _gaz2 && alive _gaz2) then { _gaz2Grp setBehaviour "SAFE"; _gaz2Grp setCombatMode "RED";
                            private _wpPickup = _gaz2Grp addWaypoint [_troopPos, 20]; _wpPickup setWaypointType "MOVE"; _wpPickup setWaypointSpeed "FULL"; _wpPickup setWaypointBehaviour "SAFE"; _gaz2Grp setSpeedMode "FULL" };
                        [_gaz1, _gaz1Grp, _gaz2, _gaz2Grp, _strandedUnits, _objTruck, _route, _angles, _fnAhead, _fnRefresh, _fnTurnSpd, _fnEject, _fnSpacing] spawn {
                            params ["_g1","_g1G","_g2","_g2G","_troops","_truck","_rt","_ang","_fnAhead","_fnRefresh","_fnTurnSpd","_fnEject","_fnSpacing"];
                            if (!isServer) exitWith {};
                            private _arriveTimer = 0;
                            waitUntil { sleep 3; _arriveTimer = _arriveTimer + 3;
                                if (isNull _truck || !alive _truck) exitWith {true}; if (_arriveTimer > 120) exitWith {true};
                                private _anyArrived = false; private _troopCenter = [0,0,0];
                                private _aliveT = _troops select { alive _x }; if (count _aliveT > 0) then { _troopCenter = getPos (_aliveT select 0) };
                                if (!isNull _g1 && alive _g1 && _g1 distance2D _troopCenter < 50) then {_anyArrived=true};
                                if (!isNull _g2 && alive _g2 && _g2 distance2D _troopCenter < 50) then {_anyArrived=true};
                                _anyArrived
                            };
                            if (isNull _truck || !alive _truck) exitWith {}; sleep 3;
                            private _aliveTroops = _troops select { alive _x && vehicle _x == _x }; private _loaded = 0;
                            { private _unit = _x; private _loaded_this = false;
                                if (!_loaded_this && !isNull _g1 && alive _g1 && (_g1 emptyPositions "cargo") > 0) then { _unit moveInCargo _g1; _loaded_this = true; _loaded = _loaded + 1 };
                                if (!_loaded_this && !isNull _g2 && alive _g2 && (_g2 emptyPositions "cargo") > 0) then { _unit moveInCargo _g2; _loaded_this = true; _loaded = _loaded + 1 };
                            } forEach _aliveTroops;
                            diag_log format ["[GROUND-CONVOY] GAZ loaded %1/%2 troops", _loaded, count _aliveTroops]; sleep 2;
                            { _x params ["_gaz","_gazGrp"];
                                if (isNull _gaz || !alive _gaz) then {continue}; if (count (crew _gaz) < 2) then {continue};
                                while {count waypoints _gazGrp > 0} do { deleteWaypoint [_gazGrp, 0] };
                                private _ai = [_gaz, _rt] call _fnAhead;
                                [_gazGrp, _rt, _ai, "SAFE", "RED", "FULL"] call _fnRefresh;
                                _gazGrp setBehaviour "SAFE"; _gazGrp setCombatMode "RED"; _gazGrp setSpeedMode "FULL";
                                diag_log format ["[GROUND-CONVOY] GAZ %1 chasing convoy", typeOf _gaz];
                                [_gaz, _gazGrp, _rt, _ang, _truck, _fnEject, _fnAhead, _fnRefresh, _fnTurnSpd, _fnSpacing] spawn {
                                    params ["_gv","_gg","_rr","_aa","_tk","_feject","_fahead","_frefresh","_fturn","_fSpacing"];
                                    if (!isServer) exitWith {};
                                    private _lp = getPos _gv; private _st = 0; private _rc = 0; sleep 10; _lp = getPos _gv;
                                    while {!isNull _gv && alive _gv && canMove _gv && !isNull _tk && alive _tk} do {
                                        sleep 3; [_gv] call _feject;
                                        private _d = driver _gv; if (isNull _d || !alive _d) then { _st=0; _lp=getPos _gv; continue };
                                        private _cp = getPos _gv;
                                        private _spacingLimitG = [_gv] call _fSpacing;
                                        if (_spacingLimitG > 0) then { _gv limitSpeed _spacingLimitG; _gg setSpeedMode "LIMITED"; _lp=_cp; _st=0; continue };
                                        private _dtk = _cp distance2D (getPos _tk);
                                        if (_dtk > 600) then { _gg setSpeedMode "FULL"; _gv limitSpeed 150 }
                                        else { if (_dtk > 300) then { _gg setSpeedMode "NORMAL"; _gv limitSpeed 80 }
                                            else { _gg setSpeedMode "LIMITED"; private _tl = [_gv, _rr, _aa] call _fturn; _gv limitSpeed _tl } };
                                        private _mv = _cp distance2D _lp;
                                        if (_mv < 3 && abs(speed _gv) < 3) then { _st=_st+3;
                                            if (_st >= 25) then { _gv setVelocityModelSpace [0,-3,0]; sleep 2; _gv setVelocityModelSpace [0,0,0]; sleep 0.5;
                                                private _ai = [_gv, _rr] call _fahead; _gv setDir ((getPos _gv) getDir (_rr select _ai));
                                                sleep 0.3; _gv setVelocityModelSpace [0,5,0]; sleep 2;
                                                [_gg, _rr, _ai, "SAFE", "RED", "FULL"] call _frefresh; _gg setSpeedMode "FULL"; _st=0; _rc=_rc+1 };
                                        } else { _st = 0 }; _lp = _cp;
                                    }; _gv limitSpeed 150;
                                };
                            } forEach [[_g1,_g1G],[_g2,_g2G]];
                        };
                        _hasDismounted = false; diag_log "[GROUND-CONVOY] GAZ pickup system activated";
                    };
                };
            };
        };
    };
} forEach _allCargoGroups;

// =====================================================
// ZSU CREW SWAP + DEAD SWEEP
// =====================================================
[_zsu, _zsuGrp, _objTruck, _fn_ejectDead, _escortVehicles] spawn {
    params ["_zsu","_zGrp","_truck","_fnEject","_escVehs"];
    if (!isServer) exitWith {};
    while {!isNull _truck && alive _truck} do {
        sleep 12;
        if (!isNull _zsu && alive _zsu) then { [_zsu] call _fnEject;
            private _zd = driver _zsu;
            if ((isNull _zd || !alive _zd) && canMove _zsu) then {
                private _zg = gunner _zsu;
                if (!isNull _zg && alive _zg) then { _zg moveInDriver _zsu }
                else { { if (alive _x && side group _x == east && vehicle _x == _x && !isPlayer _x && _x distance2D _zsu < 200) exitWith {
                    [_x] joinSilent _zGrp; _x moveInDriver _zsu } } forEach (_zsu nearEntities ["Man",200]) };
            };
        };
        { if (!isNull _x && alive _x) then { [_x] call _fnEject } } forEach _escVehs;
    };
};

// =====================================================
// DEAD BODY CLEANUP (2 minutes)
// =====================================================
[] spawn { if (!isServer) exitWith {};
    private _deadTracker = [];
    while {DYN_ground_active} do { sleep 30;
        private _enemies = +DYN_ground_enemies;
        { private _unit = _x; if (isNull _unit) then {continue};
            private _isDead = !alive _unit;
            if (!_isDead) then { if (_unit getVariable ["ACE_isUnconscious",false]) then {_isDead=true};
                if (_unit getVariable ["ace_medical_iDead",false]) then {_isDead=true};
                if (_unit getVariable ["ace_medical_status_isDead",false]) then {_isDead=true} };
            if (_isDead) then { private _tracked = false;
                { if ((_x select 0) isEqualTo _unit) exitWith {_tracked=true} } forEach _deadTracker;
                if (!_tracked) then { _deadTracker pushBack [_unit, diag_tickTime] } };
        } forEach _enemies;
        private _rem = [];
        { private _u = _x select 0; private _dt = _x select 1;
            if (isNull _u) then { _rem pushBack _forEachIndex; continue };
            if ((diag_tickTime - _dt) > 120) then {
                if (vehicle _u != _u) then { unassignVehicle _u; moveOut _u; _u setPosATL [0,0,0] };
                deleteVehicle _u; _rem pushBack _forEachIndex };
        } forEach _deadTracker;
        reverse _rem; { _deadTracker deleteAt _x } forEach _rem;
    };
};

// =====================================================
// TASK
// =====================================================
private _taskId = format ["ground_convoy_%1", round(diag_tickTime * 1000)];
private _taskTitle = if (_objectiveAction == "DESTROY") then {"Intercept and Destroy Convoy"} else {"Intercept and Capture Convoy"};
[west, _taskId, [_taskDescription, _taskTitle, ""], _startPos, "CREATED", 3, true, "truck"] remoteExec ["BIS_fnc_taskCreate", 0, true];
DYN_ground_tasks pushBack _taskId;

// =====================================================
// CHASE SQUAD (CAPTURE only)
// =====================================================
if (_objectiveAction == "CAPTURE") then {
    [_objTruck, _infPool, _routePoints, _turnAngles, _endRoadPos, _convoyGrp, _fn_ejectDead, _fn_findAheadIdx, _fn_refreshWPs, _fn_getTurnSpeed] spawn {
        params ["_truck","_pool","_route","_angles","_dest","_tGrp","_fnEject","_fnAhead","_fnRefresh","_fnTurnSpd"];
        if (!isServer) exitWith {};
        private _spawned = false; private _chaseUnits = []; private _chaseGrps = [];
        waitUntil { sleep 5; if (isNull _truck || !alive _truck) exitWith {true}; if (_spawned) exitWith {true};
            private _d = driver _truck; if (isNull _d) exitWith {false}; (isPlayer _d || {side group _d == west}) };
        if (isNull _truck || !alive _truck || _spawned) exitWith {}; _spawned = true;
        private _tPos = getPos _truck; private _bDir = (getDir _truck) + 180;
        private _chaseClasses = ["CUP_O_GAZ_Vodnik_PK_RU","CUP_O_GAZ_Vodnik_AGS_RU","CUP_O_GAZ_Vodnik_BPPU_RU"];
        private _chaseCount = 2 + floor random 2;
        for "_c" from 1 to _chaseCount do {
            private _csp = [_tPos, 400+(_c*150), _bDir] call DYN_fnc_posOffset;
            private _cr = _csp nearRoads 150; if (count _cr > 0) then { _csp = getPos(selectRandom _cr) };
            if (surfaceIsWater _csp) then { _csp = [_tPos, 300+(_c*100), _bDir+30] call DYN_fnc_posOffset };
            if (surfaceIsWater _csp) then { continue };
            private _cv = createVehicle [selectRandom _chaseClasses, [0,0,0], [], 0, "NONE"];
            _cv allowDamage false; _cv enableSimulation false; sleep 0.3;
            { deleteVehicle _x } forEach crew _cv;
            _cv setDir (_csp getDir _tPos); _cv setPosATL _csp;
            sleep 0.5; _cv enableSimulation true; sleep 1;
            _cv forceFollowRoad true;
            _cv setVariable ["DYN_convoyVehicle", true, true];
            _cv addEventHandler ["HandleDamage", {
                params ["_unit","_sel","_damage","_source","_projectile","_hitIndex"];
                if (_projectile isEqualTo "") then { private _blocked = false;
                    if (!isNull _source && {_source getVariable ["DYN_convoyVehicle",false]}) then { _blocked = true };
                    if (!_blocked) then { { if (_x != _unit && {_x getVariable ["DYN_convoyVehicle",false]} && {_x distance _unit < 15}) exitWith { _blocked = true } } forEach DYN_ground_enemyVehs };
                    if (_blocked) exitWith { if (_hitIndex >= 0) then {_unit getHitIndex _hitIndex} else {damage _unit} } };
                _damage
            }];
            [_cv] spawn { params ["_v"]; sleep 30; if (!isNull _v && alive _v) then { _v allowDamage true; diag_log format ["[GROUND-CONVOY] Chase godmode ended: %1", typeOf _v] } };
            private _ccG = createGroup east; DYN_ground_enemyGroups pushBack _ccG; _chaseGrps pushBack _ccG;
            private _cd = _ccG createUnit [selectRandom _pool, _csp, [], 0, "NONE"];
            _cd moveInDriver _cv; _cd allowFleeing 0; _cd setSkill 0.85; DYN_ground_enemies pushBack _cd; _chaseUnits pushBack _cd;
            if ((_cv emptyPositions "gunner") > 0) then {
                private _cg = _ccG createUnit [selectRandom _pool, _csp, [], 0, "NONE"];
                _cg moveInGunner _cv; _cg allowFleeing 0; _cg setSkill 0.90; _cg setSkill ["aimingAccuracy",0.85];
                DYN_ground_enemies pushBack _cg; _chaseUnits pushBack _cg };
            if ((_cv emptyPositions "commander") > 0) then {
                private _cc = _ccG createUnit [selectRandom _pool, _csp, [], 0, "NONE"];
                _cc moveInCommander _cv; _cc allowFleeing 0; _cc setSkill 0.85;
                DYN_ground_enemies pushBack _cc; _chaseUnits pushBack _cc };
            sleep 0.3;
            { DYN_ground_enemies deleteAt (DYN_ground_enemies find _x); deleteVehicle _x } forEach ((units _ccG) select {vehicle _x != _cv});
            private _ccCargo = createGroup east; DYN_ground_enemyGroups pushBack _ccCargo; _chaseGrps pushBack _ccCargo;
            private _cmc = _cv emptyPositions "cargo";
            for "_p" from 1 to _cmc do {
                private _cp = _ccCargo createUnit [selectRandom _pool, _csp, [], 0, "NONE"];
                _cp moveInCargo _cv; _cp allowFleeing 0; _cp setSkill 0.80;
                DYN_ground_enemies pushBack _cp; _chaseUnits pushBack _cp };
            DYN_ground_enemyVehs pushBack _cv;
            _ccG setBehaviour "AWARE"; _ccG setCombatMode "RED"; _ccG setSpeedMode "FULL";
            [_ccG, _truck, _cv] spawn { params ["_grp","_target","_veh"];
                if (!isServer) exitWith {}; private _lastP = getPos _veh; private _sT = 0;
                while {!isNull _target && alive _target && {count(units _grp select {alive _x}) > 0}} do {
                    private _tP = getPos _target; while {count waypoints _grp > 0} do {deleteWaypoint [_grp,0]};
                    private _wp = _grp addWaypoint [_tP, 30]; _wp setWaypointType "MOVE"; _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "AWARE"; _wp setWaypointCombatMode "RED"; sleep 10;
                    if (!isNull _veh && alive _veh && canMove _veh) then { private _cP = getPos _veh;
                        if (_cP distance2D _lastP < 3 && abs(speed _veh) < 3) then { _sT=_sT+10;
                            if (_sT >= 25) then { _veh setVelocityModelSpace [0,-3,0]; sleep 2; _veh setVelocityModelSpace [0,0,0]; sleep 0.5;
                                _veh setDir (_cP getDir _tP); sleep 0.3; _veh setVelocityModelSpace [0,5,0]; sleep 2; _sT = 0 };
                        } else { _sT = 0 }; _lastP = _cP };
                    sleep 5;
                };
            };
            sleep 3;
        };
        [_truck, _chaseUnits, _chaseGrps, _route, _dest, _tGrp, _pool, _fnEject, _fnAhead, _fnRefresh] spawn {
            params ["_truck","_units","_groups","_route","_dest","_tGrp","_pool","_fnEject","_fnAhead","_fnRefresh"];
            if (!isServer) exitWith {};
            waitUntil { sleep 3; if (isNull _truck || !alive _truck || !canMove _truck) exitWith {true};
                private _d = driver _truck; if (isNull _d || !alive _d) exitWith {true};
                if (!isPlayer _d && {side group _d != west}) exitWith {true}; false };
            if (isNull _truck || !alive _truck || !canMove _truck) exitWith {};
            sleep 6; [_truck] call _fnEject;
            private _cd = driver _truck;
            if (!isNull _cd && alive _cd && (isPlayer _cd || {side group _cd == west})) exitWith {};
            if (_truck getVariable ["DYN_driverSwapInProgress",false]) exitWith {};
            _truck setVariable ["DYN_driverSwapInProgress",true,true];
            private _rec = objNull;
            { if (alive _x && vehicle _x == _x && side group _x == east) exitWith {_rec=_x} } forEach _units;
            if (isNull _rec) then { { if (alive _x && side group _x == east) exitWith { if (vehicle _x != _x) then { unassignVehicle _x; moveOut _x }; _rec=_x } } forEach _units };
            if (isNull _rec) then { { if (alive _x && side group _x == east && !isPlayer _x) exitWith { if (vehicle _x != _x) then { unassignVehicle _x; moveOut _x }; _rec=_x } } forEach (_truck nearEntities ["Man",500]) };
            if (isNull _rec) exitWith { _truck setVariable ["DYN_driverSwapInProgress",false,true] };
            private _dw = 0; while {vehicle _rec != _rec && _dw < 12} do { sleep 1; _dw=_dw+1 };
            [_rec] joinSilent _tGrp; _rec doMove (getPos _truck); private _mt = 0;
            while {_rec distance2D _truck > 8 && _mt < 60 && alive _rec && alive _truck} do { _rec doMove(getPos _truck); sleep 2; _mt=_mt+2 };
            if (!alive _rec || !alive _truck || !canMove _truck) exitWith { _truck setVariable ["DYN_driverSwapInProgress",false,true] };
            [_truck] call _fnEject;
            private _chk = driver _truck;
            if (!isNull _chk && alive _chk && (isPlayer _chk || {side group _chk == west})) exitWith { _truck setVariable ["DYN_driverSwapInProgress",false,true] };
            _rec moveInDriver _truck; sleep 1;
            if (driver _truck == _rec) then { _rec allowFleeing 0;
                { _rec disableAI _x } forEach ["AUTOCOMBAT","SUPPRESSION","TARGET","AUTOTARGET"];
                _truck setVariable ["DYN_objDriver",_rec,true];
                private _ai = [_truck, _route] call _fnAhead;
                [_tGrp, _route, _ai, "CARELESS", "GREEN", "LIMITED"] call _fnRefresh;
                _tGrp setBehaviour "CARELESS"; _tGrp setCombatMode "GREEN"; _tGrp setSpeedMode "LIMITED" };
            _truck setVariable ["DYN_driverSwapInProgress",false,true];
        };
    };
};

// =====================================================
// COMPLETION MONITOR
// =====================================================
private _deliveryPos = getMarkerPos "blackbox_delivery";
if (_deliveryPos isEqualTo [0,0,0]) then { _deliveryPos = _basePos };

[_taskId, _timeout, _repReward, _objTruck, _objectiveAction, _endRoadPos, _deliveryPos, _startName, _endName] spawn {
    params ["_tid","_tOut","_rep","_objTruck","_action","_dest","_delPos","_from","_to"];
    if (!isServer) exitWith {}; private _startT = diag_tickTime; private _result = "PENDING";
    while {_result == "PENDING"} do { sleep 3;
        if ((diag_tickTime - _startT) > _tOut) exitWith {_result="TIMEOUT"};
        if (isNull _objTruck || !alive _objTruck) exitWith { _result = if (_action=="DESTROY") then {"SUCCESS"} else {"DESTROYED"} };
        if (_objTruck distance2D _dest < 300) then { private _d = driver _objTruck; private _blu = false;
            if (!isNull _d && (isPlayer _d || {side group _d == west})) then {_blu=true};
            if (!_blu) exitWith {_result="CONVOY_ARRIVED"} };
        if (_action == "DESTROY" && (!canMove _objTruck || damage _objTruck >= 0.9)) exitWith {_result="SUCCESS"};
        if (_action == "CAPTURE" && alive _objTruck && _objTruck distance2D _delPos < 50) then {
            private _d = driver _objTruck;
            if (!isNull _d && (isPlayer _d || {side group _d == west})) exitWith {_result="SUCCESS"};
            if (isNull _d || !alive _d) then { private _pn = false;
                { if (alive _x && isPlayer _x && _x distance2D _objTruck < 30) exitWith {_pn=true} } forEach allPlayers;
                if (_pn) exitWith {_result="SUCCESS"} };
        };
    };
    switch (_result) do {
        case "SUCCESS": { [_tid,"SUCCEEDED",false] remoteExec ["BIS_fnc_taskSetState", 0, true];
            [_rep,"Convoy Intercepted"] call DYN_fnc_changeReputation; diag_log format ["[GROUND-CONVOY] SUCCESS +%1rep (%2)",_rep,_action] };
        case "CONVOY_ARRIVED": { [_tid,"FAILED",false] remoteExec ["BIS_fnc_taskSetState", 0, true]; diag_log format ["[GROUND-CONVOY] FAILED - reached %1",_to] };
        case "DESTROYED": { [_tid,"FAILED",false] remoteExec ["BIS_fnc_taskSetState", 0, true]; diag_log "[GROUND-CONVOY] FAILED - truck destroyed (CAPTURE)" };
        case "TIMEOUT": { [_tid,"FAILED",false] remoteExec ["BIS_fnc_taskSetState", 0, true]; diag_log "[GROUND-CONVOY] TIMED OUT" };
    };
    sleep 5; [_tid] call BIS_fnc_deleteTask;
    private _aV = +DYN_ground_enemyVehs; private _aE = +DYN_ground_enemies; private _aG = +DYN_ground_enemyGroups;
    { if (!isNull _x) then { { if (!isNull _x) then { _x setPosATL [0,0,0]; deleteVehicle _x } } forEach crew _x; deleteVehicle _x } } forEach _aV;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _aE;
    { if (!isNull _x) then { deleteGroup _x } } forEach _aG;
    DYN_ground_active = false; diag_log "[GROUND-CONVOY] Cleanup complete";
};

diag_log "[GROUND-CONVOY] Convoy Intercept initialized";
