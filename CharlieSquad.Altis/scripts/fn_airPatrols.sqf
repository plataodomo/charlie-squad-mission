/*
    scripts\fn_airPatrols.sqf
    CUP RUSSIAN HELICOPTERS - Mi-8 + Mi-24
*/

params ["_aoCenter", "_aoRadius"];
if (!isServer) exitWith {};

// CUP Russian helicopters
private _transportClass = "CUP_O_Mi8AMT_RU";      // Replaces Orca
private _attackClass = "CUP_O_Mi24_V_Dynamic_RU"; // Replaces Kajman

private _transportAlt = 180;
private _attackAlt = 240;

private _transportCount = 1 + floor (random 4);
private _attackChance = 0.40;

diag_log format ["AIRPATROLS: spawning %1 Mi-8(s), Mi-24 chance=%2", _transportCount, _attackChance];

private _fn_dlActive = { !(missionNamespace getVariable ["DYN_dataLinkDisabled", true]) };

private _fn_clearWPs = {
    params ["_grp"];
    for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };
};

private _fn_randPosInAO = {
    params ["_center","_radius",["_min",80],["_maxMul",0.85],["_tries",40]];
    private _max = _radius * _maxMul;
    private _p = [];
    for "_i" from 1 to _tries do {
        private _cand = _center getPos [_min + random (_max - _min), random 360];
        if (!surfaceIsWater _cand) exitWith { _p = _cand; };
    };
    if (_p isEqualTo []) then { _p = _center getPos [_radius * 0.6, random 360]; };
    _p
};

private _fn_setupHeliWPs = {
    params ["_grp", "_center", "_radius", "_alt", "_dlActive", ["_phase", 0]];

    // Inlined: clear all waypoints (was _fn_clearWPs — breaks in spawn scope)
    for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

    // Inlined: random position finder (was _fn_randPosInAO — breaks in spawn scope)
    private _fn_rPos = {
        params ["_c","_r",["_min",80],["_maxMul",0.85],["_tries",40]];
        private _max = _r * _maxMul;
        private _p = [];
        for "_i" from 1 to _tries do {
            private _cand = _c getPos [_min + random (_max - _min), random 360];
            if (!surfaceIsWater _cand) exitWith { _p = _cand; };
        };
        if (_p isEqualTo []) then { _p = _c getPos [_r * 0.6, random 360]; };
        _p
    };

    private _firstPos3 = [];
    private _moveCount = if (_dlActive) then {4} else {3};
    private _loiterR   = if (_dlActive) then {200 + random 150} else {300 + random 250};

    for "_i" from 1 to _moveCount do {
        // Phase offset rotates the search bias so helis don't share waypoints
        private _biasDir = (_phase * 90 + _i * 70) mod 360;
        private _biasPos = _center getPos [_radius * 0.4, _biasDir];
        private _p2 = [_biasPos, _radius * 0.5, 80, 0.9, 50] call _fn_rPos;
        if (_p2 isEqualTo []) then { _p2 = [_center, _radius, 120, 0.85, 50] call _fn_rPos; };
        private _p3 = [_p2#0, _p2#1, _alt];
        if (_i == 1) then { _firstPos3 = _p3; };

        private _wp = _grp addWaypoint [_p3, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointSpeed "FULL";
        _wp setWaypointBehaviour "COMBAT";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointCompletionRadius 250;
    };

    private _lo2 = [_center, _radius, 80, 0.65, 50] call _fn_rPos;
    private _lo3 = [_lo2#0, _lo2#1, _alt];

    private _wpl = _grp addWaypoint [_lo3, 0];
    _wpl setWaypointType "LOITER";
    _wpl setWaypointLoiterType "CIRCLE_L";
    _wpl setWaypointLoiterRadius _loiterR;
    _wpl setWaypointSpeed "LIMITED";
    _wpl setWaypointBehaviour "AWARE";
    _wpl setWaypointCombatMode "RED";

    (_grp addWaypoint [_firstPos3, 0]) setWaypointType "CYCLE";
};

private _fn_spawnHeli = {
    params ["_class", "_alt", "_center", "_radius", "_fn_setupHeliWPs", "_fn_dlActive", ["_heliIdx", 0]];

    // Spread spawn positions around the AO and stagger altitude to prevent collisions
    private _spawnDir = (_heliIdx * 110 + random 40) mod 360;
    private _spawnDist = (_radius * 0.5) + random (_radius * 0.25);
    private _spawn2 = _center getPos [_spawnDist, _spawnDir];
    if (surfaceIsWater _spawn2) then {
        _spawn2 = [_center, _radius, 150, 0.70, 60] call _fn_randPosInAO;
    };
    private _myAlt = _alt + (_heliIdx * 30); // 30m altitude gap between each heli
    private _spawn3 = [_spawn2#0, _spawn2#1, _myAlt];

    private _heli = createVehicle [_class, _spawn3, [], 0, "FLY"];
    _heli setDir (random 360);
    _heli flyInHeight _alt;
    _heli setVehicleAmmo 1;
    _heli flyInHeight _myAlt;

    createVehicleCrew _heli;

    DYN_AO_enemyVehs pushBack _heli;
    { 
        DYN_AO_enemies pushBack _x; 
        _x allowFleeing 0;
        _x setSkill 0.50;
    } forEach crew _heli;

    private _grp = group (driver _heli);
    DYN_AO_enemyGroups pushBack _grp;

    _grp setBehaviour "COMBAT";
    _grp setCombatMode "RED";
    _grp setSpeedMode "FULL";

    [_grp, _center, _radius, _myAlt, (call _fn_dlActive), _heliIdx] call _fn_setupHeliWPs;

    // Engage loop
    [_heli, _center, _radius, _myAlt, _fn_dlActive] spawn {
        params ["_heli","_center","_radius","_myAlt","_fn_dlActive"];

        while { DYN_AO_active && {alive _heli} } do {
            private _dl = call _fn_dlActive;
            sleep (if (_dl) then {4} else {8});

            // Only check players (much smaller list than all vehicles)
            private _targets = allPlayers select {
                alive _x && (side (group _x) isEqualTo west) && ((_x distance2D _center) < _radius)
            };
            if (_targets isEqualTo []) then { continue; };

            // Find closest without BIS_fnc_sortBy
            private _tgt = objNull;
            private _minD = 1e9;
            { private _d = _x distance2D _heli; if (_d < _minD) then { _minD = _d; _tgt = _x; }; } forEach _targets;
            if (isNull _tgt) then { continue };

            private _gunner = gunner _heli;
            if (!isNull _gunner) then {
                _gunner reveal [_tgt, 4];
                _gunner doWatch _tgt;
                _gunner doTarget _tgt;
                _gunner doFire _tgt;
            };

            _heli flyInHeight _myAlt;
        };
    };

    // Leash + WP refresh
    [_heli, _grp, _center, _radius, _myAlt, _heliIdx, _fn_setupHeliWPs, _fn_dlActive] spawn {
        params ["_heli","_grp","_center","_radius","_myAlt","_heliIdx","_fn_setupHeliWPs","_fn_dlActive"];

        private _lastPos = getPosATL _heli;
        private _lastMoveT = diag_tickTime;

        while { DYN_AO_active && {alive _heli} && {!isNull _grp} } do {
            private _dl = call _fn_dlActive;
            sleep (if (_dl) then {8} else {12});

            private _p = getPosATL _heli;
            if ((_p distance2D _lastPos) > 60) then {
                _lastMoveT = diag_tickTime;
                _lastPos = _p;
            };

            if ((_heli distance2D _center) > (_radius * 1.05)) then {
                (driver _heli) doMove (_center getPos [_radius * 0.6, random 360]);
                _heli flyInHeight _myAlt;
                _lastMoveT = diag_tickTime;
                continue;
            };

            private _refreshT = if (_dl) then {120} else {180};

            if ((speed _heli) < 8 && {(diag_tickTime - _lastMoveT) > 90}) then {
                [_grp, _center, _radius, _myAlt, _dl, _heliIdx] call _fn_setupHeliWPs;
                _lastMoveT = diag_tickTime;
                continue;
            };

            if ((diag_tickTime - _lastMoveT) > _refreshT) then {
                [_grp, _center, _radius, _myAlt, _dl, _heliIdx] call _fn_setupHeliWPs;
                _lastMoveT = diag_tickTime;
            };
        };
    };

    _heli
};

// Spawn Mi-8 transport helicopters — stagger each one with a 5s delay and unique index
for "_i" from 1 to _transportCount do {
    [_transportClass, _transportAlt, _aoCenter, _aoRadius, _fn_setupHeliWPs, _fn_dlActive, _i - 1] call _fn_spawnHeli;
    if (_i < _transportCount) then { sleep 5; };
};
diag_log format ["AIRPATROLS: spawned %1 Mi-8(s)", _transportCount];

// Spawn Mi-24 attack helicopter — separate altitude tier from transports
if ((random 1) < _attackChance) then {
    [_attackClass, _attackAlt, _aoCenter, _aoRadius, _fn_setupHeliWPs, _fn_dlActive, _transportCount] call _fn_spawnHeli;
    diag_log "AIRPATROLS: spawned Mi-24 (40% chance hit)";
} else {
    diag_log "AIRPATROLS: Mi-24 not spawned (40% chance miss)";
};
