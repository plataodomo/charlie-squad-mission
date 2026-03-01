/*
    scripts\fn_mortarPit.sqf
    CUP RUSSIAN FORCES
*/
params ["_pos", "_aoRadius"];
if (!isServer) exitWith {};

// 70% spawn chance — skip 30% of the time
if (random 1 > 0.7) exitWith {
    diag_log "[MORTAR] Skipped — 30% no-spawn roll";
};

if (isNil "DYN_AO_hiddenTerrain") then { DYN_AO_hiddenTerrain = []; };
if (isNil "DYN_AO_objects") then { DYN_AO_objects = []; };
if (isNil "DYN_AO_enemies") then { DYN_AO_enemies = []; };
if (isNil "DYN_AO_enemyGroups") then { DYN_AO_enemyGroups = []; };
if (isNil "DYN_OBJ_centers") then { missionNamespace setVariable ["DYN_OBJ_centers", [], false]; };

// CUP Russian classes
private _mortarClass = "CUP_O_2b14_82mm_RU";
private _crewClass   = "CUP_O_RU_Soldier_Ratnik_Autumn";
private _guardClass  = "CUP_O_RU_Soldier_MG_Ratnik_Autumn";

// Mortar ammo type
private _ammoType = "8Rnd_82mm_Mo_shells";

// =====================================================
// OBJECTIVE SPACING - avoid other major objectives
// =====================================================
private _minFromObj = 600;
private _avoid = +(missionNamespace getVariable ["DYN_OBJ_centers", []]);

private _fn_farEnough = {
    params ["_p", "_avoidList", "_minDist"];
    private _ok = true;
    {
        if (!(_x isEqualTo []) && {!(_x isEqualTo [0,0,0])}) then {
            if ((_p distance2D _x) < _minDist) then {
                _ok = false;
            };
        };
    } forEach _avoidList;
    _ok
};

// =====================================================
// PICK POSITION
// =====================================================
private _mortarPos = [];
private _mortarDir = random 360;

private _margin = 120;
private _maxInside = (_aoRadius - _margin) max 50;
_maxInside = _maxInside min (_aoRadius - 20);

private _minDist = 200;
private _maxDist = (_aoRadius * 0.80) min _maxInside;

for "_attempt" from 1 to 80 do {
    private _testPos = [_pos, _minDist, _maxDist, 35, 0, 0.15, 0] call BIS_fnc_findSafePos;
    
    if ((_testPos distance2D _pos) > _maxInside) then { continue };
    if (surfaceIsWater _testPos) then { continue };
    if ((count (nearestObjects [_testPos, ["House","Building"], 80])) > 0) then { continue };
    
    // Check spacing from other objectives
    if !([_testPos, _avoid, _minFromObj] call _fn_farEnough) then { continue };
    
    private _g1 = abs ((getTerrainHeightASL _testPos) - (getTerrainHeightASL (_testPos getPos [18, 0])));
    private _g2 = abs ((getTerrainHeightASL _testPos) - (getTerrainHeightASL (_testPos getPos [18, 90])));
    if ((_g1 > 2) || (_g2 > 2)) then { continue };
    
    _mortarPos = _testPos;
    break;
};

if (_mortarPos isEqualTo []) then {
    for "_attempt" from 1 to 80 do {
        private _testPos = [_pos, (_aoRadius * 0.20), _maxInside, 40, 0, 0.12, 0] call BIS_fnc_findSafePos;
        
        if ((_testPos distance2D _pos) > _maxInside) then { continue };
        if (surfaceIsWater _testPos) then { continue };
        if ((count (nearestObjects [_testPos, ["House","Building"], 80])) > 0) then { continue };
        
        // Check spacing
        if !([_testPos, _avoid, _minFromObj] call _fn_farEnough) then { continue };
        
        _mortarPos = _testPos;
        break;
    };
};

// FALLBACK — if still no position, try multiple directions on land
if ((_mortarPos isEqualTo []) || {(_mortarPos distance2D _pos) > _maxInside} || {surfaceIsWater _mortarPos}) then {
    private _fallbackFound = false;
    for "_a" from 0 to 330 step 30 do {
        private _tryPos = _pos getPos [_maxInside, _a];
        if !(surfaceIsWater _tryPos) then {
            _mortarPos = _tryPos;
            _fallbackFound = true;
        };
        if (_fallbackFound) exitWith {};
    };
    // If every direction is water, abort — don't spawn in the ocean
    if (!_fallbackFound) exitWith {
        diag_log format ["[MORTAR] ABORTED — all fallback positions are water near %1", _pos];
    };
};

// Register this objective position
_avoid pushBack _mortarPos;
missionNamespace setVariable ["DYN_OBJ_centers", _avoid, false];

diag_log format ["[MORTAR] Spawning at %1 (dist from AO: %2m)", _mortarPos, round(_mortarPos distance2D _pos)];

// =====================================================
// TERRAIN HIDE
// =====================================================
private _hideTypes = ["BUSH","SMALL TREE","TREE","ROCK","ROCKS"];
private _hideRadius = 22;

{
    if (!(_x getVariable ["DYN_hiddenByAO", false])) then {
        _x setVariable ["DYN_hiddenByAO", true, false];
        _x hideObjectGlobal true;
        DYN_AO_hiddenTerrain pushBack _x;
    };
} forEach (nearestTerrainObjects [_mortarPos, _hideTypes, _hideRadius, false, true]);

// =====================================================
// PREFAB TRANSFORM HELPERS
// =====================================================
private _origCenter  = [23332.2, 18123.1];
private _origBaseASL = 3.19;
private _baseASLNew  = getTerrainHeightASL [_mortarPos#0, _mortarPos#1];

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

// =====================================================
// SURFACE-SNAPPED PLACEMENT (barriers / static objects)
// =====================================================
private _fn_placeStatic = {
    params ["_class", "_origX", "_origY", "_vecDir", "_origZASL"];
    private _offX = _origX - (_origCenter#0);
    private _offY = _origY - (_origCenter#1);
    private _rOff = [_offX, _offY, _mortarDir] call _fn_rot2D;
    private _newXY = [(_mortarPos#0) + (_rOff#0), (_mortarPos#1) + (_rOff#1)];

    private _obj = createVehicle [_class, [_newXY#0, _newXY#1, 0], [], 0, "CAN_COLLIDE"];

    _obj setPosATL [_newXY#0, _newXY#1, 0];

    private _dirRot = [_vecDir, _mortarDir, _fn_rot2D] call _fn_rotVec;

    private _surfNormal = surfaceNormal _newXY;
    private _dirFlat = [_dirRot#0, _dirRot#1, 0];
    private _sideVec = _dirFlat vectorCrossProduct _surfNormal;
    private _upVec = _surfNormal;
    private _fwdVec = _upVec vectorCrossProduct _sideVec;

    _obj setVectorDirAndUp [_fwdVec, _upVec];

    _obj enableSimulationGlobal false;
    _obj enableDynamicSimulation false;
    _obj allowDamage false;
    _obj setVelocity [0,0,0];
    _obj
};

// =====================================================
// MORTAR PLACEMENT — surface snapped + normal aligned
// =====================================================
private _fn_placeMortar = {
    params ["_class", "_origX", "_origY", "_vecDir", "_origZASL"];
    private _offX = _origX - (_origCenter#0);
    private _offY = _origY - (_origCenter#1);
    private _rOff = [_offX, _offY, _mortarDir] call _fn_rot2D;
    private _newXY = [(_mortarPos#0) + (_rOff#0), (_mortarPos#1) + (_rOff#1)];

    private _obj = createVehicle [_class, [_newXY#0, _newXY#1, 0], [], 0, "CAN_COLLIDE"];
    _obj allowDamage true;

    _obj setPosATL [_newXY#0, _newXY#1, 0];

    private _dirRot = [_vecDir, _mortarDir, _fn_rot2D] call _fn_rotVec;

    private _surfNormal = surfaceNormal _newXY;
    private _dirFlat = [_dirRot#0, _dirRot#1, 0];
    private _sideVec = _dirFlat vectorCrossProduct _surfNormal;
    private _upVec = _surfNormal;
    private _fwdVec = _upVec vectorCrossProduct _sideVec;

    _obj setVectorDirAndUp [_fwdVec, _upVec];
    _obj setVelocity [0,0,0];

    [_obj, _newXY, _fwdVec, _upVec] spawn {
        params ["_o","_xy","_fwd","_up"];
        sleep 0.2;
        if (!isNull _o) then {
            _o setPosATL [_xy#0, _xy#1, 0];
            _o setVectorDirAndUp [_fwd, _up];
            _o setVelocity [0,0,0];
        };
    };
    _obj
};

// =====================================================
// STRUCTURE
// =====================================================
private _struct = [
    ["Land_HBarrier_Big_F",23340.9,18116.6,[-0.831791, 0.555089,0], 4.4],
    ["Land_HBarrier_Big_F",23341.9,18122.2,[-0.965254,-0.261315,0], 4.4],
    ["Land_HBarrier_Big_F",23338.5,18127.7,[-0.712882,-0.701284,0], 4.4],
    ["Land_HBarrier_Big_F",23336.9,18112.2,[ 0.477092,-0.878853,0], 4.4],
    ["Land_HBarrier_Big_F",23332.8,18129.9,[ 0.104173,-0.994559,0], 4.4],
    ["Land_HBarrier_Big_F",23328.9,18132.7,[ 0.982412, 0.186728,0], 4.4],
    ["Land_HBarrier_Big_F",23331.3,18112.2,[-0.509101,-0.860707,0], 4.4],
    ["Land_HBarrier_Big_F",23323.6,18122.2,[ 0.988647, 0.150254,0], 4.4],
    ["Land_HBarrier_Big_F",23326.8,18116.1,[-0.753866,-0.657028,0], 4.4],
    ["Land_HBarrier_Big_F",23323.3,18129.2,[-0.995203, 0.0978338,0], 4.4],
    ["Land_BagFence_Round_F",23330.8,18119.7,[-0.631432, 0.775432,0], 3.60931],
    ["Land_BagFence_Round_F",23327.9,18123.2,[ 0.685083,-0.728465,0], 3.60931],
    ["Land_BagFence_Round_F",23334.9,18113.7,[-0.631432, 0.775432,0], 3.60931],
    ["Land_BagFence_Round_F",23332.4,18117.2,[ 0.4697,  -0.882826,0], 3.60931],
    ["Land_BagFence_Round_F",23337.9,18117.1,[-0.590895, 0.806749,0], 3.60931],
    ["Land_BagFence_Round_F",23335.3,18121.1,[ 0.608912,-0.793238,0], 3.60931],
    ["Land_BagFence_Round_F",23334.3,18127.3,[ 0.608912,-0.793238,0], 3.60931],
    ["Land_BagFence_Round_F",23336.8,18124.2,[-0.736,    0.676982,0], 3.60931]
];

{
    _x params ["_cls","_xw","_yw","_vec","_zAsl"];
    DYN_AO_objects pushBack ([_cls, _xw, _yw, _vec, _zAsl] call _fn_placeStatic);
} forEach _struct;

// =====================================================
// Mortars (2-4)
// =====================================================
private _mortarSpots = [
    [23335.1,18125.5,[0,1,0], 3.91163],
    [23336.7,18119.0,[0,1,0], 3.91163],
    [23333.5,18115.3,[0,1,0], 3.91163],
    [23329.4,18121.3,[0,1,0], 3.91163]
] call BIS_fnc_arrayShuffle;

private _mortarCount = (2 + floor (random 3)) min (count _mortarSpots);
private _mortars = [];

private _mortarGrp = createGroup east;
DYN_AO_enemyGroups pushBack _mortarGrp;
_mortarGrp setBehaviour "AWARE";
_mortarGrp setCombatMode "RED";

private _fn_setMortarSkill = {
    params ["_u"];
    _u setSkill 0.50;
    { _u setSkill [_x, 0.50]; } forEach [
        "aimingAccuracy","aimingShake","aimingSpeed",
        "spotDistance","spotTime",
        "courage","reloadSpeed",
        "commanding","general"
    ];
    _u allowFleeing 0;
};

for "_i" from 0 to (_mortarCount - 1) do {
    (_mortarSpots select _i) params ["_mx","_my","_vec","_zAsl"];
    private _m = [_mortarClass, _mx, _my, _vec, _zAsl] call _fn_placeMortar;
    DYN_AO_objects pushBack _m;
    _mortars pushBack _m;
    
    [_m, _mortarGrp, _fn_setMortarSkill, _crewClass] spawn {
        params ["_mortar", "_grp", "_fnSkill", "_crewClass"];
        sleep 0.8;
        if (isNull _mortar) exitWith {};
        
        private _mPos = getPosATL _mortar;
        
        private _gunner = _grp createUnit [_crewClass, [_mPos#0, _mPos#1, 0], [], 0, "NONE"];
        
        _gunner setPosATL [_mPos#0, _mPos#1, 0];
        
        sleep 0.2;
        _gunner moveInGunner _mortar;
        sleep 0.5;
        if (vehicle _gunner != _mortar) then {
            _gunner moveInGunner _mortar;
        };
        
        sleep 0.3;
        if (vehicle _gunner == _gunner) then {
            private _safePos = getPosATL _mortar;
            _gunner setPosATL [_safePos#0, _safePos#1, 0];
            sleep 0.1;
            _gunner moveInGunner _mortar;
        };
        
        [_gunner] call _fnSkill;
        DYN_AO_enemies pushBack _gunner;
    };
};

// =====================================================
// Guards — surface snapped, terrain normal aligned
// =====================================================
private _guardGrp = createGroup east;
DYN_AO_enemyGroups pushBack _guardGrp;
_guardGrp setBehaviour "AWARE";
_guardGrp setCombatMode "RED";

private _fn_dirFromVec = {
    params ["_v"];
    private _d = (_v select 0) atan2 (_v select 1);
    if (_d < 0) then { _d = _d + 360 };
    _d
};

private _guardSpots = [
    [23342.5,18127.5,[1,0,0]],
    [23327.0,18112.0,[0,1,0]],
    [23323.0,18129.0,[0,1,0]]
];

{
    _x params ["_gx","_gy","_vec"];
    private _offX = _gx - (_origCenter#0);
    private _offY = _gy - (_origCenter#1);
    private _rOff = [_offX, _offY, _mortarDir] call _fn_rot2D;
    private _gXY = [(_mortarPos#0) + (_rOff#0), (_mortarPos#1) + (_rOff#1)];
    
    private _g = _guardGrp createUnit [_guardClass, [_gXY#0,_gXY#1,0], [], 0, "NONE"];
    
    _g setPosATL [_gXY#0, _gXY#1, 0];
    
    _g setDir (([_vec] call _fn_dirFromVec) + _mortarDir);
    _g disableAI "PATH";
    _g setUnitPos "UP";
    _g allowFleeing 0;
    
    [_g, _gXY] spawn {
        params ["_unit", "_xy"];
        sleep 0.5;
        if (!isNull _unit && alive _unit) then {
            private _curPos = getPosATL _unit;
            if (_curPos#2 < -0.3) then {
                _unit setPosATL [_xy#0, _xy#1, 0];
            };
        };
    };
    
    DYN_AO_enemies pushBack _g;
} forEach _guardSpots;

// =====================================================
// FIRE SUPPORT LOGIC
// =====================================================
[_mortars, _pos, _aoRadius, _ammoType] spawn {
    params ["_mortars", "_aoPos", "_aoRadius", "_ammoType"];
    
    private _knowsThreshold = 0.6;
    sleep 25;
    
    while { DYN_AO_active } do {
        private _dlActive = !(missionNamespace getVariable ["DYN_dataLinkDisabled", true]);
        sleep (if (_dlActive) then {8} else {12});
        
        private _activeMortars = _mortars select {
            !isNull _x
            && {alive _x}
            && {!isNull (gunner _x)}
            && {alive (gunner _x)}
        };
        
        if (_activeMortars isEqualTo []) exitWith {};
        
        private _players = allPlayers select {
            alive _x
            && {side (group _x) == west}
            && {(_x distance2D _aoPos) < _aoRadius}
        };
        
        if (_players isEqualTo []) then { continue };
        
        // Only sample up to 30 spotters to cap cost
        private _spotterCandidates = DYN_AO_enemies select {
            !isNull _x
            && {alive _x}
            && {_x isKindOf "Man"}
            && {behaviour _x in ["AWARE","COMBAT"]}
        };
        
        if (_spotterCandidates isEqualTo []) then { continue };
        private _spotters = if (count _spotterCandidates > 30) then {
            (_spotterCandidates call BIS_fnc_arrayShuffle) select [0, 30]
        } else { _spotterCandidates };
        
        private _bestP = objNull;
        private _bestK = 0;
        
        {
            private _p = _x;
            private _k = 0;
            { _k = _k max (_x knowsAbout _p); if (_k >= 4) exitWith {}; } forEach _spotters;
            if (_k > _bestK) then { _bestK = _k; _bestP = _p; };
        } forEach _players;
        
        if (isNull _bestP || {_bestK < _knowsThreshold}) then { continue };
        
        private _tPos = (getPosATL _bestP) getPos [15 + random 35, random 360];
        
        private _readyMortars = _activeMortars select {
            (_ammoType in (getArtilleryAmmo [_x]))
            && { _tPos inRangeOfArtillery [[_x], _ammoType] }
        };
        
        if (_readyMortars isEqualTo []) then { continue };
        
        private _maxFire = if (_dlActive) then {2} else {1};
        private _fireCount = (1 + floor (random (_maxFire + 1))) min (count _readyMortars);
        private _pick = (_readyMortars call BIS_fnc_arrayShuffle) select [0, _fireCount];
        private _rounds = if (_dlActive) then { 3 + floor (random 3) } else { 2 + floor (random 2) };
        
        { _x doArtilleryFire [_tPos, _ammoType, _rounds]; } forEach _pick;
        
        sleep (if (_dlActive) then { 18 + random 12 } else { 28 + random 18 });
    };
};
