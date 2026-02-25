/*
    scripts\fn_dataLink.sqf
    CUP RUSSIAN FORCES
    UPDATED: ACE interaction with progress bar + terminal animation
*/

params ["_aoPos", "_aoRadius"];
if (!isServer) exitWith {};

// CUP Russian unit pools
private _insidePool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

private _patrolPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AA_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn"
];

if (isNil "DYN_AO_hiddenTerrain") then { DYN_AO_hiddenTerrain = []; };
if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_AO_bonusTasks") then { DYN_AO_bonusTasks = []; };

missionNamespace setVariable ["DYN_dataLinkDisabled", true, true];

// Position finding
private _margin = 220;
private _maxInside = (_aoRadius - _margin) max 60;
_maxInside = _maxInside min (_aoRadius - 20);

private _minDist = 180;
private _maxDist = (_aoRadius * 0.80) min _maxInside;

private _footR = 18;
private _maxDeltaH = 0.55;

private _fn_sampleHeights = {
    params ["_p", "_r"];
    private _hs = [getTerrainHeightASL _p];
    { _hs pushBack (getTerrainHeightASL (_p getPos [_r, _x])); } forEach [0,45,90,135,180,225,270,315];
    [selectMin _hs, selectMax _hs]
};

private _fn_footprintDry = {
    params ["_p", "_r"];
    if (surfaceIsWater _p) exitWith {false};
    { if (surfaceIsWater (_p getPos [_r, _x])) exitWith {false}; } forEach [0,45,90,135,180,225,270,315];
    true
};

private _fn_findSite = {
    params ["_vegMin", "_bldDist", "_tries"];

    private _best = [];
    private _bestDH = 1e9;

    for "_i" from 1 to _tries do {
        private _cand = [_aoPos, _minDist, _maxDist, 25, 1, 0.35, 0] call BIS_fnc_findSafePos;
        if (_cand isEqualTo [0,0,0]) then { continue };
        if ((_cand distance2D _aoPos) > _maxInside) then { continue };

        if !([_cand, _footR] call _fn_footprintDry) then { continue };

        if (isOnRoad _cand) then { continue };
        if ((count (_cand nearRoads 60)) > 0) then { continue };
        if (_bldDist > 0 && {(count (nearestObjects [_cand, ["House","Building"], _bldDist])) > 0}) then { continue };

        if (_vegMin > 0) then {
            private _veg = nearestTerrainObjects [_cand, ["BUSH","SMALL TREE","TREE"], 25];
            if ((count _veg) < _vegMin) then { continue };
        };

        private _hh = [_cand, _footR] call _fn_sampleHeights;
        private _dH = (_hh#1) - (_hh#0);

        if (_dH < _bestDH) then { _bestDH = _dH; _best = _cand; };
        if (_dH <= _maxDeltaH) exitWith { _best = _cand; };
    };

    _best
};

private _sitePos = [16, 90, 220] call _fn_findSite;
if (_sitePos isEqualTo []) then { _sitePos = [10, 90, 260] call _fn_findSite; };
if (_sitePos isEqualTo []) then { _sitePos = [0,  90, 300] call _fn_findSite; };

if (_sitePos isEqualTo []) then {
    _sitePos = [_aoPos, _minDist, _maxDist, 25, 1, 0.50, 0] call BIS_fnc_findSafePos;
};

if (_sitePos isEqualTo [0,0,0] || {surfaceIsWater _sitePos}) exitWith {};

private _siteDir = random 360;

missionNamespace setVariable ["DYN_dataLinkDisabled", false, true];

if (!isNil "DYN_fnc_refreshOpforAwareness") then {
    call DYN_fnc_refreshOpforAwareness;
} else {
    if (!isNil "DYN_fnc_boostOpforAwareness") then {
        { [_x] call DYN_fnc_boostOpforAwareness; } forEach allUnits;
    };
};

// Hide terrain
{
    if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
        _x setVariable ["DYN_hiddenByAO", true, false];
        _x hideObjectGlobal true;
        DYN_AO_hiddenTerrain pushBack _x;
    };
} forEach (nearestTerrainObjects [_sitePos, ["BUSH","SMALL TREE","TREE","ROCK","ROCKS"], 30, false, true]);

// Task
private _taskId = format ["bonusDataLink_%1", round (diag_tickTime * 1000)];

[
    west,
    _taskId,
    [
        "Enemy data link node is improving their coordination, air response and indirect fire. Locate the uplink site and disable it via the control tablet.",
        "Disable Data Link",
        ""
    ],
    _sitePos,
    "ASSIGNED",
    1,
    true,
    "download"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_AO_bonusTasks pushBack _taskId;

// Prefab helpers
private _origCenter  = [4573.91, 1461.00];
private _origBaseASL = 5.00;

private _fn_rot2D = {
    params ["_x","_y","_deg"];
    private _c = cos _deg;
    private _s = sin _deg;
    [(_x*_c - _y*_s), (_x*_s + _y*_c)]
};

private _fn_rotVec = {
    params ["_v","_deg","_fnRot"];
    private _r = [_v#0, _v#1, _deg] call _fnRot;
    [_r#0, _r#1, (_v param [2,0])]
};

private _baseASLNew = getTerrainHeightASL [_sitePos#0, _sitePos#1];

private _fn_freezeProp = {
    params ["_o"];
    if (isNull _o) exitWith {};
    _o enableSimulationGlobal false;
    _o enableDynamicSimulation false;
    _o allowDamage false;
    _o setDamage 0;
    _o setVelocity [0,0,0];
};

private _fn_placeExport = {
    params ["_class", "_origX", "_origY", "_vecDir", "_origZASL", ["_special","CAN_COLLIDE"]];

    private _offX = _origX - (_origCenter#0);
    private _offY = _origY - (_origCenter#1);

    private _rOff  = [_offX, _offY, _siteDir] call _fn_rot2D;
    private _newXY = [(_sitePos#0) + (_rOff#0), (_sitePos#1) + (_rOff#1)];

    private _zOff = _origZASL - _origBaseASL;
    private _newASL = [_newXY#0, _newXY#1, _baseASLNew + _zOff];

    private _obj = createVehicle [_class, [_newXY#0, _newXY#1, 0], [], 0, _special];
    private _dirRot = [_vecDir, _siteDir, _fn_rot2D] call _fn_rotVec;

    _obj setPosWorld _newASL;
    _obj setVectorDirAndUp [_dirRot, [0,0,1]];
    _obj setVelocity [0,0,0];
    _obj
};

private _fn_safeAnimate = {
    params ["_obj", "_animName", "_phase"];
    if (isNull _obj) exitWith {};
    if (_animName in (animationNames _obj)) then { _obj animate [_animName, _phase, true]; };
};

// Spawn prefab objects
private _building = ["Land_Cargo_House_V3_F", 4573.73,1459.15, [-0.656271,0.754525,0], 5.69] call _fn_placeExport;
DYN_AO_objects pushBack _building;

private _desk = ["Land_PortableDesk_01_sand_F", 4572.20,1458.16, [-0.67373,0.738977,0], 6.0367] call _fn_placeExport;
DYN_AO_objects pushBack _desk;
[_desk] call _fn_freezeProp;

{ [_desk, _x, 0] call _fn_safeAnimate; } forEach ["Drawer_1_move_source","Drawer_2_move_source","Drawer_3_move_source","Drawer_4_move_source","Drawer_5_move_source","Drawer_6_move_source"];
[_desk, "Lid_1_hide_source", 1] call _fn_safeAnimate;
[_desk, "Lid_2_hide_source", 1] call _fn_safeAnimate;
[_desk, "Wing_L_hide_source", 0] call _fn_safeAnimate;
[_desk, "Wing_R_hide_source", 0] call _fn_safeAnimate;

private _cab1 = ["Land_PortableCabinet_01_closed_sand_F", 4572.77,1463.15, [0.312656,-0.949866,0], 5.89244] call _fn_placeExport;
DYN_AO_objects pushBack _cab1; [_cab1] call _fn_freezeProp;

private _book1 = ["Land_PortableCabinet_01_bookcase_sand_F", 4574.50,1461.96, [0.770653,0.637255,0], 6.01076] call _fn_placeExport;
DYN_AO_objects pushBack _book1; [_book1] call _fn_freezeProp;
{ _book1 setObjectTextureGlobal [_x, "a3\props_f_enoch\military\camps\data\portablecabinet_01_books_co.paa"]; } forEach [1,2,3,4,5,6,7,8,9];

private _draw7 = ["Land_PortableCabinet_01_7drawers_sand_F", 4573.96,1462.47, [0.777292,0.62914,0], 6.1468] call _fn_placeExport;
DYN_AO_objects pushBack _draw7; [_draw7] call _fn_freezeProp;

private _draw4 = ["Land_PortableCabinet_01_4drawers_sand_F", 4573.62,1462.89, [0.750618,0.660736,0], 6.1468] call _fn_placeExport;
DYN_AO_objects pushBack _draw4; [_draw4] call _fn_freezeProp;

private _book2 = ["Land_PortableCabinet_01_bookcase_sand_F", 4574.85,1461.54, [0.770653,0.637255,0], 6.01076] call _fn_placeExport;
DYN_AO_objects pushBack _book2; [_book2] call _fn_freezeProp;
{ _book2 setObjectTextureGlobal [_x, "a3\props_f_enoch\military\camps\data\portablecabinet_01_books_co.paa"]; } forEach [1,2,3,4,5,6,7,8,9];

private _book3 = ["Land_PortableCabinet_01_bookcase_sand_F", 4575.21,1461.13, [0.770653,0.637255,0], 6.01076] call _fn_placeExport;
DYN_AO_objects pushBack _book3; [_book3] call _fn_freezeProp;
{ _book3 setObjectTextureGlobal [_x, "a3\props_f_enoch\military\camps\data\portablecabinet_01_books_co.paa"]; } forEach [1,2,3,4,5,6,7,8,9];

private _cab2 = ["Land_PortableCabinet_01_closed_sand_F", 4571.95,1462.55, [0.755744,-0.654867,0], 5.89244] call _fn_placeExport;
DYN_AO_objects pushBack _cab2; [_cab2] call _fn_freezeProp;

private _pcScreen = ["Land_PCSet_01_screen_F", 4571.70,1457.54, [0.150834,-0.988559,0], 6.73443] call _fn_placeExport;
DYN_AO_objects pushBack _pcScreen; [_pcScreen] call _fn_freezeProp;
_pcScreen setObjectTextureGlobal [0,"#(argb,8,8,3)color(0,0,0,0,co)"];

private _pcKb = ["Land_PCSet_01_keyboard_F", 4571.70,1457.91, [0.300617,-0.953745,0], 6.48768] call _fn_placeExport;
DYN_AO_objects pushBack _pcKb; [_pcKb] call _fn_freezeProp;

private _pcMouse = ["Land_PCSet_01_mouse_F", 4571.44,1457.68, [0.302545,-0.953135,0], 6.50496] call _fn_placeExport;
DYN_AO_objects pushBack _pcMouse; [_pcMouse] call _fn_freezeProp;

private _ant1 = ["SatelliteAntenna_01_Mounted_Sand_F", 4568.88,1459.84, [-0.754554,-0.656238,0], 7.8865] call _fn_placeExport;
private _ant2 = ["SatelliteAntenna_01_Mounted_Sand_F", 4573.58,1464.24, [ 0.734068, 0.679076,0], 7.66976] call _fn_placeExport;
private _ant3 = ["OmniDirectionalAntenna_01_sand_F",   4579.12,1462.69, [ 0.0486881,-0.998814,0], 7.04146] call _fn_placeExport;
{ DYN_AO_objects pushBack _x; } forEach [_ant1,_ant2,_ant3];

// Tablet
private _tablet = ["Land_Tablet_02_sand_F", 4572.50,1458.62, [-0.576886,0.816825,0], 6.51391] call _fn_placeExport;
DYN_AO_objects pushBack _tablet;

_tablet allowDamage false;
_tablet setObjectTextureGlobal [0,"a3\structures_f_heli\items\electronics\data\tablet_screen_co.paa"];
_tablet setVariable ["DYN_dataLinkDisabled", false, true];
_tablet setVariable ["DYN_dataLinkTaskId", _taskId, true];
[_tablet] call _fn_freezeProp;

private _offset = [0.3, 0.46, 0.47721];
private _c = cos _siteDir;
private _s = sin _siteDir;
private _offR = [(_offset#0)*_c - (_offset#1)*_s, (_offset#0)*_s + (_offset#1)*_c, _offset#2];

private _deskW = getPosWorld _desk;
private _tabletW = [_deskW#0 + _offR#0, _deskW#1 + _offR#1, _deskW#2 + _offR#2];
_tablet setPosWorld _tabletW;
_tablet setVelocity [0,0,0];

[_tablet, _tabletW] spawn {
    params ["_tab","_pW"];
    sleep 0.1;
    if (!isNull _tab) then {
        _tab setPosWorld _pW;
        _tab setVelocity [0,0,0];
        _tab enableSimulationGlobal false;
    };
};

// Inside guards
private _insideGrp = createGroup east;
DYN_AO_enemyGroups pushBack _insideGrp;
_insideGrp setBehaviour "AWARE";
_insideGrp setCombatMode "RED";

private _inside = [_building] call BIS_fnc_buildingPositions;
if (_inside isEqualTo []) then { _inside = [getPosATL _building]; };

private _insideCount = 3 + floor (random 3);
for "_i" from 1 to _insideCount do {
    private _p = selectRandom _inside;
    private _u = _insideGrp createUnit [selectRandom _insidePool, _p, [], 0, "NONE"];
    _u disableAI "PATH";
    _u setUnitPos (selectRandom ["UP","MIDDLE"]);
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

// Patrol 1
private _patrolGrp1 = createGroup east;
DYN_AO_enemyGroups pushBack _patrolGrp1;
_patrolGrp1 setBehaviour "AWARE";
_patrolGrp1 setCombatMode "RED";
_patrolGrp1 setSpeedMode "LIMITED";

private _patrol1Count = 4 + floor (random 3);
for "_i" from 1 to _patrol1Count do {
    private _p = [_sitePos, 15, 40, 6, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _p) then { _p = _sitePos getPos [20, random 360]; };

    private _u = _patrolGrp1 createUnit [selectRandom _patrolPool, _p, [], 0, "FORM"];
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

for "_w" from 1 to 5 do {
    private _wpPos = [_sitePos, 30, 80, 8, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _wpPos) then { _wpPos = _sitePos getPos [50, _w * 72]; };

    private _wp = _patrolGrp1 addWaypoint [_wpPos, 10];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCompletionRadius 15;
};
(_patrolGrp1 addWaypoint [_sitePos getPos [40, random 360], 0]) setWaypointType "CYCLE";

// Patrol 2
private _patrolGrp2 = createGroup east;
DYN_AO_enemyGroups pushBack _patrolGrp2;
_patrolGrp2 setBehaviour "AWARE";
_patrolGrp2 setCombatMode "RED";
_patrolGrp2 setSpeedMode "NORMAL";

private _patrol2Count = 3 + floor (random 3);
for "_i" from 1 to _patrol2Count do {
    private _p = [_sitePos, 50, 100, 8, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _p) then { _p = _sitePos getPos [70, random 360]; };

    private _u = _patrolGrp2 createUnit [selectRandom _patrolPool, _p, [], 0, "FORM"];
    _u allowFleeing 0;
    DYN_AO_enemies pushBack _u;
};

for "_w" from 1 to 6 do {
    private _wpPos = [_sitePos, 80, 150, 10, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (surfaceIsWater _wpPos) then { _wpPos = _sitePos getPos [100, _w * 60]; };

    private _wp = _patrolGrp2 addWaypoint [_wpPos, 15];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCompletionRadius 20;
};
(_patrolGrp2 addWaypoint [_sitePos getPos [90, random 360], 0]) setWaypointType "CYCLE";

// =====================================================
// SERVER DISABLE FUNCTION
// =====================================================
if (isNil "DYN_fnc_serverDisableDataLink") then {
    DYN_fnc_serverDisableDataLink = {
        params ["_tablet"];
        if (!isServer) exitWith {};
        if (isNull _tablet) exitWith {};
        if (_tablet getVariable ["DYN_dataLinkDisabled", false]) exitWith {};

        private _caller = objNull;
        { if (owner _x == remoteExecutedOwner) exitWith { _caller = _x; }; } forEach allPlayers;
        if (isNull _caller) exitWith {};
        if (!alive _caller) exitWith {};
        if (side (group _caller) != west) exitWith {};
        if ((_caller distance _tablet) > 3) exitWith {};

        _tablet setVariable ["DYN_dataLinkDisabled", true, true];
        missionNamespace setVariable ["DYN_dataLinkDisabled", true, true];

        private _tid = _tablet getVariable ["DYN_dataLinkTaskId", ""];
        if (_tid != "") then { [_tid, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, true]; };

        ["TaskSucceeded", ["Data Link Disabled", "Enemy coordination degraded."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];

        if (!isNil "DYN_fnc_refreshOpforAwareness") then { call DYN_fnc_refreshOpforAwareness; };
    };
    publicVariable "DYN_fnc_serverDisableDataLink";
};

// =====================================================
// CLIENT ACE INTERACTION - TABLET (8 seconds)
// =====================================================
if (isNil "DYN_fnc_addDataLinkHoldAction") then {
    DYN_fnc_addDataLinkHoldAction = {
        params ["_tablet"];
        if (isNull _tablet) exitWith {};

        if (isNil "ace_interact_menu_fnc_createAction") exitWith {
            diag_log "[DATALINK] ACE interact menu not loaded!";
        };

        private _action = [
            "DYN_DisableDataLink",
            "Disable Data Link",
            "\a3\ui_f\data\IGUI\Cfg\HoldActions\holdAction_hack_ca.paa",
            {
                params ["_target", "_caller", "_params"];

                if (_target getVariable ["DYN_dataLinkHacking", false]) exitWith {
                    hint "Someone is already hacking this terminal.";
                };

                _target setVariable ["DYN_dataLinkHacking", true, true];

                missionNamespace setVariable ["DYN_progressTarget", _target];
                missionNamespace setVariable ["DYN_progressCaller", _caller];
                missionNamespace setVariable ["DYN_progressActive", true];

                // Holster weapon
                _caller action ["SwitchWeapon", _caller, _caller, 99];

                // Animation loop - kneeling work animation (reliable with all stances)
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
                    8,
                    "HACKING DATA LINK",
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
                            [_t] remoteExecCall ["DYN_fnc_serverDisableDataLink", 2];
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
                            _t setVariable ["DYN_dataLinkHacking", false, true];
                        };

                        hint "Hack cancelled.";
                        [] spawn { sleep 2; hintSilent ""; };
                    },
                    {
                        // Condition check
                        private _t = missionNamespace getVariable ["DYN_progressTarget", objNull];
                        private _c = missionNamespace getVariable ["DYN_progressCaller", objNull];

                        !isNull _t
                        && {!isNull _c}
                        && {alive _c}
                        && {(_c distance _t) < 4}
                    }
                ] call DYN_fnc_showProgressBar;
            },
            {
                params ["_target", "_caller", "_params"];
                alive _caller
                && {(_caller distance _target) < 4}
                && {!isNull _target}
                && {!(_target getVariable ["DYN_dataLinkDisabled", false])}
                && {!(_target getVariable ["DYN_dataLinkHacking", false])}
            }
        ] call ace_interact_menu_fnc_createAction;

        [_tablet, 0, ["ACE_MainActions"], _action] call ace_interact_menu_fnc_addActionToObject;
    };
    publicVariable "DYN_fnc_addDataLinkHoldAction";
};

[_tablet] remoteExec ["DYN_fnc_addDataLinkHoldAction", 0, true];

diag_log format ["[DATALINK] Spawned at %1", _sitePos];
