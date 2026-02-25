/*
    scripts\fn_spawnSideObjectives.sqf
    CUP RUSSIAN FORCES
    FIXED: _hvtClass scope, notifications, ACE interaction with progress bar + animation
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

// CUP pools
private _guardPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

if (isNil "DYN_AO_sideTasks") then { DYN_AO_sideTasks = []; };
if (isNil "DYN_AO_bonusTasks") then { DYN_AO_bonusTasks = []; };
if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };

missionNamespace setVariable ["DYN_HVTSpawned", false, true];

// =====================================================
// PROGRESS BAR SYSTEM
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

            // Background bar
            private _bgCtrl = findDisplay 46 ctrlCreate ["RscText", -1];
            _bgCtrl ctrlSetPosition [0.3, 0.02, 0.4, 0.045];
            _bgCtrl ctrlSetBackgroundColor [0.05, 0.05, 0.05, 0.85];
            _bgCtrl ctrlCommit 0;

            // Fill bar
            private _fillCtrl = findDisplay 46 ctrlCreate ["RscText", -1];
            _fillCtrl ctrlSetPosition [0.301, 0.022, 0, 0.041];
            _fillCtrl ctrlSetBackgroundColor [0.0, 0.55, 0.85, 0.9];
            _fillCtrl ctrlCommit 0;

            // Title text
            private _titleCtrl = findDisplay 46 ctrlCreate ["RscStructuredText", -1];
            _titleCtrl ctrlSetPosition [0.3, -0.02, 0.4, 0.04];
            _titleCtrl ctrlSetStructuredText parseText format [
                "<t align='center' size='0.9' color='#00BFFF' shadow='1'>%1</t>", _title
            ];
            _titleCtrl ctrlCommit 0;

            // Percentage text
            private _pctCtrl = findDisplay 46 ctrlCreate ["RscStructuredText", -1];
            _pctCtrl ctrlSetPosition [0.3, 0.065, 0.4, 0.03];
            _pctCtrl ctrlSetStructuredText parseText "<t align='center' size='0.85' color='#CCCCCC' shadow='1'>0%</t>";
            _pctCtrl ctrlCommit 0;

            private _success = false;

            while {(diag_tickTime - _startTime) < _duration} do {
                if !(call _condCheck) exitWith {};

                private _progress = ((diag_tickTime - _startTime) / _duration) min 1;
                private _pct = round (_progress * 100);

                _fillCtrl ctrlSetPosition [0.301, 0.022, 0.398 * _progress, 0.041];
                _fillCtrl ctrlCommit 0;

                _pctCtrl ctrlSetStructuredText parseText format [
                    "<t align='center' size='0.85' color='#CCCCCC' shadow='1'>%1%%</t>", _pct
                ];
                _pctCtrl ctrlCommit 0;

                private _r = 0.0;
                private _g = 0.55 + (_progress * 0.45);
                private _b = 0.85 - (_progress * 0.45);
                _fillCtrl ctrlSetBackgroundColor [_r, _g, _b, 0.9];

                sleep 0.05;
            };

            if (call _condCheck && {(diag_tickTime - _startTime) >= _duration}) then {
                _fillCtrl ctrlSetPosition [0.301, 0.022, 0.398, 0.041];
                _fillCtrl ctrlSetBackgroundColor [0.0, 1.0, 0.3, 1.0];
                _fillCtrl ctrlCommit 0;

                _pctCtrl ctrlSetStructuredText parseText "<t align='center' size='0.85' color='#00FF00' shadow='1'>COMPLETE</t>";
                _pctCtrl ctrlCommit 0;

                _titleCtrl ctrlSetStructuredText parseText format [
                    "<t align='center' size='0.9' color='#00FF00' shadow='1'>%1 - DONE</t>", _title
                ];
                _titleCtrl ctrlCommit 0;

                sleep 0.8;
                _success = true;
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
// SURRENDER HELPER
// =====================================================
if (isNil "DYN_fnc_applySurrenderState") then {
    DYN_fnc_applySurrenderState = {
        params ["_u"];
        if (isNull _u) exitWith {};

        _u setCaptive true;
        _u allowFleeing 0;
        _u disableAI "AUTOCOMBAT";
        _u disableAI "TARGET";
        _u disableAI "SUPPRESSION";
        _u setUnitPos "UP";

        [_u, "AmovPercMstpSsurWnonDnon"] remoteExecCall ["switchMove", 0, _u];
    };
    publicVariable "DYN_fnc_applySurrenderState";
};

// =====================================================
// SPAWN BONUS HVT MISSION
// =====================================================
if (isNil "DYN_fnc_spawnBonusHVT") then {
    DYN_fnc_spawnBonusHVT = {
        params ["_aoPos", "_aoRadius"];
        if (!isServer) exitWith {};

        private _hvtClass = "O_Officer_Parade_Veteran_F";

        private _hvtTaskId = format ["bonusHVT_%1", round (diag_tickTime * 1000)];

        private _allowedHouseTypes = [
            "Land_u_House_Small_01_V1_F",
            "Land_i_House_Small_02_V3_F",
            "Land_i_House_Small_02_V1_F",
            "Land_i_House_Small_02_V2_F",
            "Land_i_House_Small_01_V3_F",
            "Land_i_House_Small_01_V1_F"
        ];

        private _houses = nearestObjects [_aoPos, _allowedHouseTypes, _aoRadius * 0.70];
        _houses = _houses select { !isNull _x };
        if (_houses isEqualTo []) then {
            _houses = nearestObjects [_aoPos, ["House","Building"], _aoRadius * 0.70];
        };

        private _hvtPos = [];
        private _house = objNull;

        if (_houses isEqualTo []) then {
            _hvtPos = [_aoPos, 50, _aoRadius * 0.5, 10, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_hvtPos isEqualTo [0,0,0]) then { _hvtPos = _aoPos getPos [200, random 360]; };
        } else {
            _house = selectRandom _houses;

            private _housePositions = [];
            for "_i" from 0 to 80 do {
                private _p = _house buildingPos _i;
                if !(_p isEqualTo [0,0,0]) then { _housePositions pushBack _p; };
            };

            if (_housePositions isEqualTo []) then { _housePositions = [_house] call BIS_fnc_buildingPositions; };
            if (_housePositions isEqualTo []) then { _housePositions = [getPosATL _house]; };

            _hvtPos = selectRandom _housePositions;
        };

        if (isNil "_hvtPos" || {_hvtPos isEqualTo []}) then { _hvtPos = _aoPos getPos [100, random 360]; };

        // Guards
        private _gGrp = createGroup east;
        DYN_AO_enemyGroups pushBack _gGrp;
        _gGrp setBehaviour "AWARE";
        _gGrp setCombatMode "RED";

        private _insideGuardPool = [
            "CUP_O_RU_Soldier_Ratnik_Autumn",
            "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
            "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
            "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
        ];

        private _guardPositions = [];
        if (!isNull _house) then {
            for "_i" from 0 to 80 do {
                private _p = _house buildingPos _i;
                if !(_p isEqualTo [0,0,0]) then { _guardPositions pushBack _p; };
            };
        };

        if (_guardPositions isEqualTo []) then {
            for "_i" from 0 to 7 do {
                _guardPositions pushBack (_hvtPos getPos [3 + random 5, _i * 45]);
            };
        };

        for "_i" from 1 to 3 do {
            private _p = selectRandom _guardPositions;
            if (isNil "_p" || {_p isEqualTo []}) then { _p = _hvtPos getPos [3, random 360]; };

            private _u = _gGrp createUnit [selectRandom _insideGuardPool, _p, [], 0, "NONE"];
            if (!isNull _u) then {
                _u disableAI "PATH";
                _u setUnitPos (selectRandom ["UP","MIDDLE"]);
                _u allowFleeing 0;
                DYN_AO_enemies pushBack _u;
            };
        };

        private _outsideGuardPool = [
            "CUP_O_RU_Soldier_Ratnik_Autumn",
            "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
            "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
            "CUP_O_RU_Soldier_AA_Ratnik_Autumn"
        ];

        for "_i" from 1 to 6 do {
            private _p = [_hvtPos, 10, 40, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_p isEqualTo [0,0,0]) then { _p = _hvtPos getPos [20, _i * 60]; };

            private _u = _gGrp createUnit [selectRandom _outsideGuardPool, _p, [], 0, "FORM"];
            if (!isNull _u) then {
                _u allowFleeing 0;
                DYN_AO_enemies pushBack _u;
            };
        };

        for "_w" from 1 to 4 do {
            private _wpPos = [_hvtPos, 15, 80, 8, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_wpPos isEqualTo [0,0,0]) then { _wpPos = _hvtPos getPos [50, _w * 90]; };

            private _wp = _gGrp addWaypoint [_wpPos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "NORMAL";
        };
        (_gGrp addWaypoint [_hvtPos, 0]) setWaypointType "CYCLE";

        // HVT
        private _hvtGrp = createGroup east;
        DYN_AO_enemyGroups pushBack _hvtGrp;

        private _hvt = _hvtGrp createUnit [_hvtClass, _hvtPos, [], 0, "NONE"];
        if (isNull _hvt) then { _hvt = _hvtGrp createUnit ["O_officer_F", _hvtPos, [], 0, "NONE"]; };
        if (isNull _hvt) then { _hvt = _hvtGrp createUnit ["O_Soldier_F", _hvtPos, [], 0, "NONE"]; };
        if (isNull _hvt) exitWith {
            diag_log "[HVT] ERROR: Could not create HVT unit!";
        };

        _hvt setPosATL _hvtPos;
        removeAllWeapons _hvt;

        _hvt setCaptive true;
        _hvt disableAI "MOVE";
        _hvt disableAI "PATH";
        _hvt disableAI "FSM";
        _hvt disableAI "AUTOCOMBAT";
        _hvt disableAI "TARGET";
        _hvt setUnitPos "UP";

        _hvt setVariable ["hvtTaskId", _hvtTaskId, true];
        _hvt setVariable ["hvtCaptured", false, true];

        DYN_AO_enemies pushBack _hvt;

        [
            west,
            _hvtTaskId,
            [
                "Capture the HVT alive using ACE restraints and deliver him to the prison at base.",
                "Capture HVT",
                ""
            ],
            _hvtPos,
            "ASSIGNED",
            1,
            true,
            "meet"
        ] remoteExec ["BIS_fnc_taskCreate", 0, true];

        DYN_AO_bonusTasks pushBack _hvtTaskId;

        _hvt addEventHandler ["Killed", {
            params ["_unit"];
            private _tid = _unit getVariable ["hvtTaskId", ""];
            if (_tid != "") then { [_tid, "FAILED"] remoteExec ["BIS_fnc_taskSetState", 0, true]; };
        }];

        if (!isNil "DYN_fnc_registerAceCapture") then {
            [_hvt, _hvtTaskId, "HVT", "hvtCaptured"] call DYN_fnc_registerAceCapture;
        };

        diag_log format ["[HVT] Spawned at %1", _hvtPos];
    };
    publicVariable "DYN_fnc_spawnBonusHVT";
};

// =====================================================
// SERVER LAPTOP USED
// =====================================================
if (isNil "DYN_fnc_serverIntelLaptopUsed") then {
    DYN_fnc_serverIntelLaptopUsed = {
        params ["_laptop"];
        if (!isServer) exitWith {};
        if (isNull _laptop) exitWith {};

        private _caller = objNull;
        { if (owner _x == remoteExecutedOwner) exitWith { _caller = _x; }; } forEach allPlayers;
        if (isNull _caller) exitWith {};
        if (!alive _caller) exitWith {};
        if (side (group _caller) != west) exitWith {};
        if ((_caller distance _laptop) > 3) exitWith {};

        private _aoPos     = _laptop getVariable ["DYN_intel_aoPos", [0,0,0]];
        private _aoRadius  = _laptop getVariable ["DYN_intel_aoRadius", 0];
        private _hvtChance = _laptop getVariable ["DYN_intel_hvtChance", 0];

        deleteVehicle _laptop;

        if (missionNamespace getVariable ["DYN_HVTSpawned", false]) exitWith {
            ["RepStatus", ["Intel already processed."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
        };

        if ((random 1) > _hvtChance) exitWith {
            ["RepStatus", ["No actionable intelligence found."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
        };

        missionNamespace setVariable ["DYN_HVTSpawned", true, true];

        ["RepGain", ["HVT location identified from intel!"]]
            remoteExecCall ["BIS_fnc_showNotification", 0];

        [_aoPos, _aoRadius] spawn DYN_fnc_spawnBonusHVT;
    };
    publicVariable "DYN_fnc_serverIntelLaptopUsed";
};

// =====================================================
// CLIENT LAPTOP ACE INTERACTION + PROGRESS BAR + ANIMATION
// =====================================================
if (isNil "DYN_fnc_addLaptopHoldAction") then {
    DYN_fnc_addLaptopHoldAction = {
        params ["_lap"];
        if (isNull _lap) exitWith {};

        if (isNil "ace_interact_menu_fnc_createAction") exitWith {
            diag_log "[INTEL] ACE interact menu not loaded!";
        };

        private _action = [
            "DYN_DownloadIntel",
            "Download Intel",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
            {
                params ["_target", "_caller", "_params"];

                if (_target getVariable ["DYN_intelDownloading", false]) exitWith {
                    hint "Someone is already downloading from this laptop.";
                };

                _target setVariable ["DYN_intelDownloading", true, true];

                // Store references
                missionNamespace setVariable ["DYN_progressTarget", _target];
                missionNamespace setVariable ["DYN_progressCaller", _caller];
                missionNamespace setVariable ["DYN_progressActive", true];

                // Holster weapon for clean animation
                _caller action ["SwitchWeapon", _caller, _caller, 99];

                // Animation loop
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
                    "DOWNLOADING INTEL",
                    {
                        // On Complete
                        missionNamespace setVariable ["DYN_progressActive", false];

                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                        if (!isNull _c) then {
                            _c playMoveNow "";
                            _c switchMove "";
                        };

                        if (!isNull _t) then {
                            [_t] remoteExecCall ["DYN_fnc_serverIntelLaptopUsed", 2];
                        };
                    },
                    {
                        // On Cancel
                        missionNamespace setVariable ["DYN_progressActive", false];

                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                        if (!isNull _c) then {
                            _c playMoveNow "";
                            _c switchMove "";
                        };

                        if (!isNull _t) then {
                            _t setVariable ["DYN_intelDownloading", false, true];
                        };

                        hint "Download cancelled.";
                        [] spawn { sleep 2; hintSilent ""; };
                    },
                    {
                        // Condition check - stay alive and near laptop
                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                        !isNull _t
                        && {!isNull _c}
                        && {alive _c}
                        && {(_c distance _t) < 3}
                    }
                ] call DYN_fnc_showProgressBar;
            },
            {
                params ["_target", "_caller", "_params"];
                alive _caller
                && {(_caller distance _target) < 2.5}
                && {!isNull _target}
                && {!(_target getVariable ["DYN_intelDownloading", false])}
            }
        ] call ace_interact_menu_fnc_createAction;

        [_lap, 0, ["ACE_MainActions"], _action] call ace_interact_menu_fnc_addActionToObject;
    };
    publicVariable "DYN_fnc_addLaptopHoldAction";
};

// =====================================================
// INTEL LAPTOPS
// =====================================================
private _buildings = nearestObjects [_aoPos, ["House","Building"], _aoRadius * 0.60];

private _laptopCount = 5 + floor (random 11);
private _hvtChance = 0.35;

private _allPositions = [];
{ _allPositions append ([_x] call BIS_fnc_buildingPositions); } forEach _buildings;

_allPositions = _allPositions select { !(_x isEqualTo [0,0,0]) && !surfaceIsWater _x };
_allPositions = _allPositions call BIS_fnc_arrayShuffle;

private _useCount = _laptopCount min (count _allPositions);
private _spawned = 0;

for "_i" from 0 to (_useCount - 1) do {
    private _p = _allPositions select _i;

    private _lap = createVehicle ["Land_Laptop_unfolded_F", _p, [], 0, "NONE"];
    _lap setDir (random 360);

    private _pp = getPosATL _lap;
    _pp set [2, (_pp select 2) + 0.02];
    _lap setPosATL _pp;

    _lap setVariable ["DYN_intel_aoPos", _aoPos, false];
    _lap setVariable ["DYN_intel_aoRadius", _aoRadius, false];
    _lap setVariable ["DYN_intel_hvtChance", _hvtChance, false];

    DYN_AO_objects pushBack _lap;
    [_lap] remoteExec ["DYN_fnc_addLaptopHoldAction", 0, true];

    _spawned = _spawned + 1;
};

if (_spawned < _laptopCount) then {
    private _need = _laptopCount - _spawned;

    for "_i" from 1 to _need do {
        private _p = [_aoPos, 0, _aoRadius * 0.55, 6, 0, 0.6, 0] call BIS_fnc_findSafePos;
        if (surfaceIsWater _p) then { continue };

        private _lap = createVehicle ["Land_Laptop_unfolded_F", _p, [], 0, "NONE"];
        _lap setDir (random 360);

        private _pp = getPosATL _lap;
        _pp set [2, (_pp select 2) + 0.02];
        _lap setPosATL _pp;

        _lap setVariable ["DYN_intel_aoPos", _aoPos, false];
        _lap setVariable ["DYN_intel_aoRadius", _aoRadius, false];
        _lap setVariable ["DYN_intel_hvtChance", _hvtChance, false];

        DYN_AO_objects pushBack _lap;
        [_lap] remoteExec ["DYN_fnc_addLaptopHoldAction", 0, true];
    };
};

// =====================================================
// CACHE TASKS
// =====================================================
private _cacheCount = selectRandom [1, 2];

for "_i" from 1 to _cacheCount do {
    if (_buildings isEqualTo []) exitWith {};

    private _bld = selectRandom _buildings;
    private _bPosArr = [_bld] call BIS_fnc_buildingPositions;
    if (_bPosArr isEqualTo []) then { continue };

    private _bldPos = selectRandom _bPosArr;

    private _grp = createGroup east;
    DYN_AO_enemyGroups pushBack _grp;
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";

    private _cacheGuardPool = [
        "CUP_O_RU_Soldier_Ratnik_Autumn",
        "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
        "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
    ];

    for "_g" from 1 to 3 do {
        private _u = _grp createUnit [selectRandom _cacheGuardPool, _bldPos, [], 0, "NONE"];
        if (!isNull _u) then {
            _u allowFleeing 0;
            DYN_AO_enemies pushBack _u;
        };
    };

    private _taskId = format ["sideCache_%1", round (diag_tickTime * 1000)];
    DYN_AO_sideTasks pushBack _taskId;

    [
        west,
        _taskId,
        ["Destroy the weapons cache.", "Destroy Weapon Cache", ""],
        _bldPos,
        "ASSIGNED",
        1,
        true,
        "destroy"
    ] remoteExec ["BIS_fnc_taskCreate", 0, true];

    private _crateW = createVehicle ["Box_FIA_Wps_F", _bldPos, [], 0, "CAN_COLLIDE"];
    private _ammoPos = _bldPos getPos [1.5 + random 1.5, random 360];
    _ammoPos set [2, _bldPos select 2];
    private _crateA = createVehicle ["Box_FIA_Ammo_F", _ammoPos, [], 0, "CAN_COLLIDE"];

    DYN_AO_objects pushBack _crateW;
    DYN_AO_objects pushBack _crateA;

    {
        _x setVariable ["cacheTaskId", _taskId, true];
        _x setVariable ["cachePair", [_crateW, _crateA], false];

        _x addEventHandler ["Killed", {
            params ["_killed"];
            private _tid = _killed getVariable ["cacheTaskId", ""];
            if (_tid isEqualTo "") exitWith {};
            private _pair = _killed getVariable ["cachePair", []];
            if (_pair isEqualTo []) exitWith {};
            if (({ alive _x } count _pair) == 0) then {
                [_tid, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
            };
        }];
    } forEach [_crateW, _crateA];
};
