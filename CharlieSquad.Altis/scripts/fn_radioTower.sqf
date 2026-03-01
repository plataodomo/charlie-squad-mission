/*
    scripts\fn_radioTower.sqf
*/

params ["_pos", "_spawnRadius"];
if (!isServer) exitWith {};

// FIND FLAT POSITION (NOT NEAR ROADS)
private _txPos = _pos;
private _found = false;
private _minRoadDist = 120;

for "_t" from 1 to 120 do {
    private _cand = [_pos, 250, _spawnRadius, 10, 0, 0.3, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _cand) then { continue };
    if (isOnRoad _cand) then { continue };
    if ((count (_cand nearRoads _minRoadDist)) > 0) then { continue };

    private _flat = _cand isFlatEmpty [10, -1, 0.35, 25, 0, false, objNull];
    if !(_flat isEqualTo []) exitWith { _txPos = _cand; _found = true; };
};

if (!_found) then {
    _txPos = [_pos, 200, _spawnRadius, 10, 0, 0.3, 0] call BIS_fnc_findSafePos;
};

// FIX: Register radio tower position so AA pits and other objectives avoid it
if (isNil "DYN_radioTowerPositions") then { DYN_radioTowerPositions = []; };
DYN_radioTowerPositions pushBack _txPos;
if (isNil "DYN_AO_hiddenObjectives") then { DYN_AO_hiddenObjectives = []; };

// RADIO TOWER + TASK
private _radioTaskId = format ["task_radio_%1", round (diag_tickTime * 1000)];

private _radioTower = createVehicle ["Land_TTowerBig_2_F", _txPos, [], 0, "NONE"];
_radioTower setDamage 0;
_radioTower allowDamage true;

DYN_AO_objects pushBack _radioTower;

_radioTower setVariable ["radioTaskId", _radioTaskId, true];
_radioTower setVariable ["radioDone", false, true];

[
    west,
    _radioTaskId,
    [
        "Destroy the enemy radio tower to disrupt communications.",
        "Destroy Radio Tower",
        ""
    ],
    getPosATL _radioTower,
    "CREATED",
    1,
    true,
    "radio"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_AO_sideTasks pushBack _radioTaskId;
DYN_AO_hiddenObjectives pushBack [_radioTaskId, "Radio Tower", getPosATL _radioTower];

// TASK COMPLETION
_radioTower addEventHandler ["Killed", {
    params ["_tower"];

    if (_tower getVariable ["radioDone", false]) exitWith {};
    _tower setVariable ["radioDone", true, true];

    private _tid = _tower getVariable ["radioTaskId", ""];
    if (_tid != "") then { [_tid, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, true]; };

    ["TaskSucceeded", ["Radio Tower Destroyed", "Enemy communications disrupted."]]
        remoteExecCall ["BIS_fnc_showNotification", 0];
}];

// Fallback
_radioTower addEventHandler ["HandleDamage", {
    params ["_tower", "_selection", "_damage"];

    if ((_damage >= 1) && !(_tower getVariable ["radioDone", false])) then {
        _tower setVariable ["radioDone", true, true];

        private _tid = _tower getVariable ["radioTaskId", ""];
        if (_tid != "") then { [_tid, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, true]; };

        ["TaskSucceeded", ["Radio Tower Destroyed", "Enemy communications disrupted."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
    };

    _damage
}];

// RAZORWIRE RING + SIGNS + SAFE LANE
private _ringRadius = 28;
private _segments = 20;

private _entranceCount = 3 + floor (random 3);
private _skipSegs = [];
for "_e" from 1 to _entranceCount do { _skipSegs pushBackUnique (floor (random _segments)); };

for "_s" from 0 to (_segments - 1) do {
    if (_s in _skipSegs) then { continue };
    private _dir = _s * (360 / _segments);
    private _p = _txPos getPos [_ringRadius, _dir];

    private _wire = createVehicle ["Land_Razorwire_F", _p, [], 0, "NONE"];
    _wire setDir _dir;
    DYN_AO_objects pushBack _wire;
};

private _signCount = 1 + floor (random 2);
for "_i" from 1 to _signCount do {
    private _dir = random 360;
    private _signPos = _txPos getPos [_ringRadius + 1.5, _dir];
    if (surfaceIsWater _signPos) then { continue };

    private _sign = createVehicle ["Land_Sign_MinesDanger_English_F", _signPos, [], 0, "NONE"];
    _sign setDir (_dir + 180);
    DYN_AO_objects pushBack _sign;
};

// Safe lane
private _laneDir = (selectRandom _skipSegs) * (360 / _segments);
private _laneWidth = 45;
private _minLaneSide = 3;

private _fn_inLane = {
    params ["_p"];
    private _dirTo = _txPos getDir _p;
    private _delta = abs (((_dirTo - _laneDir + 540) mod 360) - 180);
    private _d = _p distance _txPos;
    private _side = abs (sin _delta) * _d;
    (_delta < (_laneWidth / 2)) && (_side < _minLaneSide)
};

// BLUFOR-ONLY MINES — OPFOR aware and avoids
private _insideCount = 55;
private _allMines = [];

for "_iMine" from 1 to _insideCount do {
    private _dir = random 360;
    private _dist = 8 + random (_ringRadius - 10);
    private _p = _txPos getPos [_dist, _dir];

    if (surfaceIsWater _p) then { continue };
    if ((_p distance _txPos) < 7) then { continue };
    if ([_p] call _fn_inLane) then { continue };

    private _mine = createMine ["APERSBoundingMine", _p, [], 0];
    _mine allowDamage false;

    east revealMine _mine;

    DYN_AO_mines pushBack _mine;
    _allMines pushBack _mine;
};

// Single manager thread checks ALL mines instead of 55 individual spawn loops
[_allMines] spawn {
    params ["_mines"];
    private _triggerRadius = 3.2;

    while {count _mines > 0} do {
        sleep 0.5;

        private _players = allPlayers select { alive _x && side (group _x) == west };
        if (_players isEqualTo []) then { continue };

        private _triggered = [];

        {
            private _mine = _x;
            if (isNull _mine) then {
                _triggered pushBack _forEachIndex;
                continue;
            };

            private _minePos = getPosATL _mine;
            private _trip = false;
            {
                if ((_x distance2D _minePos) < _triggerRadius) exitWith { _trip = true };
            } forEach _players;

            if (_trip) then {
                _mine allowDamage true;
                _mine setDamage 1;
                _triggered pushBack _forEachIndex;
            };
        } forEach _mines;

        // Remove triggered/null mines in reverse order
        reverse _triggered;
        { _mines deleteAt _x } forEach _triggered;
    };
};
