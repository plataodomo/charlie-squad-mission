/*
    scripts\fn_resistanceAreas.sqf
    Spawns 1-3 small enemy resistance areas near the main AO.
    Each area has a handful of enemies guarding an intel laptop.
    When a player downloads the intel, one hidden AO side objective
    (HQ / fuel depot / radio tower) is revealed on the map.
    Server only.
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

private _infantryPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

// =====================================================
// PROGRESS BAR — shared definition (isNil guard)
// =====================================================
if (isNil "DYN_fnc_showProgressBar") then {
    DYN_fnc_showProgressBar = {
        params ["_duration", "_title", "_onComplete", "_onCancel", "_condCheck"];
        disableSerialization;
        private _display = findDisplay 46;
        if (isNull _display) exitWith { false };
        [_duration, _title, _onComplete, _onCancel, _condCheck] spawn {
            params ["_duration", "_title", "_onComplete", "_onCancel", "_condCheck"];
            disableSerialization;
            private _startTime = diag_tickTime;
            private _bgCtrl = findDisplay 46 ctrlCreate ["RscText", -1];
            _bgCtrl ctrlSetPosition [0.3, 0.02, 0.4, 0.045];
            _bgCtrl ctrlSetBackgroundColor [0.05, 0.05, 0.05, 0.85];
            _bgCtrl ctrlCommit 0;
            private _fillCtrl = findDisplay 46 ctrlCreate ["RscText", -1];
            _fillCtrl ctrlSetPosition [0.301, 0.022, 0, 0.041];
            _fillCtrl ctrlSetBackgroundColor [0.0, 0.55, 0.85, 0.9];
            _fillCtrl ctrlCommit 0;
            private _titleCtrl = findDisplay 46 ctrlCreate ["RscStructuredText", -1];
            _titleCtrl ctrlSetPosition [0.3, -0.02, 0.4, 0.04];
            _titleCtrl ctrlSetStructuredText parseText format ["<t align='center' size='0.9' color='#00BFFF' shadow='1'>%1</t>", _title];
            _titleCtrl ctrlCommit 0;
            private _pctCtrl = findDisplay 46 ctrlCreate ["RscStructuredText", -1];
            _pctCtrl ctrlSetPosition [0.3, 0.065, 0.4, 0.03];
            _pctCtrl ctrlSetStructuredText parseText "<t align='center' size='0.85' color='#CCCCCC' shadow='1'>0%</t>";
            _pctCtrl ctrlCommit 0;
            while {(diag_tickTime - _startTime) < _duration} do {
                if !(call _condCheck) exitWith {};
                private _progress = ((diag_tickTime - _startTime) / _duration) min 1;
                private _pct = round (_progress * 100);
                _fillCtrl ctrlSetPosition [0.301, 0.022, 0.398 * _progress, 0.041];
                _fillCtrl ctrlCommit 0;
                _pctCtrl ctrlSetStructuredText parseText format ["<t align='center' size='0.85' color='#CCCCCC' shadow='1'>%1%%</t>", _pct];
                _pctCtrl ctrlCommit 0;
                private _r = 0.0;
                private _g = 0.55 + (_progress * 0.45);
                private _b = 0.85 - (_progress * 0.45);
                _fillCtrl ctrlSetBackgroundColor [_r, _g, _b, 0.9];
                sleep 0.15;
            };
            if (call _condCheck && {(diag_tickTime - _startTime) >= _duration}) then {
                _fillCtrl ctrlSetPosition [0.301, 0.022, 0.398, 0.041];
                _fillCtrl ctrlSetBackgroundColor [0.0, 1.0, 0.3, 1.0];
                _fillCtrl ctrlCommit 0;
                _pctCtrl ctrlSetStructuredText parseText "<t align='center' size='0.85' color='#00FF00' shadow='1'>COMPLETE</t>";
                _pctCtrl ctrlCommit 0;
                _titleCtrl ctrlSetStructuredText parseText format ["<t align='center' size='0.9' color='#00FF00' shadow='1'>%1 - DONE</t>", _title];
                _titleCtrl ctrlCommit 0;
                sleep 0.8;
                call _onComplete;
            } else {
                call _onCancel;
            };
            ctrlDelete _bgCtrl;
            ctrlDelete _fillCtrl;
            ctrlDelete _titleCtrl;
            ctrlDelete _pctCtrl;
        };
        true
    };
    publicVariable "DYN_fnc_showProgressBar";
};

// =====================================================
// SERVER: REVEAL ONE HIDDEN AO OBJECTIVE
// =====================================================
if (isNil "DYN_fnc_revealAOObjective") then {
    DYN_fnc_revealAOObjective = {
        if (!isServer) exitWith { false };
        private _hidden = missionNamespace getVariable ["DYN_AO_hiddenObjectives", []];
        if (_hidden isEqualTo []) exitWith { false };

        private _idx = floor (random (count _hidden));
        (_hidden select _idx) params ["_taskId", "_title", "_pos"];
        _hidden deleteAt _idx;
        missionNamespace setVariable ["DYN_AO_hiddenObjectives", _hidden, false];

        [_taskId, "ASSIGNED"] remoteExec ["BIS_fnc_taskSetState", 0, true];

        ["TaskUpdated", [format ["Intel analysed: %1 located!", _title], "New objective revealed on your map."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];

        diag_log format ["[RESISTANCE] Revealed AO objective: %1 at %2", _title, _pos];
        true
    };
    publicVariable "DYN_fnc_revealAOObjective";
};

// =====================================================
// SERVER: RESISTANCE LAPTOP USED
// =====================================================
if (isNil "DYN_fnc_serverResIntelUsed") then {
    DYN_fnc_serverResIntelUsed = {
        params ["_laptop"];
        if (!isServer) exitWith {};
        if (isNull _laptop) exitWith {};
        if (_laptop getVariable ["DYN_resIntelUsed", false]) exitWith {};

        private _caller = objNull;
        { if (owner _x == remoteExecutedOwner) exitWith { _caller = _x; }; } forEach allPlayers;
        if (isNull _caller) exitWith {};
        if (!alive _caller) exitWith {};
        if (side (group _caller) != west) exitWith {};
        if ((_caller distance _laptop) > 3) exitWith {};

        _laptop setVariable ["DYN_resIntelUsed", true, true];

        private _taskId = _laptop getVariable ["DYN_res_taskId", ""];
        if (_taskId != "") then {
            [_taskId, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, true];
        };

        private _revealed = call DYN_fnc_revealAOObjective;
        if (!_revealed) then {
            ["RepStatus", ["Intel collected. All AO objectives already revealed."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
        };

        if (!isNil "DYN_fnc_changeReputation") then {
            private _repGain = 5 + floor (random 6);
            [_repGain, "Enemy Intel Secured"] call DYN_fnc_changeReputation;
        };
    };
    publicVariable "DYN_fnc_serverResIntelUsed";
};

// =====================================================
// CLIENT: ACE INTERACTION FOR RESISTANCE LAPTOP
// =====================================================
if (isNil "DYN_fnc_addResIntelAction") then {
    DYN_fnc_addResIntelAction = {
        params ["_lap"];
        if (isNull _lap) exitWith {};

        if (isNil "ace_interact_menu_fnc_createAction") exitWith {
            diag_log "[RES_INTEL] ACE interact menu not loaded!";
        };

        private _action = [
            "DYN_ResIntelDownload",
            "Secure Enemy Intel",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
            {
                params ["_target", "_caller", "_params"];

                if (_target getVariable ["DYN_resIntelDownloading", false]) exitWith {
                    hint "Someone is already downloading from this laptop.";
                };

                _target setVariable ["DYN_resIntelDownloading", true, true];

                missionNamespace setVariable ["DYN_progressTarget", _target];
                missionNamespace setVariable ["DYN_progressCaller", _caller];
                missionNamespace setVariable ["DYN_progressActive", true];

                _caller action ["SwitchWeapon", _caller, _caller, 99];

                [_caller] spawn {
                    params ["_unit"];
                    sleep 0.5;
                    while {missionNamespace getVariable ["DYN_progressActive", false]} do {
                        if (!alive _unit) exitWith {};
                        _unit playMoveNow "AinvPknlMstpSnonWnonDnon_medicUp";
                        sleep 8;
                    };
                };

                [
                    10,
                    "SECURING INTEL",
                    {
                        missionNamespace setVariable ["DYN_progressActive", false];
                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];
                        if (!isNull _c) then { _c playMoveNow ""; _c switchMove ""; };
                        if (!isNull _t) then { [_t] remoteExecCall ["DYN_fnc_serverResIntelUsed", 2]; };
                    },
                    {
                        missionNamespace setVariable ["DYN_progressActive", false];
                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];
                        if (!isNull _c) then { _c playMoveNow ""; _c switchMove ""; };
                        if (!isNull _t) then { _t setVariable ["DYN_resIntelDownloading", false, true]; };
                        hint "Download cancelled.";
                        [] spawn { sleep 2; hintSilent ""; };
                    },
                    {
                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];
                        !isNull _t && {!isNull _c} && {alive _c} && {(_c distance _t) < 3}
                    }
                ] call DYN_fnc_showProgressBar;
            },
            {
                params ["_target", "_caller", "_params"];
                alive _caller
                && {(_caller distance _target) < 2.5}
                && {!isNull _target}
                && {!(_target getVariable ["DYN_resIntelUsed", false])}
                && {!(_target getVariable ["DYN_resIntelDownloading", false])}
            }
        ] call ace_interact_menu_fnc_createAction;

        [_lap, 0, ["ACE_MainActions"], _action] call ace_interact_menu_fnc_addActionToObject;
    };
    publicVariable "DYN_fnc_addResIntelAction";
};

// =====================================================
// FIND RESISTANCE LOCATIONS
// Towns/villages outside the AO but close enough to matter
// =====================================================
private _types = ["NameCity", "NameCityCapital", "NameVillage"];
private _allLocations = nearestLocations [_aoPos, _types, 6000];

private _candidates = _allLocations select {
    private _lPos = locationPosition _x;
    private _dist = _lPos distance2D _aoPos;
    _dist > (_aoRadius + 150)
    && {_dist < (_aoRadius + 2500)}
    && {!surfaceIsWater _lPos}
};

// Widen search if nothing found nearby
if (_candidates isEqualTo []) then {
    _candidates = _allLocations select {
        private _lPos = locationPosition _x;
        private _dist = _lPos distance2D _aoPos;
        _dist > (_aoRadius + 100) && {_dist < 6500} && {!surfaceIsWater _lPos}
    };
};

if (_candidates isEqualTo []) exitWith {
    diag_log "[RESISTANCE] No valid resistance area locations found near AO";
};

_candidates = _candidates call BIS_fnc_arrayShuffle;
private _areaCount = (1 + floor (random 3)) min (count _candidates);
private _selectedAreas = _candidates select [0, _areaCount];

diag_log format ["[RESISTANCE] Spawning %1 resistance area(s) around AO", _areaCount];

// =====================================================
// SPAWN EACH RESISTANCE AREA
// =====================================================
{
    private _loc     = _x;
    private _lPos    = locationPosition _loc;
    private _lName   = text _loc;
    private _areaIdx = _forEachIndex;

    // --- Marker ---
    private _mName = format ["RES_marker_%1_%2", _areaIdx, round (diag_tickTime * 1000)];
    createMarker [_mName, _lPos];
    _mName setMarkerShape "ELLIPSE";
    _mName setMarkerSize [200, 200];
    _mName setMarkerColor "ColorYellow";
    _mName setMarkerBrush "SolidBorder";
    _mName setMarkerAlpha 0.6;
    _mName setMarkerText format ["Resistance - %1", _lName];

    // --- Task ---
    private _resTaskId = format ["task_res_%1_%2", _areaIdx, round (diag_tickTime * 1000)];
    [
        west,
        _resTaskId,
        [
            format ["Enemy forces have established a resistance presence in %1. Eliminate the resistance and secure enemy intel to reveal AO objectives.", _lName],
            format ["Resistance - %1", _lName],
            ""
        ],
        _lPos,
        "ASSIGNED",
        1,
        true,
        "investigate"
    ] remoteExec ["BIS_fnc_taskCreate", 0, true];

    // --- Enemies (4-8) ---
    private _enemyCount = 4 + floor (random 5);
    private _resGrp = createGroup east;
    if (!isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups pushBack _resGrp; };
    _resGrp setBehaviour "AWARE";
    _resGrp setCombatMode "RED";

    private _nearBuildings = nearestObjects [_lPos, ["House", "Building"], 160];
    _nearBuildings = _nearBuildings select { !isNull _x };
    _nearBuildings = _nearBuildings call BIS_fnc_arrayShuffle;

    private _spawnedCount = 0;

    if (!(_nearBuildings isEqualTo [])) then {
        // Garrison buildings first
        private _useHouses = (_enemyCount min (count _nearBuildings)) max 1;
        for "_h" from 0 to (_useHouses - 1) do {
            private _bld = _nearBuildings select _h;
            private _positions = [_bld] call BIS_fnc_buildingPositions;
            if (_positions isEqualTo []) then { continue };

            private _u = _resGrp createUnit [selectRandom _infantryPool, selectRandom _positions, [], 0, "NONE"];
            if (!isNull _u) then {
                _u disableAI "PATH";
                _u setUnitPos (selectRandom ["UP","MIDDLE"]);
                _u allowFleeing 0;
                if (!isNil "DYN_fnc_boostOpforAwareness") then { [_u] call DYN_fnc_boostOpforAwareness; };
                if (!isNil "DYN_AO_enemies") then { DYN_AO_enemies pushBack _u; };
                _spawnedCount = _spawnedCount + 1;
            };
        };
    };

    // Fill remaining count with outside patrol units
    for "_i" from _spawnedCount to (_enemyCount - 1) do {
        private _p = [_lPos, 10, 180, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _p || {_p isEqualTo [0,0,0]}) then { _p = _lPos getPos [30 + random 80, random 360]; };

        private _u = _resGrp createUnit [selectRandom _infantryPool, _p, [], 0, "FORM"];
        if (!isNull _u) then {
            _u allowFleeing 0;
            if (!isNil "DYN_fnc_boostOpforAwareness") then { [_u] call DYN_fnc_boostOpforAwareness; };
            if (!isNil "DYN_AO_enemies") then { DYN_AO_enemies pushBack _u; };
        };
    };

    // Patrol waypoints around the area
    for "_w" from 1 to 4 do {
        private _wpPos = [_lPos, 20, 200, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _wpPos || {_wpPos isEqualTo [0,0,0]}) then { _wpPos = _lPos getPos [60 + random 100, _w * 90]; };
        private _wp = _resGrp addWaypoint [_wpPos, 10];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "AWARE";
    };
    (_resGrp addWaypoint [_lPos, 0]) setWaypointType "CYCLE";

    // --- Intel laptop ---
    private _lapPos = [];

    if (!(_nearBuildings isEqualTo [])) then {
        // Prefer placing laptop inside a building
        private _bld = selectRandom _nearBuildings;
        private _bldPositions = [_bld] call BIS_fnc_buildingPositions;
        if (!(_bldPositions isEqualTo [])) then {
            _lapPos = selectRandom _bldPositions;
        };
    };

    if (_lapPos isEqualTo []) then {
        _lapPos = [_lPos, 10, 120, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _lapPos || {_lapPos isEqualTo [0,0,0]}) then { _lapPos = _lPos getPos [30, random 360]; };
    };

    private _lap = createVehicle ["Land_Laptop_unfolded_F", _lapPos, [], 0, "NONE"];
    _lap setDir (random 360);
    private _pp = getPosATL _lap;
    _pp set [2, (_pp select 2) + 0.02];
    _lap setPosATL _pp;

    _lap setVariable ["DYN_res_taskId",        _resTaskId, false];
    _lap setVariable ["DYN_resIntelUsed",       false,      false];
    _lap setVariable ["DYN_resIntelDownloading",false,      false];

    if (!isNil "DYN_AO_objects") then { DYN_AO_objects pushBack _lap; };

    [_lap] remoteExec ["DYN_fnc_addResIntelAction", 0, true];

    // --- Cleanup marker when task finishes or AO ends ---
    [_mName, _resTaskId] spawn {
        params ["_marker", "_taskId"];
        waitUntil {
            sleep 5;
            private _state = [_taskId, west] call BIS_fnc_taskState;
            _state == "SUCCEEDED" || {_state == "CANCELED"} || {!DYN_AO_active}
        };
        sleep 3;
        deleteMarker _marker;
        if (!([_taskId, west] call BIS_fnc_taskCompleted)) then {
            [_taskId, "CANCELED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        };
    };

    diag_log format ["[RESISTANCE] Area spawned: %1 at %2, task %3", _lName, _lPos, _resTaskId];

} forEach _selectedAreas;
