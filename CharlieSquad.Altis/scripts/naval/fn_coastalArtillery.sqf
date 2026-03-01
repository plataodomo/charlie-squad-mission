/*
    scripts\naval\fn_coastalArtillery.sqf
    NAVAL MISSION: Destroy Coastal Artillery Battery
    Full composition: "Outpost Machiavelli" with BM-21 MLRS battery
    
    FIXES APPLIED:
    - All getPos on position arrays replaced with DYN_fnc_posOffset
    - Surgical cleanup of global arrays instead of wiping
    - Hidden terrain tracked via DYN_naval_hiddenTerrain
    - Task deleted during cleanup
*/
if (!isServer) exitWith {};

diag_log "[NAVAL-ARTY] Setting up Coastal Artillery mission...";

// =====================================================
// 1. FIND POSITION
// =====================================================
private _waterPos = [2500, 2000] call DYN_fnc_findNavalWaterPos;

if (_waterPos isEqualTo []) exitWith {
    diag_log "[NAVAL-ARTY] Could not find water position. Aborting.";
    DYN_naval_active = false;
};

private _landPos = [_waterPos, 500, 60] call DYN_fnc_findCoastalLandPos;

if (_landPos isEqualTo []) exitWith {
    diag_log "[NAVAL-ARTY] Could not find coastal land position. Aborting.";
    DYN_naval_active = false;
};

diag_log format ["[NAVAL-ARTY] Land pos: %1", _landPos];

// =====================================================
// 2. SETTINGS
// =====================================================
private _timeout    = 7200; // 2 hours
private _repReward  = 10 + floor random 8;
private _dirToSea   = [_landPos] call DYN_fnc_dirToWater;
private _cleanupDelay = 600;

private _infPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AA_Ratnik_Autumn"
];

private _taskId = format ["naval_arty_%1", round (diag_tickTime * 1000)];

// =====================================================
// 3. CLEAR TERRAIN & SPAWN COMPOSITION
// =====================================================
private _compCenter = [1629, 1461, 0];
private _spawnCenter = _landPos;
private _spawnDir = _dirToSea;

private _nearObjects = nearestTerrainObjects [_spawnCenter, ["TREE", "SMALL TREE", "BUSH", "ROCK", "FENCE", "WALL"], 60, false];
{
    _x hideObjectGlobal true;
} forEach _nearObjects;
diag_log format ["[NAVAL-ARTY] Cleared %1 terrain objects", count _nearObjects];

DYN_naval_hiddenTerrain = +_nearObjects;

private _fn_relToWorld = {
    private _relPos = _this;
    private _dx = (_relPos select 0) - (_compCenter select 0);
    private _dy = (_relPos select 1) - (_compCenter select 1);
    private _dz = _relPos select 2;
    private _cosD = cos _spawnDir;
    private _sinD = sin _spawnDir;
    private _wx = (_spawnCenter select 0) + (_dx * _cosD - _dy * _sinD);
    private _wy = (_spawnCenter select 1) + (_dx * _sinD + _dy * _cosD);
    [_wx, _wy, _dz]
};

private _fn_rotDir = {
    private _dirVec = _this select 0;
    private _upVec = _this select 1;
    private _cosD = cos _spawnDir;
    private _sinD = sin _spawnDir;
    private _rd = [
        (_dirVec#0)*_cosD - (_dirVec#1)*_sinD,
        (_dirVec#0)*_sinD + (_dirVec#1)*_cosD,
        _dirVec#2
    ];
    private _ru = [
        (_upVec#0)*_cosD - (_upVec#1)*_sinD,
        (_upVec#0)*_sinD + (_upVec#1)*_cosD,
        _upVec#2
    ];
    [_rd, _ru]
};

private _compObjects = [];

// =====================================================
// COMPOSITION DATA
// =====================================================
private _compositionData = [
    ["Land_CncWall4_F",[1634.37,1482.15,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1634.36,1481.29,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1624.82,1482.43,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1624.76,1481.42,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1619.69,1482.45,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1619.6,1481.49,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1639.58,1482.28,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1639.49,1481.31,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1614.47,1482.46,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1614.38,1481.5,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1609.25,1482.48,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1609.13,1481.43,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1650.01,1482.26,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1649.92,1481.3,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1644.79,1482.28,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1644.7,1481.32,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall1_F",[1630.65,1481.91,1.6538],[4.37114e-08,1.19249e-08,-1],[-1,0,-4.37114e-08],false],
    ["Land_CncWall1_F",[1628.62,1481.85,1.65717],[1.19249e-08,-4.37114e-08,-1],[1,0,1.19249e-08],false],
    ["Land_CncWall4_F",[1651.75,1463.36,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.72,1463.27,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.82,1468.58,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.78,1468.49,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.83,1479.01,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.79,1478.92,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.81,1473.79,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.78,1473.7,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.66,1442.49,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.62,1442.4,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.72,1447.71,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.69,1447.62,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.74,1458.14,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.7,1458.05,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.72,1452.92,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.68,1452.83,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.51,1463.71,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.48,1463.62,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.58,1468.93,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.54,1468.84,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.66,1479.35,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.6,1479.25,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.57,1474.14,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.54,1474.05,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.42,1442.84,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.38,1442.75,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.48,1448.06,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.45,1447.97,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.5,1458.49,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.46,1458.4,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1605.48,1453.27,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1606.44,1453.18,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1633.92,1440.2,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1634.03,1439.2,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1624.48,1440.29,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1624.39,1439.33,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1619.25,1440.31,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1619.16,1439.35,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1639.15,1440.14,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1639.06,1439.18,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1614.04,1440.32,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1613.95,1439.36,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1608.81,1440.34,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1608.72,1439.38,0],[-8.74228e-08,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1649.57,1440.13,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1649.48,1439.16,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1644.35,1440.14,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1644.26,1439.18,0],[-3.25841e-07,-1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1629.21,1439.27,0],[-0.0174524,-0.999848,0],[0,0,1],false],
    ["Land_CncWall4_F",[1629.17,1440.24,0],[0.0174526,0.999848,0],[0,0,1],false],
    ["Land_CncWall4_F",[1633.41,1479.07,0],[1,-4.37114e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1625.78,1479.32,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1633.43,1473.87,0],[1,-4.37114e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1625.81,1474.12,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1633.42,1468.7,0],[1,-4.37114e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1625.79,1468.95,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall1_F",[1632.37,1466.23,0.139454],[0.0348995,-0.999391,0],[0,0,1],false],
    ["Land_CncWall1_F",[1626.65,1466.16,0.185087],[0.0348995,-0.999391,0],[0,0,1],false],
    ["Land_CncWall1_F",[1630.67,1466.52,1.65858],[4.37114e-08,1.19249e-08,-1],[-1,0,-4.37114e-08],false],
    ["Land_CncWall1_F",[1628.63,1466.46,1.64934],[1.19249e-08,-4.37114e-08,-1],[1,0,1.19249e-08],false],
    ["Land_CncWall4_F",[1635.63,1466.76,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1635.62,1466.55,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1623.53,1466.88,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1623.52,1466.68,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1618.31,1466.88,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1618.3,1466.67,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1640.84,1466.77,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1640.83,1466.56,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1613.09,1466.89,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1613.08,1466.68,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1646.06,1466.78,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1646.05,1466.57,0],[0,1,0],[0,0,1],false],
    ["Land_CncWall4_F",[1648.21,1468.77,0],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1610.86,1474.04,0],[1,-4.37114e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1610.85,1468.86,0],[1,-4.37114e-08,0],[0,0,1],false],
    ["Land_CncWall4_F",[1651.67,1468.71,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_CncWall4_F",[1652.06,1468.84,0],[1,-4.01339e-07,0],[0,0,1],false],
    ["Land_ConcreteKerb_03_BY_long_F",[1629.63,1481.21,0],[0,1,0],[0,0,1],false],
    ["Land_ConcreteKerb_03_BY_long_F",[1629.66,1482.54,0],[0,1,0],[0,0,1],false],
    ["Land_ConcreteKerb_03_BY_long_F",[1629.64,1465.84,0],[0,1,0],[0,0,1],false],
    ["Land_ConcreteKerb_03_BY_long_F",[1629.63,1467.13,0],[0,1,0],[0,0,1],false],
    ["Land_ConcreteWall_01_l_gate_F",[1631.52,1466.38,0],[0,1,0],[0,0,1],false],
    ["Land_ConcreteWall_01_l_gate_F",[1631.58,1481.69,0],[0,1,0],[0,0,1],false],
    ["Land_ConcreteWall_01_l_gate_F",[1627.59,1481.9,0],[-8.74228e-08,-1,0],[0,0,1],false],
    ["Land_ConcreteWall_01_l_gate_F",[1627.55,1466.64,0],[1.50996e-07,-1,0],[0,0,1],false],
    ["Land_GuardHouse_02_grey_F",[1635.82,1487.31,0],[0.0174523,0.999848,0],[0,0,1],false],
    ["Land_Razorwire_F",[1624.43,1481.78,3.63618],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1616.11,1481.68,3.26792],[0.0174525,-0.999848,0],[0,0,1],false],
    ["Land_Razorwire_F",[1632.51,1481.82,3.56672],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1640.58,1481.84,3.26792],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1648.67,1481.89,3.27115],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1609.49,1481.57,3.26792],[0.0174525,-0.999848,0],[0,0,1],false],
    ["Land_Razorwire_F",[1624.34,1439.71,3.26792],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1616.02,1439.6,3.26792],[0.0174525,-0.999848,0],[0,0,1],false],
    ["Land_Razorwire_F",[1632.41,1439.74,3.26792],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1640.49,1439.77,3.26792],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1648.58,1439.81,3.27115],[0,1,0],[0,0,1],false],
    ["Land_Razorwire_F",[1609.39,1439.5,3.26792],[0.0174525,-0.999848,0],[0,0,1],false],
    ["Land_Razorwire_F",[1652.2,1458.14,3.27192],[-0.999391,0.0348993,0],[0,0,1],false],
    ["Land_Razorwire_F",[1652.02,1449.83,3.27192],[0.999848,-0.0174522,0],[0,0,1],false],
    ["Land_Razorwire_F",[1652.45,1466.21,3.27191],[-0.999391,0.0348993,0],[0,0,1],false],
    ["Land_Razorwire_F",[1652.71,1474.29,3.27191],[-0.999391,0.0348993,0],[0,0,1],false],
    ["Land_Razorwire_F",[1652.1,1477.42,3.27191],[-0.999391,0.0348993,0],[0,0,1],false],
    ["Land_Razorwire_F",[1651.89,1443.2,3.27192],[0.999848,-0.0174522,0],[0,0,1],false],
    ["Land_Razorwire_F",[1605.73,1462.89,3.26792],[0.999848,-0.0174525,0],[0,0,1],false],
    ["Land_Razorwire_F",[1605.77,1471.21,3.26792],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_Razorwire_F",[1605.63,1454.82,3.26792],[0.999848,-0.0174525,0],[0,0,1],false],
    ["Land_Razorwire_F",[1605.51,1446.74,3.26792],[0.999848,-0.0174525,0],[0,0,1],false],
    ["Land_Razorwire_F",[1605.72,1444.07,3.26792],[0.999848,-0.0174525,0],[0,0,1],false],
    ["Land_Razorwire_F",[1605.78,1477.84,3.26792],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_Cargo_HQ_V3_F",[1641.86,1474.76,0],[1.50996e-07,-1,0],[0,0,1],false],
    ["Land_Cargo_House_V3_F",[1634.51,1444.54,0],[-8.74228e-08,-1,0],[0,0,1],false],
    ["Land_Cargo_House_V3_F",[1628.03,1444.48,0],[-8.74228e-08,-1,0],[0,0,1],false],
    ["Land_Cargo_House_V3_F",[1640.95,1444.61,0],[-8.74228e-08,-1,0],[0,0,1],false],
    ["Land_Medevac_house_V1_F",[1610.65,1444.48,0],[-1,4.88762e-07,0],[0,0,1],false],
    ["Land_Cargo_Patrol_V3_F",[1647.7,1444.08,0],[-0.999848,-0.0174513,0],[0,0,1],false],
    ["Land_Cargo_Tower_V3_F",[1617.8,1473.65,0],[0,1,0],[0,0,1],false],
    ["Land_Shed_Small_F",[1610.07,1453.54,0.308861],[0,1,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.96,1466.83,0],[0,1,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.97,1468.37,0],[0,1,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.96,1469.9,0],[0,1,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.98,1471.45,0],[0,1,0],[0,0,1],false],
    ["Land_CncShelter_F",[1646.99,1477.1,0.601673],[-1,1.19249e-08,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.09,1478.33,0.220978],[0.469471,0.882948,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.08,1475.99,0.218784],[0.5,-0.866025,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.59,1474.9,0.166517],[-0.309017,0.951057,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.84,1473.65,0.0935669],[-0.104529,0.994522,0],[0,0,1],false],
    ["Land_CncShelter_F",[1649.93,1472.92,0.0469723],[-0.0174526,0.999848,0],[0,0,1],false],
    ["Land_CncShelter_F",[1648.34,1465.53,0],[-0.898794,-0.438371,0],[0,0,1],false],
    ["Land_SandbagBarricade_01_F",[1649.92,1467.36,1.64594],[0,1.19249e-08,1],[0,-1,1.19249e-08],false],
    ["Land_SandbagBarricade_01_F",[1649.94,1469.94,1.69246],[8.6163e-08,-4.22074e-08,-1],[-0.0174521,0.999848,-4.37047e-08],false],
    ["Land_SandbagBarricade_01_F",[1649.9,1472.19,1.49192],[8.6163e-08,-4.22074e-08,-1],[-0.0174521,0.999848,-4.37047e-08],false],
    ["Land_SandbagBarricade_01_F",[1649.66,1473.48,1.61203],[-8.58166e-08,2.70304e-08,1],[-0.190809,0.981627,-4.29083e-08],false],
    ["Land_SandbagBarricade_01_F",[1649.26,1475.55,1.88886],[-2.95313e-07,-1.49631e-07,-1],[0.422618,-0.906308,1.08076e-08],false],
    ["Land_SandbagBarricade_01_F",[1647.61,1477.05,2.02778],[-5.56273e-08,-8.14118e-07,-1],[0.999848,-0.0174552,-4.14082e-08],false],
    ["Land_SandbagBarricade_01_F",[1648.93,1477.8,2.17961],[2.11252e-07,-2.7833e-07,-1],[0.743145,0.669131,-2.92486e-08],false],
    ["Land_SandbagBarricade_01_F",[1650.36,1466.71,1.60861],[7.08882e-08,-1.45246e-07,-1],[-0.882948,-0.469471,5.59839e-09],false],
    ["Land_SandbagBarricade_01_F",[1650.61,1466.36,1.61567],[1.44398e-07,3.2222e-08,-1],[0.292371,-0.956305,1.14038e-08],false],
    ["Land_SandbagBarricade_01_F",[1648.95,1465.3,1.55825],[0,1.19249e-08,1],[-0.882948,-0.469472,5.59839e-09],false],
    ["Land_CncWall1_F",[1648.12,1481.08,0],[-0.987688,0.156435,0],[0,0,1],false],
    ["Land_CncWall1_F",[1648.05,1479.96,0],[-0.99863,-0.0523356,0],[0,0,1],false],
    ["Land_CncWall1_F",[1649.71,1464.57,-1.05429],[0.29237,-0.956305,0],[0,0,1],false],
    ["Land_CncWall1_F",[1650.95,1465.42,-0.846481],[0.777145,-0.629321,0],[0,0,1],false],
    ["Land_BagFence_Corner_F",[1606.21,1439.93,3.41302],[-0.0523362,-0.99863,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1614.16,1439.68,3.47815],[0,1,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1611.22,1439.7,3.47815],[0,1,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1608.29,1439.64,3.47815],[0,1,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.91,1456.06,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.74,1444.66,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.8,1447.58,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.79,1450.39,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.78,1453.3,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.7,1441.79,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_End_F",[1615.97,1439.66,3.46536],[0,1,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.91,1459.01,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.91,1461.94,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_Long_F",[1605.87,1464.85,3.50243],[1,7.54979e-08,0],[0,0,1],false],
    ["Land_BagFence_End_F",[1605.88,1466.7,3.44018],[-0.99863,0.0523366,0],[0,0,1],false],
    ["Land_SignM_WarningMilitaryVehicles_english_F",[1626.18,1482.61,0],[1.50996e-07,-1,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1626.92,1482.01,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1631.96,1483.38,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632.01,1484.61,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632.06,1486.02,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632,1487.5,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632.02,1488.92,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1627.09,1483.38,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1627.14,1484.62,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1627.19,1486.03,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1627.24,1487.5,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1627.25,1488.92,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632.08,1490.42,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632.12,1491.65,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1632.15,1492.74,0],[0.0349002,0.999391,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1641.54,1492.67,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1640.3,1492.71,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1638.89,1492.76,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1637.42,1492.81,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1636,1492.83,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1634.49,1492.78,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_Bollard_01_F",[1633.26,1492.83,0],[-0.999391,0.0349007,0],[0,0,1],true],
    ["Land_SignWarning_01_CheckpointAhead_F",[1632.86,1492.13,0],[0.258818,-0.965926,0],[0,0,1],true],
    ["Land_FieldToilet_F",[1646.86,1471.71,1.08504],[0,1,0],[0,0,1],true],
    ["Land_ToiletBox_F",[1647.98,1472.04,1.08504],[0.173648,0.984808,0],[0,0,1],true],
    ["Land_BarrelSand_F",[1642.06,1467.26,0],[0,1,0],[0,0,1],true],
    ["Land_BarrelEmpty_F",[1645.96,1467.15,0],[0,1,0],[0,0,1],true],
    ["Land_WaterBarrel_F",[1641.12,1469.67,0],[0,1,0],[0,0,1],true],
    ["Land_GarbageBarrel_02_F",[1641.76,1468.76,0],[0,1,0],[0,0,1],true],
    ["Land_GarbageBarrel_01_english_F",[1647.44,1467.24,0],[-0.694659,-0.719339,0],[0,0,1],true],
    ["Land_WoodenCrate_01_F",[1645.8,1470.36,0.60167],[0,1,0],[0,0,1],true],
    ["Land_FieldToilet_F",[1625.76,1445.78,0],[-0.0174531,-0.999848,0],[0,0,1],true],
    ["Land_GarbageContainer_open_F",[1625.32,1465.46,0],[-0.0174526,-0.999848,0],[0,0,1],true],
    ["Land_GarbageContainer_closed_F",[1623.43,1465.37,0],[0,1,0],[0,0,1],true],
    ["Land_TankTracks_01_long_F",[1615.25,1441.98,0],[0,1,0],[0,0,1],true],
    ["CargoNet_01_box_F",[1642.38,1465.13,0],[0,1,0],[0,0,1],true],
    ["CargoNet_01_barrels_F",[1639.29,1465.08,0],[0,1,0],[0,0,1],true],
    ["Land_FoodSacks_01_cargo_brown_F",[1644.07,1465.2,0],[0,1,0],[0,0,1],true],
    ["Land_Cargo10_sand_F",[1649.49,1462.57,0],[0,1,0],[0,0,1],true],
    ["Land_Cargo40_sand_F",[1649.31,1446.98,1.19929],[0.999391,-0.0348997,0],[0,0,1],true],
    ["Land_HelicopterWheels_01_assembled_F",[1651.13,1460.31,1.0916],[0,0.999929,0.0118799],[0.562644,-0.00982114,0.826641],true],
    ["Land_HelicopterWheels_01_disassembled_F",[1651.07,1459.17,1.11605],[0.825567,-0.0456571,-0.562455],[0.562644,-0.00982114,0.826641],true],
    ["Land_MobileLandingPlatform_01_F",[1649.12,1458.64,0],[-0.999848,0.0174523,0],[0,0,1],true],
    ["Land_RotorCoversBag_01_F",[1651.34,1458.07,0],[0,1,0],[0,0,1],true],
    ["Land_AirIntakePlug_04_F",[1650.36,1456.87,0],[0,1,0],[0,0,1],true],
    ["O_CargoNet_01_ammo_F",[1640.7,1465.07,0],[0,1,0],[0,0,1],true],
    ["Land_PalletTrolley_01_yellow_F",[1638.8,1464.95,1.0585],[-0.0174521,0.999848,0],[0,0,1],true],
    ["Land_PalletTrolley_01_khaki_F",[1636.08,1465.1,0],[0.999391,0.0348993,0],[0,0,1],true],
    ["Land_ToolTrolley_02_F",[1623.89,1441.77,0],[0.999391,-0.0348995,0],[0,0,1],true],
    ["Land_CanisterFuel_F",[1648.52,1457.12,0],[-0.829038,-0.559192,0],[0,0,1],true],
    ["Land_WeldingTrolley_01_F",[1615.21,1444.98,0],[0,1,0],[0,0,1],true],
    ["Land_DrillAku_F",[1622.07,1445.9,0],[0.920505,0.390731,0],[0,0,1],true],
    ["Land_ButaneTorch_F",[1616.09,1445.14,0],[0,1,0],[0,0,1],true],
    ["Land_CanisterOil_F",[1617.83,1445.97,0],[0.601815,0.798636,0],[0,0,1],true],
    ["Land_CanisterPlastic_F",[1624.54,1445.25,0],[0,1,0],[0,0,1],true],
    ["Land_MetalWire_F",[1616.34,1445.55,0],[0,1,0],[0,0,1],true],
    ["Land_GasTank_02_F",[1623.56,1445.2,0],[-0.0174526,-0.999848,0],[0,0,1],true],
    ["Land_Stretcher_01_sand_F",[1607.15,1443.28,0.72885],[0,1,0],[0,0,1],true],
    ["Box_C_UAV_06_medical_F",[1606.86,1445.19,0.72885],[0,1,0],[0,0,1],true],
    ["Land_CampingChair_V2_white_F",[1607.75,1446.51,0.72885],[0.999848,0.0174524,0],[0,0,1],true],
    ["Land_Laptop_03_sand_F",[1607.27,1446.47,2.67007],[-1,1.19249e-08,0],[0,0,1],true],
    ["Land_IPPhone_01_sand_F",[1607.19,1446.83,2.67007],[-0.999391,-0.0348993,0],[0,0,1],true],
    ["Land_TripodScreen_01_large_sand_F",[1610.14,1442.2,0.59281],[-0.681998,0.731354,0],[0,0,1],true],
    ["Land_Router_01_olive_F",[1606.77,1446.82,2.76134],[1,7.54979e-08,0],[0,0,1],true],
    ["Land_PortableCabinet_01_7drawers_olive_F",[1610.37,1446.75,0.59281],[0,1,0],[0,0,1],true],
    ["Land_PortableCabinet_01_bookcase_black_F",[1609.84,1446.83,0.59281],[0,1,0],[0,0,1],true],
    ["Land_PortableCabinet_01_4drawers_olive_F",[1609.29,1446.73,0.59281],[0,1,0],[0,0,1],true],
    ["Land_PortableDesk_01_sand_F",[1607.14,1445.77,0.72885],[-0.999391,-0.0348983,0],[0,0,1],true],
    ["Land_Computer_01_sand_F",[1607.01,1446.14,1.61578],[-0.999848,-0.0174523,0],[0,0,1],true],
    ["Land_WoodPile_large_F",[1649.9,1469.4,3.1861],[0,1,0],[0,0,1],true],
    ["Land_RepairDepot_01_tan_F",[1619.7,1444.45,0],[1,-4.01339e-07,0],[0,0,1],true],
    ["Land_GarbageBarrel_02_buried_F",[1647.49,1468.7,0],[0,1,0],[0,0,1],false],
    ["Land_CratesShabby_F",[1644.94,1469.84,0],[-0.999848,0.0174523,0],[0,0,1],false],
    ["Land_WoodenCrate_01_stack_x3_F",[1640.61,1468.28,0],[-0.994522,0.104529,0],[0,0,1],false],
    ["Land_TowBar_01_F",[1624.61,1470.53,0],[0,1,0],[0,0,1],false],
    ["Land_SewerCover_03_F",[1617.88,1474.07,0],[0,1,0],[0,0,1],false],
    ["MedicalGarbage_01_FirstAidKit_F",[1607.17,1445.65,1.62502],[0,1,0],[0,0,1],false],
    ["MedicalGarbage_01_1x1_v1_F",[1607.18,1444.92,1.61578],[0,1,0],[0,0,1],false]
];

// =====================================================
// SPAWN ALL COMPOSITION OBJECTS
// =====================================================
diag_log format ["[NAVAL-ARTY] Spawning %1 composition objects...", count _compositionData];

{
    _x params ["_class", "_origPos", "_dirVec", "_upVec", "_isSimple"];

    private _worldPos = _origPos call _fn_relToWorld;
    private _rotated = [_dirVec, _upVec] call _fn_rotDir;

    private _obj = objNull;

    if (_isSimple) then {
        _obj = createSimpleObject [_class, [0,0,0]];
        _obj setPosATL _worldPos;
        _obj setVectorDirAndUp _rotated;
        _obj enableSimulation false;
    } else {
        _obj = createVehicle [_class, _worldPos, [], 0, "CAN_COLLIDE"];
        _obj setPosATL _worldPos;
        _obj setVectorDirAndUp _rotated;
        _obj allowDamage false;
        _obj enableSimulation false;
    };

    if (!isNull _obj) then {
        _compObjects pushBack _obj;
        DYN_naval_objects pushBack _obj;
    };
} forEach _compositionData;

DYN_naval_compObjects = +_compObjects;

diag_log format ["[NAVAL-ARTY] Composition spawned: %1 objects", count _compObjects];

// =====================================================
// 4. SPAWN BM-21 TRUCKS
// =====================================================
private _artilleryVehs = [];

private _artySlots = [
    [[1637.2, 1455.73, 0], [[0,1,0],[0,0,1]]],
    [[1642.72, 1455.72, 0], [[0,1,0],[0,0,1]]]
];

private _artyCount = 1 + floor random 2;
_artySlots = _artySlots call BIS_fnc_arrayShuffle;

for "_i" from 0 to (_artyCount - 1) do {
    private _slotData = _artySlots select _i;
    private _slotPos = (_slotData select 0) call _fn_relToWorld;
    private _slotDirUp = [(_slotData select 1) select 0, (_slotData select 1) select 1] call _fn_rotDir;

    private _artyVeh = createVehicle ["CUP_O_BM21_SLA", _slotPos, [], 0, "CAN_COLLIDE"];
    _artyVeh setPosATL _slotPos;
    _artyVeh setVectorDirAndUp _slotDirUp;
    _artyVeh setFuel 0;
    _artyVeh allowDamage true;
    _artilleryVehs pushBack _artyVeh;
    DYN_naval_enemyVehs pushBack _artyVeh;
};

diag_log format ["[NAVAL-ARTY] Spawned %1 BM-21 truck(s)", count _artilleryVehs];

// =====================================================
// 5. TOWER GARRISONS
// =====================================================
private _grpBigTower = createGroup east;
DYN_naval_enemyGroups pushBack _grpBigTower;
_grpBigTower setBehaviour "COMBAT";
_grpBigTower setCombatMode "RED";

private _bigTowerWorldPos = [1617.8, 1473.65, 0] call _fn_relToWorld;

private _bigTowerObj = objNull;
{
    if (typeOf _x == "Land_Cargo_Tower_V3_F") exitWith { _bigTowerObj = _x };
} forEach _compObjects;

if (!isNull _bigTowerObj) then {
    private _towerBldgPos = _bigTowerObj buildingPos -1;
    diag_log format ["[NAVAL-ARTY] Big tower has %1 building positions", count _towerBldgPos];

    private _towerSlots = count _towerBldgPos min 4;
    for "_i" from 0 to (_towerSlots - 1) do {
        private _bPos = _towerBldgPos select _i;
        private _u = _grpBigTower createUnit [
            if (_i == 0) then {"CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"} else {selectRandom _infPool},
            _bPos, [], 0, "NONE"
        ];
        if (!isNull _u) then {
            _u setPosATL _bPos;
            _u setUnitPos "UP";
            _u allowFleeing 0;
            _u setSkill 0.55;
            _u setSkill ["aimingAccuracy", 0.50];
            _u setSkill ["spotDistance", 0.60];
            _u doWatch ([_bigTowerWorldPos, 200, _dirToSea] call DYN_fnc_posOffset);
            DYN_naval_enemies pushBack _u;
        };
    };
} else {
    diag_log "[NAVAL-ARTY] WARNING: Could not find big tower object for garrison";
};

private _grpSmallTower = createGroup east;
DYN_naval_enemyGroups pushBack _grpSmallTower;
_grpSmallTower setBehaviour "COMBAT";
_grpSmallTower setCombatMode "RED";

private _smallTowerWorldPos = [1647.7, 1444.08, 0] call _fn_relToWorld;

private _smallTowerObj = objNull;
{
    if (typeOf _x == "Land_Cargo_Patrol_V3_F") exitWith { _smallTowerObj = _x };
} forEach _compObjects;

if (!isNull _smallTowerObj) then {
    private _stBldgPos = _smallTowerObj buildingPos -1;
    diag_log format ["[NAVAL-ARTY] Small tower has %1 building positions", count _stBldgPos];

    private _stSlots = count _stBldgPos min 2;
    for "_i" from 0 to (_stSlots - 1) do {
        private _bPos = _stBldgPos select _i;
        private _u = _grpSmallTower createUnit [
            if (_i == 0) then {"CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"} else {selectRandom _infPool},
            _bPos, [], 0, "NONE"
        ];
        if (!isNull _u) then {
            _u setPosATL _bPos;
            _u setUnitPos "UP";
            _u allowFleeing 0;
            _u setSkill 0.55;
            _u setSkill ["aimingAccuracy", 0.50];
            _u setSkill ["spotDistance", 0.60];
            _u doWatch ([_smallTowerWorldPos, 200, _dirToSea] call DYN_fnc_posOffset);
            DYN_naval_enemies pushBack _u;
        };
    };
} else {
    diag_log "[NAVAL-ARTY] WARNING: Could not find small tower object for garrison";
};

// =====================================================
// 6. INTERIOR BASE SQUADS
// =====================================================
private _grpArtyGuard = createGroup east;
DYN_naval_enemyGroups pushBack _grpArtyGuard;
_grpArtyGuard setBehaviour "AWARE";
_grpArtyGuard setCombatMode "RED";

{
    private _vPos = getPosATL _x;
    for "_i" from 1 to 3 do {
        private _p = [_vPos, 2 + random 5, random 360] call DYN_fnc_posOffset;
        private _u = _grpArtyGuard createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
        if (!isNull _u) then {
            _u allowFleeing 0;
            _u setSkill 0.50;
            DYN_naval_enemies pushBack _u;
        };
    };
} forEach _artilleryVehs;

private _grpHQ = createGroup east;
DYN_naval_enemyGroups pushBack _grpHQ;
_grpHQ setBehaviour "AWARE";
_grpHQ setCombatMode "RED";

private _hqWorldPos = [1641.86, 1474.76, 0] call _fn_relToWorld;
for "_i" from 1 to 5 do {
    private _p = [_hqWorldPos, 2 + random 6, random 360] call DYN_fnc_posOffset;
    private _u = _grpHQ createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.50;
        DYN_naval_enemies pushBack _u;
    };
};

private _grpBarracks = createGroup east;
DYN_naval_enemyGroups pushBack _grpBarracks;
_grpBarracks setBehaviour "SAFE";
_grpBarracks setCombatMode "YELLOW";

private _barracksPos = [1634.51, 1444.54, 0] call _fn_relToWorld;
for "_i" from 1 to 5 do {
    private _p = [_barracksPos, 3 + random 10, random 360] call DYN_fnc_posOffset;
    private _u = _grpBarracks createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.45;
        DYN_naval_enemies pushBack _u;
    };
};

private _grpGate = createGroup east;
DYN_naval_enemyGroups pushBack _grpGate;
_grpGate setBehaviour "AWARE";
_grpGate setCombatMode "RED";

private _gateWorldPos = [1629.6, 1481.8, 0] call _fn_relToWorld;
for "_i" from 1 to 3 do {
    private _p = [_gateWorldPos, 1 + random 3, random 360] call DYN_fnc_posOffset;
    private _u = _grpGate createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u setUnitPos "MIDDLE";
        _u allowFleeing 0;
        _u setSkill 0.50;
        DYN_naval_enemies pushBack _u;
    };
};

private _grpInteriorPatrol = createGroup east;
DYN_naval_enemyGroups pushBack _grpInteriorPatrol;

for "_i" from 1 to 4 do {
    private _baseP = [1629, 1461, 0] call _fn_relToWorld;
    private _p = [_baseP, 5 + random 10, random 360] call DYN_fnc_posOffset;
    private _u = _grpInteriorPatrol createUnit [selectRandom _infPool, _p, [], 0, "FORM"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.45;
        DYN_naval_enemies pushBack _u;
    };
};

_grpInteriorPatrol setBehaviour "SAFE";
_grpInteriorPatrol setCombatMode "YELLOW";

private _interiorWPPositions = [
    [1620, 1470, 0],
    [1640, 1470, 0],
    [1645, 1450, 0],
    [1620, 1450, 0],
    [1630, 1460, 0],
    [1635, 1475, 0]
];

{
    private _wpWorldPos = _x call _fn_relToWorld;
    private _wp = _grpInteriorPatrol addWaypoint [_wpWorldPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
} forEach _interiorWPPositions;
(_grpInteriorPatrol addWaypoint [(_interiorWPPositions select 0) call _fn_relToWorld, 0]) setWaypointType "CYCLE";

private _grpMedic = createGroup east;
DYN_naval_enemyGroups pushBack _grpMedic;
_grpMedic setBehaviour "AWARE";
_grpMedic setCombatMode "RED";

private _medicPos = [1610.65, 1444.48, 0] call _fn_relToWorld;
for "_i" from 1 to 3 do {
    private _p = [_medicPos, 2 + random 5, random 360] call DYN_fnc_posOffset;
    private _u = _grpMedic createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.45;
        DYN_naval_enemies pushBack _u;
    };
};

diag_log format ["[NAVAL-ARTY] Base garrison: %1 total enemies inside", count DYN_naval_enemies];

// =====================================================
// 7. GAZ VEHICLE PATROLS
// =====================================================
private _gazCount = 1 + floor random 2;

for "_g" from 1 to _gazCount do {
    private _gazSpawnAngle = (_dirToSea + 180) + ((_g - 1) * 120) + (random 60 - 30);
    private _gazSpawnDist = 80 + random 40;
    private _gazSpawnPos = [_landPos, _gazSpawnDist, _gazSpawnAngle] call DYN_fnc_posOffset;

    if (surfaceIsWater _gazSpawnPos) then {
        _gazSpawnPos = [_landPos, 60, _gazSpawnAngle + 90] call DYN_fnc_posOffset;
    };
    if (surfaceIsWater _gazSpawnPos) then {
        _gazSpawnPos = [_landPos, 50, _dirToSea + 180] call DYN_fnc_posOffset;
    };
    if (surfaceIsWater _gazSpawnPos) then {
        _gazSpawnPos = [_landPos, 40, _dirToSea + 180] call DYN_fnc_posOffset;
    };

    if (surfaceIsWater _gazSpawnPos) then {
        diag_log format ["[NAVAL-ARTY] GAZ patrol %1 skipped - no valid land position", _g];
    } else {
        private _gazVeh = createVehicle ["CUP_O_UAZ_MG_RU", _gazSpawnPos, [], 0, "NONE"];
        _gazVeh setDir (random 360);

        { deleteVehicle _x } forEach crew _gazVeh;

        private _gazGrp = createGroup east;
        DYN_naval_enemyGroups pushBack _gazGrp;

        private _driver = _gazGrp createUnit [selectRandom _infPool, _gazSpawnPos, [], 0, "NONE"];
        _driver moveInDriver _gazVeh;
        _driver allowFleeing 0;
        _driver setSkill 0.45;
        DYN_naval_enemies pushBack _driver;

        private _gunner = _gazGrp createUnit [selectRandom _infPool, _gazSpawnPos, [], 0, "NONE"];
        _gunner moveInGunner _gazVeh;
        _gunner allowFleeing 0;
        _gunner setSkill 0.50;
        DYN_naval_enemies pushBack _gunner;

        private _passengerCount = 1 + floor random 2;
        for "_p" from 1 to _passengerCount do {
            private _passenger = _gazGrp createUnit [selectRandom _infPool, _gazSpawnPos, [], 0, "NONE"];
            _passenger moveInCargo _gazVeh;
            _passenger allowFleeing 0;
            _passenger setSkill 0.45;
            DYN_naval_enemies pushBack _passenger;
        };

        DYN_naval_enemyVehs pushBack _gazVeh;

        _gazGrp setBehaviour "SAFE";
        _gazGrp setCombatMode "YELLOW";

        private _wpOffset = (_g - 1) * 45;
        private _wpCount = 0;
        for "_w" from 1 to 8 do {
            private _wpAngle = (_w * 45) + _wpOffset;
            private _wpDist = 70 + random 50;
            private _wpPos = [_landPos, _wpDist, _wpAngle] call DYN_fnc_posOffset;

            if (surfaceIsWater _wpPos) then {
                _wpPos = [_landPos, 50, _wpAngle] call DYN_fnc_posOffset;
            };
            if (surfaceIsWater _wpPos) then {
                _wpPos = [_landPos, 40, _wpAngle + 180] call DYN_fnc_posOffset;
            };

            if !(surfaceIsWater _wpPos) then {
                private _wp = _gazGrp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "SAFE";
                _wpCount = _wpCount + 1;
            };
        };

        if (_wpCount > 0) then {
            (_gazGrp addWaypoint [_gazSpawnPos, 0]) setWaypointType "CYCLE";
        };

        diag_log format ["[NAVAL-ARTY] GAZ patrol %1 spawned at %2 with %3 waypoints", _g, _gazSpawnPos, _wpCount];
    };
};

// =====================================================
// 7b. FOOT PATROLS OUTSIDE COMPOUND
// =====================================================
for "_fp" from 1 to 2 do {
    private _fpGrp = createGroup east;
    DYN_naval_enemyGroups pushBack _fpGrp;

    private _fpAngle = (_dirToSea + 180) + ((_fp - 1) * 180) + (random 40 - 20);
    private _fpDist = 50 + random 30;
    private _fpSpawn = [_landPos, _fpDist, _fpAngle] call DYN_fnc_posOffset;

    if (surfaceIsWater _fpSpawn) then {
        _fpSpawn = [_landPos, 40, _fpAngle + 90] call DYN_fnc_posOffset;
    };
    if (surfaceIsWater _fpSpawn) then {
        _fpSpawn = [_landPos, 35, _dirToSea + 180] call DYN_fnc_posOffset;
    };

    private _fpSize = 4 + floor random 3;
    for "_i" from 1 to _fpSize do {
        private _p = [_fpSpawn, random 5, random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _p) then { _p = _fpSpawn };

        private _u = _fpGrp createUnit [selectRandom _infPool, _p, [], 0, "FORM"];
        if (!isNull _u) then {
            _u allowFleeing 0;
            _u setSkill 0.45;
            DYN_naval_enemies pushBack _u;
        };
    };

    _fpGrp setBehaviour "SAFE";
    _fpGrp setCombatMode "YELLOW";

    private _fpWpOffset = (_fp - 1) * 30;
    for "_w" from 1 to 6 do {
        private _wpAngle = (_w * 60) + _fpWpOffset;
        private _wpDist = 50 + random 40;
        private _wpPos = [_landPos, _wpDist, _wpAngle] call DYN_fnc_posOffset;

        if (surfaceIsWater _wpPos) then {
            _wpPos = [_landPos, 35, _wpAngle + 180] call DYN_fnc_posOffset;
        };

        if !(surfaceIsWater _wpPos) then {
            private _wp = _fpGrp addWaypoint [_wpPos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "SAFE";
        };
    };
    (_fpGrp addWaypoint [_fpSpawn, 0]) setWaypointType "CYCLE";

    diag_log format ["[NAVAL-ARTY] Foot patrol %1: %2 men at %3", _fp, count units _fpGrp, _fpSpawn];
};

// =====================================================
// 8. OPTIONAL PATROL BOAT
// =====================================================
if (random 1 < 0.55) then {
    private _boatSpawn = [_landPos, 100, 400, 40] call DYN_fnc_findNearbyWater;
    if !(_boatSpawn isEqualTo []) then {
        private _boat = createVehicle ["O_Boat_Armed_01_hmg_F", _boatSpawn, [], 0, "NONE"];
        _boat setDir (random 360);
        _boat setPosASL [_boatSpawn#0, _boatSpawn#1, 0];

        { deleteVehicle _x } forEach crew _boat;
        private _bGrp = createGroup east;
        DYN_naval_enemyGroups pushBack _bGrp;

        private _bDriver = _bGrp createUnit [selectRandom _infPool, _boatSpawn, [], 0, "NONE"];
        _bDriver moveInDriver _boat;
        DYN_naval_enemies pushBack _bDriver;
        _bDriver allowFleeing 0;

        private _bGunner = _bGrp createUnit [selectRandom _infPool, _boatSpawn, [], 0, "NONE"];
        _bGunner moveInGunner _boat;
        DYN_naval_enemies pushBack _bGunner;
        _bGunner allowFleeing 0;

        DYN_naval_enemyVehs pushBack _boat;

        _bGrp setBehaviour "AWARE";
        _bGrp setCombatMode "RED";
        for "_w" from 1 to 4 do {
            private _wpW = [_landPos, 120, 450, 30] call DYN_fnc_findNearbyWater;
            if !(_wpW isEqualTo []) then {
                private _wp = _bGrp addWaypoint [_wpW, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "NORMAL";
            };
        };
        (_bGrp addWaypoint [_boatSpawn, 0]) setWaypointType "CYCLE";
    };
};

// =====================================================
// 9. MARKER & TASK
// =====================================================
private _mkr = format ["naval_mkr_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _landPos];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [300, 300];
_mkr setMarkerColor "ColorRed";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
DYN_naval_markers pushBack _mkr;

private _truckWord = if (count _artilleryVehs == 1) then {"truck"} else {"trucks"};

[
    west,
    _taskId,
    [
        format ["An enemy coastal artillery battery has been identified at a fortified outpost. Intelligence confirms %1 BM-21 MLRS %2 at the location. Infiltrate the compound and destroy all artillery vehicles.", count _artilleryVehs, _truckWord],
        "Neutralize Artillery Battery",
        ""
    ],
    _landPos,
    "CREATED",
    3,
    true,
    "destroy"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_naval_tasks pushBack _taskId;

["NavalMission", [format ["Neutralize Artillery Battery - %1 BM-21 %2 detected!", count _artilleryVehs, _truckWord]]]
    remoteExecCall ["BIS_fnc_showNotification", 0];

diag_log format ["[NAVAL-ARTY] %1 BM-21(s) | %2 enemies | Pos: %3",
    count _artilleryVehs, count DYN_naval_enemies, _landPos];

// =====================================================
// 10. MONITOR COMPLETION & DELAYED CLEANUP
// =====================================================
private _localEnemies = +DYN_naval_enemies;
private _localGroups  = +DYN_naval_enemyGroups;
private _localVehs    = +DYN_naval_enemyVehs;
private _localMarkers = +DYN_naval_markers;
private _localObjects = +DYN_naval_objects;

[_taskId, _artilleryVehs, _timeout, _repReward, _compObjects, _nearObjects, _cleanupDelay,
 _localEnemies, _localGroups, _localVehs, _localMarkers, _localObjects] spawn {
    params [
        "_tid", "_objectives", "_tOut", "_rep", "_spawnedObjects", "_hiddenTerrain", "_despawnDelay",
        "_localEnemies", "_localGroups", "_localVehs", "_localMarkers", "_localObjects"
    ];
    private _startTime = diag_tickTime;

    waitUntil {
        sleep 8;
        private _alive = { !isNull _x && alive _x } count _objectives;
        private _timedOut = (diag_tickTime - _startTime) > _tOut;
        (_alive == 0) || _timedOut
    };

    private _alive = { !isNull _x && alive _x } count _objectives;

    if (_alive == 0) then {
        [_tid, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalComplete", ["All BM-21 artillery vehicles destroyed!"]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        [_rep, "Coastal Artillery Destroyed"] call DYN_fnc_changeReputation;
        diag_log format ["[NAVAL-ARTY] SUCCESS. +%1 rep.", _rep];
    } else {
        [_tid, "FAILED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalFailed", ["Coastal artillery mission expired."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[NAVAL-ARTY] TIMED OUT.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_naval_markers = DYN_naval_markers - _localMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_naval_active = false;

    diag_log format ["[NAVAL-ARTY] Mission area will be cleaned up in %1 minutes", floor (_despawnDelay / 60)];

    sleep _despawnDelay;

    diag_log format ["[NAVAL-ARTY] Starting full cleanup of %1 composition objects", count _spawnedObjects];

    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            deleteVehicle _x;
        };
    } forEach _localVehs;

    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;

    { if (!isNull _x) then { deleteGroup _x } } forEach _localGroups;

    {
        if (!isNull _x) then {
            _x enableSimulation true;
            _x allowDamage true;
            deleteVehicle _x;
        };
    } forEach _spawnedObjects;

    sleep 2;

    {
        if (!isNull _x) then {
            _x hideObjectGlobal false;
        };
    } forEach _hiddenTerrain;
    diag_log format ["[NAVAL-ARTY] Restored %1 terrain objects", count _hiddenTerrain];

    // Surgical cleanup of global arrays
    DYN_naval_enemies     = DYN_naval_enemies     - _localEnemies;
    DYN_naval_enemyGroups = DYN_naval_enemyGroups  - _localGroups;
    DYN_naval_enemyVehs   = DYN_naval_enemyVehs   - _localVehs;
    DYN_naval_objects     = DYN_naval_objects      - _localObjects;

    diag_log "[NAVAL-ARTY] Full cleanup complete";
};
