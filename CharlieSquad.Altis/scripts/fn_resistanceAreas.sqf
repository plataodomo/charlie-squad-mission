/*
    scripts\fn_resistanceAreas.sqf
    Spawns 1-3 small enemy resistance areas near the main AO.
    Each area has a handful of enemies guarding an intel laptop.
    Area completes when ALL enemies are eliminated (100% kill required).
    The intel laptop awards reputation points when secured via ACE interact.
    Server only.
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

private _infantryPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RUS_M_Soldier_HAT_Ratnik_Autumn",
    "CUP_O_RUS_M_Soldier_AA_Ratnik_Autumn"
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
// SERVER: RESISTANCE LAPTOP USED — awards rep only
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

        if (!isNil "DYN_fnc_changeReputation") then {
            private _repGain = 3 + floor (random 4);
            [_repGain, "Enemy Intel Secured"] call DYN_fnc_changeReputation;
        };

        deleteVehicle _laptop;
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

                uiNamespace setVariable ["DYN_progressTarget", _target];
                uiNamespace setVariable ["DYN_progressCaller", _caller];
                uiNamespace setVariable ["DYN_progressActive", true];

                _caller action ["SwitchWeapon", _caller, _caller, 99];

                [_caller] spawn {
                    params ["_unit"];
                    sleep 0.5;
                    while {uiNamespace getVariable ["DYN_progressActive", false]} do {
                        if (!alive _unit) exitWith {};
                        _unit playMoveNow "AinvPknlMstpSnonWnonDnon_medicUp";
                        sleep 8;
                    };
                };

                [
                    10,
                    "SECURING INTEL",
                    {
                        uiNamespace setVariable ["DYN_progressActive", false];
                        private _t = uiNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = uiNamespace getVariable ["DYN_progressCaller", objNull];
                        if (!isNull _c) then { _c playMoveNow ""; _c switchMove ""; };
                        if (!isNull _t) then { [_t] remoteExecCall ["DYN_fnc_serverResIntelUsed", 2]; };
                    },
                    {
                        uiNamespace setVariable ["DYN_progressActive", false];
                        private _t = uiNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = uiNamespace getVariable ["DYN_progressCaller", objNull];
                        if (!isNull _c) then { _c playMoveNow ""; _c switchMove ""; };
                        if (!isNull _t) then { _t setVariable ["DYN_resIntelDownloading", false, true]; };
                        hint "Download cancelled.";
                        [] spawn { sleep 2; hintSilent ""; };
                    },
                    {
                        private _t = uiNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = uiNamespace getVariable ["DYN_progressCaller", objNull];
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

// Broadcast selected positions so ground missions can avoid spawning on top of them
if (isNil "DYN_resistanceAreaPositions") then { DYN_resistanceAreaPositions = []; };
{ DYN_resistanceAreaPositions pushBackUnique (locationPosition _x); } forEach _selectedAreas;
publicVariable "DYN_resistanceAreaPositions";

diag_log format ["[RESISTANCE] Spawning %1 resistance area(s) around AO", _areaCount];

// =====================================================
// SPAWN EACH RESISTANCE AREA
// =====================================================
{
    private _loc         = _x;
    private _lPos        = locationPosition _loc;
    private _lName       = text _loc;
    private _areaIdx     = _forEachIndex;
    private _areaEnemies = [];
    private _areaGroups  = [];

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
            format ["Enemy forces have established a resistance presence in %1. Eliminate the resistance.", _lName],
            format ["Resistance - %1", _lName],
            ""
        ],
        _lPos,
        "ASSIGNED",
        1,
        true,
        "investigate"
    ] remoteExec ["BIS_fnc_taskCreate", 0, _resTaskId];

    private _nearBuildings = nearestObjects [_lPos, ["House", "Building"], 200];
    _nearBuildings = _nearBuildings select { !isNull _x };
    _nearBuildings = _nearBuildings call BIS_fnc_arrayShuffle;

    // --- Squad 1: Patrol around the area perimeter ---
    private _patrolGrp = createGroup east;
    _patrolGrp setBehaviour "AWARE";
    _patrolGrp setCombatMode "RED";
    _areaGroups pushBack _patrolGrp;

    private _patrolCount = 5 + floor (random 4);  // 5-8 units
    for "_i" from 0 to (_patrolCount - 1) do {
        private _p = [_lPos, 20, 180, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _p || {_p isEqualTo [0,0,0]}) then { _p = _lPos getPos [30 + random 80, random 360]; };
        private _u = _patrolGrp createUnit [selectRandom _infantryPool, _p, [], 0, "FORM"];
        if (!isNull _u) then {
            _u allowFleeing 0;
            if (!isNil "DYN_fnc_boostOpforAwareness") then { [_u] call DYN_fnc_boostOpforAwareness; };
            _areaEnemies pushBack _u;
        };
    };

    for "_w" from 1 to 5 do {
        private _wpPos = [_lPos, 30, 200, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _wpPos || {_wpPos isEqualTo [0,0,0]}) then { _wpPos = _lPos getPos [60 + random 120, _w * 72]; };
        private _wp = _patrolGrp addWaypoint [_wpPos, 20];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
    };
    (_patrolGrp addWaypoint [_lPos, 0]) setWaypointType "CYCLE";

    // --- Squad 2: CQB garrison — one group per occupied building ---
    // Mirror the main AO pattern: disableAI PATH while holding, re-enable on COMBAT.
    private _garrisonBuildings = _nearBuildings select {
        count ([_x] call BIS_fnc_buildingPositions) > 0
    };
    private _maxBuildings = 12 min (count _garrisonBuildings);
    _garrisonBuildings = _garrisonBuildings select [0, _maxBuildings];

    if (_garrisonBuildings isEqualTo []) then {
        // No usable buildings — fall back to a small static patrol
        private _fbGrp = createGroup east;
        _fbGrp setBehaviour "AWARE";
        _fbGrp setCombatMode "RED";
        _areaGroups pushBack _fbGrp;
        for "_i" from 0 to 3 do {
            private _p = _lPos getPos [20 + random 60, random 360];
            private _u = _fbGrp createUnit [selectRandom _infantryPool, _p, [], 0, "FORM"];
            if (!isNull _u) then {
                _u allowFleeing 0;
                if (!isNil "DYN_fnc_boostOpforAwareness") then { [_u] call DYN_fnc_boostOpforAwareness; };
                _areaEnemies pushBack _u;
            };
        };
        for "_w" from 1 to 4 do {
            (_fbGrp addWaypoint [_lPos getPos [40 + random 80, _w * 90], 15]) setWaypointType "MOVE";
        };
        (_fbGrp addWaypoint [_lPos, 0]) setWaypointType "CYCLE";
    } else {
        {
            private _bld      = _x;
            private _positions = [_bld] call BIS_fnc_buildingPositions;
            if (_positions isEqualTo []) then { continue };
            _positions = _positions call BIS_fnc_arrayShuffle;

            private _bGrp = createGroup east;
            _bGrp setBehaviour "AWARE";
            _bGrp setCombatMode "RED";
            _areaGroups pushBack _bGrp;

            // 2-3 soldiers per building
            private _count = (2 + floor (random 2)) min (count _positions);
            for "_u" from 0 to (_count - 1) do {
                private _bPos = _positions select _u;
                private _unit = _bGrp createUnit [selectRandom _infantryPool, _bPos, [], 0, "NONE"];
                if (isNull _unit) then { continue };
                _unit setPosATL _bPos;
                _unit disableAI "PATH";
                _unit setUnitPos (selectRandom ["UP", "MIDDLE"]);
                _unit allowFleeing 0;
                if (!isNil "DYN_fnc_boostOpforAwareness") then { [_unit] call DYN_fnc_boostOpforAwareness; };
                _areaEnemies pushBack _unit;
            };

            // Re-enable PATH on COMBAT so units can exit and engage rather than staying frozen.
            // Also release after 4 minutes so they don't stay hidden forever if combat never reaches them.
            [_bGrp] spawn {
                params ["_g"];
                private _holdStart = diag_tickTime;
                waitUntil { sleep 2; isNull _g || { !(alive leader _g) } || { behaviour leader _g == "COMBAT" } || { (diag_tickTime - _holdStart) > 240 } };
                if (!isNull _g && { alive leader _g }) then {
                    { if (alive _x) then { _x enableAI "PATH"; }; } forEach units _g;
                };
            };
        } forEach _garrisonBuildings;
    };

    // --- Squad 3: Second patrol covering a wider perimeter ---
    private _patrol2Grp = createGroup east;
    _patrol2Grp setBehaviour "AWARE";
    _patrol2Grp setCombatMode "RED";
    _areaGroups pushBack _patrol2Grp;

    private _patrol2Count = 4 + floor (random 4);  // 4-7 units
    for "_i" from 0 to (_patrol2Count - 1) do {
        private _p = [_lPos, 40, 220, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _p || {_p isEqualTo [0,0,0]}) then { _p = _lPos getPos [60 + random 100, random 360]; };
        private _u = _patrol2Grp createUnit [selectRandom _infantryPool, _p, [], 0, "FORM"];
        if (!isNull _u) then {
            _u allowFleeing 0;
            if (!isNil "DYN_fnc_boostOpforAwareness") then { [_u] call DYN_fnc_boostOpforAwareness; };
            _areaEnemies pushBack _u;
        };
    };

    // Wider patrol loop, offset angles so it doesn't overlap Squad 1
    for "_w" from 1 to 5 do {
        private _wpPos = [_lPos, 60, 250, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _wpPos || {_wpPos isEqualTo [0,0,0]}) then { _wpPos = _lPos getPos [80 + random 150, (_w * 72) + 36]; };
        private _wp = _patrol2Grp addWaypoint [_wpPos, 25];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
    };
    (_patrol2Grp addWaypoint [_lPos, 0]) setWaypointType "CYCLE";

    // --- Light vehicle patrol ---
    private _vehPool = ["CUP_O_UAZ_MG_RU", "CUP_O_GAZ_Vodnik_PK_RU"];
    private _vehClass = selectRandom _vehPool;
    private _vehSpawnPos = [_lPos, 20, 90, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_vehSpawnPos isEqualTo [0,0,0] || {surfaceIsWater _vehSpawnPos}) then {
        _vehSpawnPos = _lPos getPos [40, random 360];
    };

    private _veh = createVehicle [_vehClass, _vehSpawnPos, [], 0, "NONE"];
    _veh setDir (random 360);
    _veh setFuel 1;
    _veh lock 2;
    if (!isNil "DYN_AO_objects") then { DYN_AO_objects pushBack _veh; };

    private _vehGrp = createGroup east;
    _areaGroups pushBack _vehGrp;
    _vehGrp setBehaviour "AWARE";
    _vehGrp setCombatMode "RED";
    _vehGrp setSpeedMode "LIMITED";

    private _vDriver = _vehGrp createUnit ["CUP_O_RU_Soldier_Ratnik_Autumn", _vehSpawnPos, [], 0, "NONE"];
    if (!isNull _vDriver) then {
        _vDriver moveInDriver _veh;
        _vDriver allowFleeing 0;
        _vDriver setSkill (0.35 + random 0.15);
        _areaEnemies pushBack _vDriver;
    };

    private _vGunner = _vehGrp createUnit [selectRandom _infantryPool, _vehSpawnPos, [], 0, "NONE"];
    if (!isNull _vGunner) then {
        _vGunner moveInGunner _veh;
        _vGunner allowFleeing 0;
        _vGunner setSkill (0.35 + random 0.15);
        _areaEnemies pushBack _vGunner;
    };

    // Road patrol loop around the area
    for "_w" from 1 to 4 do {
        private _vwp = [_lPos, 50, 200, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_vwp isEqualTo [0,0,0] || {surfaceIsWater _vwp}) then { _vwp = _lPos getPos [80 + random 80, _w * 90]; };
        private _wp = _vehGrp addWaypoint [_vwp, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
    };
    (_vehGrp addWaypoint [_vehSpawnPos, 0]) setWaypointType "CYCLE";

    // --- Squad 4: Close-protection sentries guarding the laptop area ---
    private _guardGrp = createGroup east;
    _guardGrp setBehaviour "AWARE";
    _guardGrp setCombatMode "RED";
    _areaGroups pushBack _guardGrp;

    private _guardCount = 2 + floor (random 3);  // 2-4 units — static sentries
    for "_i" from 0 to (_guardCount - 1) do {
        private _p = [_lPos, 10, 60, 4, 0, 0.3, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _p || {_p isEqualTo [0,0,0]}) then { _p = _lPos getPos [15 + random 20, random 360]; };
        private _u = _guardGrp createUnit [selectRandom _infantryPool, _p, [], 0, "NONE"];
        if (!isNull _u) then {
            _u setUnitPos "UP";
            _u allowFleeing 0;
            if (!isNil "DYN_fnc_boostOpforAwareness") then { [_u] call DYN_fnc_boostOpforAwareness; };
            _areaEnemies pushBack _u;
        };
    };

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

    _lap setVariable ["DYN_res_taskId",        _resTaskId, true];
    _lap setVariable ["DYN_resIntelUsed",       false,      true];
    _lap setVariable ["DYN_resIntelDownloading",false,      true];

    if (!isNil "DYN_AO_objects") then { DYN_AO_objects pushBack _lap; };

    [_lap] remoteExec ["DYN_fnc_addResIntelAction", 0, true];

    // --- Complete task when 90% of area enemies are eliminated ---
    // OR despawn cleanly when main AO ends.
    // Threshold allows for 1-2 garrison units stuck inside buildings with no LoS.
    [_mName, _resTaskId, _areaEnemies, _areaGroups, _lName] spawn {
        params ["_marker", "_taskId", "_enemies", "_groups", "_name"];
        private _totalEnemies = count _enemies;
        private _clearThreshold = floor (_totalEnemies * 0.1) max 1;
        waitUntil {
            sleep 5;
            private _alive = { !isNull _x && alive _x } count _enemies;
            _alive <= _clearThreshold || {!(missionNamespace getVariable ["DYN_AO_active", false])}
        };
        private _alive = { !isNull _x && alive _x } count _enemies;
        if (_alive <= _clearThreshold) then {
            [_taskId, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, _taskId];
            private _clearRep = 3 + floor (random 3);   // 3-5 pts
            if (!isNil "DYN_fnc_changeReputation") then {
                [_clearRep, "Resistance Area Cleared"] call DYN_fnc_changeReputation;
            };
            ["TaskSucceeded", [format ["Resistance in %1 eliminated. +%2 reputation.", _name, _clearRep], "Area cleared."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log format ["[RESISTANCE] Area '%1' cleared (task %2) +%3 rep", _name, _taskId, _clearRep];
        } else {
            // AO ended — cancel task and despawn remaining resistance
            [_taskId, "CANCELED"] remoteExec ["BIS_fnc_taskSetState", 0, _taskId];
            { if (!isNull _x && alive _x) then { deleteVehicle _x } } forEach _enemies;
            { if (!isNull _x) then { deleteGroup _x } } forEach _groups;
            diag_log format ["[RESISTANCE] Area '%1' despawned — AO ended", _name];
        };
        sleep 3;
        deleteMarker _marker;
    };

    diag_log format ["[RESISTANCE] Area spawned: %1 at %2, task %3", _lName, _lPos, _resTaskId];

} forEach _selectedAreas;
