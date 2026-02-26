/*
    scripts\fn_prisonSystem.sqf
    Server-only prison delivery system.
*/

if (!isServer) exitWith {};

private _dropPos = getMarkerPos "prison_dropoff";
if (_dropPos isEqualTo [0,0,0]) exitWith {
    diag_log "PRISON: marker 'prison_dropoff' not found (pos [0,0,0])";
};

private _radius = 8;
private _cellSearch = 60;

diag_log format ["PRISON: system running. DropPos=%1 radius=%2", _dropPos, _radius];

private _fn_cellOccupied = {
    params ["_cellPos"];
    private _nearUnits = _cellPos nearEntities ["Man", 2];
    ({ _x getVariable ["DYN_prisonDelivered", false] } count _nearUnits) > 0
};

while { true } do {
    sleep 3;

    private _cells = nearestObjects [_dropPos, ["Land_HelipadEmpty_F"], _cellSearch];
    if (_cells isEqualTo []) then { continue };

    private _nearUnits = _dropPos nearEntities ["Man", _radius + 15];

    private _prisoners = _nearUnits select {
        (_x getVariable ["DYN_isPrisoner", false])
        && !(_x getVariable ["DYN_prisonDelivered", false])
        && ((_x distance2D _dropPos) < _radius)
    };

    {
        private _u = _x;

        _u setVariable ["DYN_prisonDelivered", true, true];
        _u setVariable ["DYN_repProcessed", true, true];

        if (!isNull objectParent _u) then {
            moveOut _u;
            unassignVehicle _u;
        };

        private _cellIndex = _cells findIf { !([getPosATL _x] call _fn_cellOccupied) };
        private _cell = if (_cellIndex < 0) then { _cells select 0 } else { _cells select _cellIndex };

        _u setPosATL (getPosATL _cell);
        _u setDir (getDir _cell);

        _u setCaptive true;
        _u disableAI "MOVE";
        _u disableAI "PATH";
        _u disableAI "FSM";
        _u disableAI "AUTOCOMBAT";
        _u disableAI "TARGET";
        _u setUnitPos "UP";

        _u setVariable ["DYN_keepInPrison", true, true];

        private _type = _u getVariable ["DYN_prisonerType", "Prisoner"];
        private _tid  = _u getVariable ["DYN_prisonTaskId", ""];

        ["TaskSucceeded", [format ["%1 Delivered", _type], "Prisoner secured in holding cells."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];

        [_u] call DYN_fnc_awardPrisonerRep;

        if (_tid != "") then {
            [_tid, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        };

    } forEach _prisoners;
};
