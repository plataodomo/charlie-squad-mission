/*
    scripts\naval\fn_coastalOutpost.sqf
    NAVAL MISSION: Clear Coastal Outpost
    Uses exported composition from Eden (coastalOutpost)
    Performance: enableSimulation false on all decorative objects
    Terrain: clears trees/bushes before spawning
    
    FIXES APPLIED:
    - All getPos on position arrays replaced with DYN_fnc_posOffset
    - Surgical cleanup of global arrays instead of wiping
    - Hidden terrain tracked via DYN_naval_hiddenTerrain
    - Task deleted during cleanup
    - Vehicle spawn: damage disabled during settle, elevated spawn prevents explosions
*/
if (!isServer) exitWith {};

diag_log "[NAVAL-OUTPOST] Setting up Coastal Outpost mission...";

// =====================================================
// 1. FIND POSITION
// =====================================================
private _waterPos = [2500, 2000] call DYN_fnc_findNavalWaterPos;

if (_waterPos isEqualTo []) exitWith {
    diag_log "[NAVAL-OUTPOST] Could not find water position. Aborting.";
    DYN_naval_active = false;
};

private _landPos = [_waterPos, 600, 80] call DYN_fnc_findCoastalLandPos;

if (_landPos isEqualTo []) exitWith {
    diag_log "[NAVAL-OUTPOST] Could not find coastal land position. Aborting.";
    DYN_naval_active = false;
};

diag_log format ["[NAVAL-OUTPOST] Land pos: %1 (water ref: %2)", _landPos, _waterPos];

// =====================================================
// 2. SETTINGS
// =====================================================
private _timeout    = 7200; // 2 hours
private _repReward  = 8 + floor random 8;
private _cleanupDelay = 600;

private _infPool = [
    "CUP_O_RU_Soldier_SL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AA_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AT_Ratnik_Autumn"
];

// =====================================================
// 3. CLEAR TERRAIN & COMPOSITION HELPERS
// =====================================================
private _dirToSea = [_landPos] call DYN_fnc_dirToWater;
private _compCenter = [1937, 2716, 0];
private _rot = _dirToSea;

// Clear trees, bushes, rocks
private _clearedObjects = [_landPos, 45] call DYN_fnc_clearCompositionArea;

{
    DYN_naval_objects pushBack _x;
} forEach _clearedObjects;

diag_log format ["[NAVAL-OUTPOST] Cleared %1 terrain objects at %2", count _clearedObjects, _landPos];

// Store hidden terrain globally for cleanup
DYN_naval_hiddenTerrain = +_clearedObjects;

// Transform original VR position to world position relative to _landPos, rotated by _rot
private _fn_compPos = {
    params ["_origWorldPos", "_center", "_basePos", "_rotDeg"];
    private _dx = (_origWorldPos select 0) - (_center select 0);
    private _dy = (_origWorldPos select 1) - (_center select 1);
    private _rx = _dx * cos(_rotDeg) - _dy * sin(_rotDeg);
    private _ry = _dx * sin(_rotDeg) + _dy * cos(_rotDeg);
    [(_basePos select 0) + _rx, (_basePos select 1) + _ry, 0]
};

// Rotate direction and up vectors
private _fn_rotDirUp = {
    params ["_dirVec", "_upVec", "_rotDeg"];
    private _cd = cos _rotDeg;
    private _sd = sin _rotDeg;
    private _newDir = [
        (_dirVec select 0) * _cd - (_dirVec select 1) * _sd,
        (_dirVec select 0) * _sd + (_dirVec select 1) * _cd,
        _dirVec select 2
    ];
    private _newUp = [
        (_upVec select 0) * _cd - (_upVec select 1) * _sd,
        (_upVec select 0) * _sd + (_upVec select 1) * _cd,
        _upVec select 2
    ];
    [_newDir, _newUp]
};

// Spawn a composition object with terrain snapping (for STATIC/DECORATIVE objects only)
private _fn_spawnCompObj = {
    params ["_class", "_origPos", "_dirVec", "_upVec", ["_simEnabled", true]];
    private _pos = [_origPos, _compCenter, _landPos, _rot] call _fn_compPos;
    if (surfaceIsWater _pos) exitWith { objNull };
    private _obj = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
    private _rotVecs = [_dirVec, _upVec, _rot] call _fn_rotDirUp;
    _obj setVectorDirAndUp _rotVecs;
    
    private _posATL = getPosATL _obj;
    _obj setPosATL [_posATL select 0, _posATL select 1, 0];
    
    if (!_simEnabled) then {
        _obj enableSimulationGlobal false;
    };
    _obj
};

// Spawn a VEHICLE safely — elevated with damage disabled to prevent physics explosions
private _fn_spawnCompVeh = {
    params ["_class", "_origPos", "_dirVec", "_upVec"];
    private _pos = [_origPos, _compCenter, _landPos, _rot] call _fn_compPos;
    if (surfaceIsWater _pos) exitWith { objNull };

    // Spawn with NONE — engine finds nearby safe position
    private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
    if (isNull _veh) exitWith { objNull };

    // Disable damage immediately so physics settling doesn't blow it up
    _veh allowDamage false;
    _veh setDamage 0;

    // Set rotation
    private _rotVecs = [_dirVec, _upVec, _rot] call _fn_rotDirUp;
    _veh setVectorDirAndUp _rotVecs;

    // Place at correct position, slightly above terrain to avoid clipping
    _veh setPosATL [_pos select 0, _pos select 1, 0.3];

    // Kill any velocity from spawn
    _veh setVelocity [0, 0, 0];

    // Re-enable damage after vehicle has settled
    [_veh] spawn {
        params ["_v"];
        sleep 5;
        if (!isNull _v && alive _v) then {
            _v setVelocity [0, 0, 0];
            _v allowDamage true;
        };
    };

    _veh
};

// Master list of all composition objects for cleanup
private _compObjects = [];

// =====================================================
// 4. SPAWN COMPOSITION
// =====================================================
diag_log "[NAVAL-OUTPOST] Spawning composition...";

private _compositionHMG = objNull;

// -------------------------------------------------------
// 4A. DECORATIVE OBJECTS (simulation DISABLED)
// -------------------------------------------------------
private _decoDefs = [
    // Cargo houses
    ["Land_Cargo_House_V3_F", [1928.45,2705.54], [0.0118595,-0.99993,0], [0,0,1]],
    ["Land_Cargo_House_V3_F", [1947.29,2724.79], [0.656729,0.754127,0], [0,0,1]],

    // Desks
    ["Land_PortableDesk_01_sand_F", [1930.13,2706.94], [0,1,0], [0,0,1]],
    ["Land_PortableDesk_01_sand_F", [1931.01,2708.54], [0.999962,0.00876006,0], [0,0,1]],

    // Electronics / comms
    ["Land_Laptop_device_F", [1929.8,2707.04], [0,1,0], [0,0,1]],
    ["Land_PortableSolarPanel_01_folded_sand_F", [1929.76,2706.75], [-0.00299627,0.999996,0], [0,0,1]],
    ["Land_PortableLongRangeRadio_F", [1930.13,2707.09], [-0.046314,-0.998927,0], [0,0,1]],
    ["Land_PortableSpeakers_01_F", [1930.07,2706.99], [0.0674964,-0.99772,0], [0,0,1]],
    ["PowerCable_01_Roll_F", [1930.99,2707.8], [0,1,0], [0,0,1]],
    ["Land_IPPhone_01_sand_F", [1930.32,2707.02], [0.0142757,-0.999898,0], [0,0,1]],
    ["Land_TripodScreen_01_dual_v1_sand_F", [1931.86,2708.04], [-0.990752,0.135689,0], [0,0,1]],
    ["Land_Laptop_03_sand_F", [1931.07,2707.71], [0.997764,-0.0668389,0], [0,0,1]],
    ["Land_Computer_01_sand_F", [1931.07,2707.37], [0.999567,-0.0294206,0], [0,0,1]],
    ["Land_BatteryPack_01_open_sand_F", [1930.87,2706.98], [-0.63601,0.771681,0], [0,0,1]],
    ["Land_TripodScreen_01_large_sand_F", [1930.25,2706.06], [0,1,0], [0,0,1]],
    ["Land_Tablet_02_sand_F", [1929.41,2707.15], [0,1,0], [0,0,1]],
    ["Land_Router_01_sand_F", [1929.05,2707.13], [0.0175118,-0.999847,0], [0,0,1]],
    ["Land_PortableServer_01_black_F", [1929.43,2706.83], [0.0135264,-0.999909,0], [0,0,1]],
    ["Land_PortableServer_01_black_F", [1929.44,2706.78], [0.0351325,-0.999383,0], [0,0,1]],
    ["Land_PortableServer_01_cover_sand_F", [1931.07,2706.57], [-0.999065,-0.0432442,0], [0,0,1]],
    ["Land_BatteryPack_01_closed_sand_F", [1930.98,2707.12], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_closed_sand_F", [1930.99,2707.12], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.06,2706.75], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.07,2706.88], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.2,2706.74], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.19,2706.86], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.3,2706.87], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.32,2706.73], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.4,2706.73], [0,1,0], [0,0,1]],
    ["Land_BatteryPack_01_battery_sand_F", [1929.4,2706.87], [0,1,0], [0,0,1]],

    // Medical props
    ["Land_Bandage_F", [1931.17,2708.45], [0,1,0], [0,0,1]],
    ["Land_Bandage_F", [1931.16,2708.36], [0,1,0], [0,0,1]],
    ["Land_PainKillers_F", [1930.89,2708.7], [0,1,0], [0,0,1]],
    ["Land_PainKillers_F", [1930.86,2708.55], [0,1,0], [0,0,1]],
    ["Land_IntravenBag_01_full_F", [1930.83,2708.34], [0,1,0], [0,0,1]],
    ["Land_IntravenBag_01_full_F", [1931.12,2708.7], [0,1,0], [0,0,1]],
    ["Land_IntravenBag_01_empty_F", [1931,2708.32], [0,1,0], [0,0,1]],
    ["Land_PlasticCase_01_medium_black_CBRN_F", [1930.96,2709.36], [0,1,0], [0,0,1]],

    // Fuel cans (decorative)
    ["Land_CanisterFuel_Red_F", [1930.91,2709.54], [0,1,0], [0,0,1]],
    ["Land_CanisterFuel_Red_F", [1930.89,2709.36], [0,1,0], [0,0,1]],
    ["Land_CanisterFuel_Red_F", [1930.88,2709.16], [0,1,0], [0,0,1]],
    ["Land_CanisterFuel_Red_F", [1921.29,2725.36], [0,1,0], [0,0,1]],
    ["Land_CanisterFuel_Red_F", [1921.28,2725.19], [0,1,0], [0,0,1]],
    ["Land_CanisterFuel_Red_F", [1921.3,2725.53], [0,1,0], [0,0,1]],

    // Chairs
    ["Land_CampingChair_V2_F", [1929.55,2707.84], [0.0129169,0.999917,0], [0,0,1]],
    ["Land_CampingChair_V2_F", [1930.08,2708.99], [-0.998658,0.0517909,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1924.75,2719.55], [0.133818,-0.991006,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1928.28,2721.9], [0.888012,-0.459821,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1926.18,2719.61], [0.486916,-0.873449,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1927.27,2720.24], [0.517526,-0.855667,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1927.84,2720.98], [0.920557,-0.390609,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1925.88,2718.23], [-0.126514,-0.991965,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1928.06,2719.04], [0.554133,-0.832428,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1929.01,2720], [0.85892,-0.512111,0], [0,0,1]],
    ["Land_CampingChair_V2_white_F", [1927.09,2718.57], [0.384046,-0.923314,0], [0,0,1]],

    // Bookcase
    ["Land_PortableCabinet_01_bookcase_sand_F", [1930.95,2709.93], [0.0439258,-0.999035,0], [0,0,1]],

    // Air conditioners
    ["Land_AirConditioner_04_F", [1925.59,2707.59], [-0.806857,0.590747,0], [0,0,1]],
    ["Land_AirConditioner_04_F", [1949.12,2720.59], [0.427976,-0.90379,0], [0,0,1]],

    // Satellite antenna
    ["SatelliteAntenna_01_Mounted_Sand_F", [1945.46,2728.02], [-0.756192,0.65435,0], [0,0,1]],

    // Map board
    ["MapBoard_altis_F", [1925.41,2722.45], [-0.663155,0.748482,0], [0,0,1]],

    // Misc props
    ["Land_Pipes_large_F", [1921.96,2727.2], [-0.72629,-0.687388,0], [0,0,1]],
    ["Land_Pallet_F", [1920.74,2725.82], [0,1,0], [0,0,1]],
    ["Land_PortableCabinet_01_closed_black_F", [1921.11,2726.3], [0,1,0], [0,0,1]],
    ["Land_Axe_F", [1920.4,2725.47], [0.540373,0.841426,0], [0,0,1]],
    ["Land_Bucket_clean_F", [1920.74,2725.86], [0,1,0], [0,0,1]],
    ["Land_GasTank_02_F", [1922.05,2725.71], [0,1,0], [0,0,1]],
    ["Land_Rope_01_F", [1921.02,2726.42], [0,1,0], [0,0,1]],
    ["Land_WaterTank_F", [1924.09,2716.62], [0.0124516,0.999922,0], [0,0,1]],
    ["Land_WoodenCrate_01_stack_x5_F", [1920.26,2715.86], [0,1,0], [0,0,1]],

    // Wood piles / logs
    ["Land_WoodPile_large_F", [1947.02,2730.95], [0.536725,0.843757,0], [0,0,1]],
    ["Land_WoodPile_F", [1944.44,2731.39], [0,1,0], [0,0,1]],
    ["Land_WoodPile_F", [1945.12,2731.46], [0,1,0], [0,0,1]],
    ["Land_WoodenLog_F", [1946.07,2731.81], [0,1,0], [0,0,1]],
    ["Land_WoodenLog_F", [1946.8,2732.3], [0,0.73249,0.680778], [-0.0869495,-0.678199,0.729716]],
    ["Land_WoodenLog_F", [1945.97,2731.22], [0,1,0], [0,0,1]],
    ["Land_WoodPile_large_F", [1945.05,2733.38], [-0.999988,0.00497912,0], [0,0,1]],

    // Paper boxes / pallet / coffin
    ["Land_PaperBox_closed_F", [1953.01,2718.79], [0,1,0], [0,0,1]],
    ["Land_PaperBox_closed_F", [1948.32,2728.56], [0.759899,-0.650041,0], [0,0,1]],
    ["Land_Pallet_MilBoxes_F", [1952.58,2717.09], [0.594112,0.804382,0], [0,0,1]],
    ["Land_Pallet_MilBoxes_F", [1946.77,2726.93], [0.728718,-0.684814,0], [0,0,1]],
    ["Land_PlasticCase_01_large_black_CBRN_F", [1951.69,2719.56], [0,1,0], [0,0,1]],
    ["Land_PaperBox_open_empty_F", [1927.95,2729.88], [0,1,0], [0,0,1]],
    ["Coffin_02_F", [1949.53,2726.93], [-0.988741,0.149634,0], [0,0,1]],

    // Metal barrels
    ["Land_MetalBarrel_F", [1951.43,2723.9], [0,1,0], [0,0,1]],
    ["Land_MetalBarrel_F", [1951.96,2723.28], [0,1,0], [0,0,1]],
    ["Land_MetalBarrel_F", [1950.87,2722.89], [0,1,0], [0,0,1]],
    ["Land_MetalBarrel_F", [1951.6,2722.66], [0,1,0], [0,0,1]],
    ["Land_MetalBarrel_F", [1951.11,2722.09], [0,1,0], [0,0,1]],

    // Refueling hoses / tank parts
    ["Land_RefuelingHose_01_F", [1951.56,2718.28], [0,1,0], [0,0,1]],
    ["Land_TankSprocketWheels_01_single_F", [1951.22,2717.28], [0,1,0], [0,0,1]],
    ["Land_RefuelingHose_01_F", [1929.56,2730.65], [0,1,0], [0,0,1]],
    ["Land_TankTracks_01_long_F", [1930.86,2731.16], [-0.285296,-0.95844,0], [0,0,1]],
    ["Land_TankSprocketWheels_01_single_F", [1930.57,2732.07], [0,1,0], [0,0,1]],
    ["Land_TankRoadWheels_01_single_F", [1930.26,2731.29], [0,1,0], [0,0,1]],
    ["Land_TankTracks_01_short_F", [1929.79,2731.9], [-0.456677,-0.889633,0], [0,0,1]],

    // Planks / net fence poles
    ["Land_Plank_01_4m_F", [1950.07,2710.49], [0,1,0], [0,0,1]],
    ["Land_Plank_01_4m_F", [1949.33,2710.47], [0,1,0], [0,0,1]],
    ["Land_NetFence_03_m_pole_F", [1949.41,2712.31], [0,1,0], [0,0,1]],
    ["Land_NetFence_03_m_pole_F", [1949.26,2708.49], [0.0135884,-0.999908,0], [0,0,1]],

    // H-Barriers
    ["Land_HBarrier_3_F", [1952.96,2714.12], [0.999456,0.0329672,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1953.22,2721.31], [0.999568,-0.0294019,0], [0,0,1]],
    ["Land_HBarrier_1_F", [1953.14,2726.97], [0.98807,0.154006,0], [0,0,1]],
    ["Land_HBarrier_5_F", [1950.53,2729.39], [-0.55316,-0.833075,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1942.09,2731.18], [0,1,0], [0,0,1]],
    ["Land_HBarrier_5_F", [1934.59,2731.64], [0,1,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1927.24,2731.53], [0,1,0], [0,0,1]],
    ["Land_HBarrier_5_F", [1924.16,2729.76], [0.710601,-0.703596,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1920.99,2720.67], [0.99824,-0.0593117,0], [0,0,1]],
    ["Land_HBarrier_1_F", [1920.52,2717.3], [0.996904,-0.0786275,0], [0,0,1]],
    ["Land_HBarrier_5_F", [1920.6,2711.97], [-0.99979,-0.0205078,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1920.69,2704], [-0.999849,0.0173794,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1921.48,2701.66], [-0.501859,-0.86495,0], [0,0,1]],
    ["Land_HBarrier_5_F", [1928.48,2700.45], [0,1,0], [0,0,1]],
    ["Land_HBarrier_5_F", [1936.86,2700.46], [0,1,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1941.25,2700.42], [0,1,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1943.48,2700.43], [0,1,0], [0,0,1]],
    ["Land_HBarrier_3_F", [1948.77,2700.22], [0,1,0], [0,0,1]],
    ["Land_HBarrier_1_F", [1953.18,2700.16], [0,1,0], [0,0,1]],

    // Sandbags
    ["Land_SandbagBarricade_01_half_F", [1939.57,2731.54], [0,1,0], [0,0,1]],
    ["Land_SandbagBarricade_01_half_F", [1938.04,2731.54], [0,1,0], [0,0,1]],

    // Bag fences / bunker
    ["Land_BagFence_End_F", [1953.98,2712.43], [0.860426,0.509575,0], [0,0,1]],
    ["Land_BagBunker_Small_F", [1951.79,2710.44], [-0.998844,0.0480634,0], [0,0,1]],
    ["Land_BagFence_Long_F", [1949.63,2708.3], [0,1,0], [0,0,1]],
    ["Land_BagFence_Round_F", [1947.59,2708.92], [0.733698,0.679475,0], [0,0,1]],
    ["Land_BagFence_Long_F", [1947.09,2711.35], [-0.999164,0.0408803,0], [0,0,1]],
    ["Land_BagFence_Short_F", [1949.89,2712.2], [0,1,0], [0,0,1]],

    // Concrete barriers
    ["Land_CncBarrier_stripes_F", [1930.39,2727.08], [-0.999229,0.0392489,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1930.27,2723.64], [-0.999875,0.0158332,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1930.27,2720.67], [-0.999363,-0.0356913,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1931.44,2729.74], [-0.793716,0.608288,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1954.13,2710.03], [0.983075,-0.183204,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1954.24,2712.33], [0.994835,0.101506,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1952.66,2708.09], [0,1,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1954.07,2709.29], [0.994003,-0.109355,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1951.61,2708.09], [0,1,0], [0,0,1]],
    ["Land_CncBarrier_stripes_F", [1951.78,2712.51], [0,1,0], [0,0,1]],
    ["Land_CncBarrier_F", [1920.51,2707.83], [-0.998798,0.0490164,0], [0,0,1]],
    ["Land_CncBarrier_F", [1920.37,2705.27], [-0.997239,0.0742657,0], [0,0,1]],
    ["Land_CncBarrier_F", [1945.38,2727.8], [-0.745942,0.666011,0], [0,0,1]],
    ["Land_CncBarrier_F", [1945.59,2725.18], [-0.672532,-0.740068,0], [0,0,1]],

    // Czech hedgehogs
    ["Land_CzechHedgehog_01_old_F", [1953.14,2724.74], [0,1,0], [0,0,1]],
    ["Land_CzechHedgehog_01_old_F", [1951.57,2700.26], [0,1,0], [0,0,1]],
    ["Land_CzechHedgehog_01_old_F", [1946.06,2700.23], [0,1,0], [0,0,1]],
    ["Land_CzechHedgehog_01_old_F", [1956.3,2713.53], [0,1,0], [0,0,1]],
    ["Land_CzechHedgehog_01_old_F", [1954.82,2700.16], [0,1,0], [0,0,1]],
    ["Land_CzechHedgehog_01_old_F", [1918.16,2718.58], [0,1,0], [0,0,1]],
    ["Land_CzechHedgehog_01_old_F", [1924.26,2698.76], [0,1,0], [0,0,1]]
];

{
    _x params ["_class", "_origPos", "_dirVec", "_upVec"];
    private _obj = [_class, _origPos, _dirVec, _upVec, false] call _fn_spawnCompObj;
    if (!isNull _obj) then {
        _compObjects pushBack _obj;
        DYN_naval_objects pushBack _obj;
    };
} forEach _decoDefs;

diag_log format ["[NAVAL-OUTPOST] %1 decorative objects spawned (sim disabled)", count _decoDefs];

// -------------------------------------------------------
// 4B. INTERACTIVE OBJECTS (simulation ENABLED)
// -------------------------------------------------------
private _interactiveDefs = [
    ["Box_CSAT_Equip_F", [1921.46,2722.78], [-0.996416,0.0845927,0], [0,0,1]],
    ["Box_East_Wps_F", [1921.43,2723.45], [-0.0270837,-0.999633,0], [0,0,1]],
    ["Box_East_Ammo_F", [1920.47,2722.91], [0,1,0], [0,0,1]],
    ["Box_T_East_Ammo_F", [1922.23,2722.03], [0,1,0], [0,0,1]],
    ["O_supplyCrate_F", [1937.85,2730], [-0.747707,-0.664029,0], [0,0,1]],
    ["Box_East_AmmoOrd_F", [1937.16,2729.34], [0.638689,-0.769465,0], [0,0,1]],
    ["Box_East_Ammo_F", [1938.55,2729.29], [-0.689298,-0.724478,0], [0,0,1]],
    ["Box_T_East_Ammo_F", [1938.69,2730.3], [0.687752,-0.725945,0], [0,0,1]],
    ["Box_East_AmmoVeh_F", [1935.46,2729.87], [0,1,0], [0,0,1]],
    ["Box_East_Support_F", [1923.49,2701.86], [-0.663948,0.747779,0], [0,0,1]],
    ["O_supplyCrate_F", [1924.35,2700.63], [0,1,0], [0,0,1]],
    ["Box_East_Support_F", [1925.28,2701.83], [0,1,0], [0,0,1]],
    ["Box_CSAT_Uniforms_F", [1922.58,2702.54], [-0.878899,0.477008,0], [0,0,1]],
    ["Box_East_WpsSpecial_F", [1924.53,2702.23], [-0.858671,0.512527,0], [0,0,1]],
    ["Box_CSAT_Uniforms_F", [1923.72,2702.97], [0,1,0], [0,0,1]],
    ["Box_T_East_WpsSpecial_F", [1925.11,2704.06], [0.998052,0.0623886,0], [0,0,1]],
    ["Box_East_WpsLaunch_F", [1924.4,2704.07], [-0.99975,-0.0223604,0], [0,0,1]],
    ["O_CargoNet_01_ammo_F", [1922.63,2704.56], [0,1,0], [0,0,1]],

    // Flexible fuel tanks (ACE refuel)
    ["FlexibleTank_01_sand_F", [1923.73,2727.26], [0,1,0], [0,0,1]],
    ["FlexibleTank_01_sand_F", [1924.28,2727.61], [0,1,0], [0,0,1]],
    ["FlexibleTank_01_sand_F", [1924.4,2726.87], [0,1,0], [0,0,1]],
    ["FlexibleTank_01_sand_F", [1924.79,2728.18], [0,1,0], [0,0,1]],
    ["FlexibleTank_01_sand_F", [1925.36,2727.83], [0,1,0], [0,0,1]],
    ["FlexibleTank_01_sand_F", [1924.95,2727.2], [0,1,0], [0,0,1]],
    ["FlexibleTank_01_sand_F", [1925.21,2728.7], [0,1,0], [0,0,1]],

    // Repair depot
    ["Land_RepairDepot_01_tan_F", [1924.28,2712.34], [-0.00345572,-0.999994,0], [0,0,1]]
];

{
    _x params ["_class", "_origPos", "_dirVec", "_upVec"];
    private _obj = [_class, _origPos, _dirVec, _upVec, true] call _fn_spawnCompObj;
    if (!isNull _obj) then {
        _compObjects pushBack _obj;
        DYN_naval_objects pushBack _obj;
    };
} forEach _interactiveDefs;

diag_log format ["[NAVAL-OUTPOST] %1 interactive objects spawned (sim enabled)", count _interactiveDefs];

// -------------------------------------------------------
// 4C. VEHICLES (safe spawn — damage disabled during settle)
// -------------------------------------------------------
private _vehDefs = [
    ["CUP_O_Tigr_M_233114_KORD_CSAT_T", [1934.9,2704.65], [0,1,0], [0,0,1]],
    ["CUP_O_Tigr_M_233114_PK_CSAT_T", [1938.87,2704.25], [0.51188,0.859057,0], [0,0,1]],
    ["O_T_Truck_03_transport_ghex_F", [1941.4,2723.95], [-0.0273638,-0.999626,0], [0,0,1]],
    ["O_T_Truck_03_covered_ghex_F", [1934.08,2723.18], [-0.0189084,-0.999821,0], [0,0,1]]
];

{
    _x params ["_class", "_origPos", "_dirVec", "_upVec"];
    private _obj = [_class, _origPos, _dirVec, _upVec] call _fn_spawnCompVeh;
    if (!isNull _obj) then {
        { deleteVehicle _x } forEach crew _obj;
        _compObjects pushBack _obj;
        DYN_naval_objects pushBack _obj;
        DYN_naval_enemyVehs pushBack _obj;
    };
} forEach _vehDefs;

// -------------------------------------------------------
// 4D. HMG STATIC WEAPON (simulation ENABLED)
// -------------------------------------------------------
private _hmgObj = ["O_HMG_01_high_F", [1952.3,2710.09], [0.995182,-0.0980475,0], [0,0,1], true] call _fn_spawnCompObj;
if (!isNull _hmgObj) then {
    { deleteVehicle _x } forEach crew _hmgObj;
    _compositionHMG = _hmgObj;
    _compObjects pushBack _hmgObj;
    DYN_naval_objects pushBack _hmgObj;
    DYN_naval_enemyVehs pushBack _hmgObj;
};

// Store composition objects globally for cleanup
DYN_naval_compObjects = +_compObjects;

diag_log format ["[NAVAL-OUTPOST] Composition complete at %1, rotation %2 (%3 tracked objects)", _landPos, _rot, count _compObjects];

// =====================================================
// 5. SPAWN INFANTRY (increased enemy count)
// =====================================================
private _taskId = format ["naval_outpost_%1", round (diag_tickTime * 1000)];
private _enemyCount = 16 + floor random 9; // 16-24 enemies

// --- Garrison group (inside outpost) ---
private _grpGarrison = createGroup east;
DYN_naval_enemyGroups pushBack _grpGarrison;
_grpGarrison setBehaviour "AWARE";
_grpGarrison setCombatMode "RED";

for "_i" from 1 to (ceil (_enemyCount * 0.4)) do {
    private _p = [_landPos, random 15, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _p) then { _p = _landPos };

    private _u = _grpGarrison createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u setUnitPos (selectRandom ["UP", "MIDDLE"]);
        _u allowFleeing 0;
        _u setSkill 0.45;
        DYN_naval_enemies pushBack _u;
    };
};

// --- Inner patrol group (close to outpost) ---
private _grpInnerPatrol = createGroup east;
DYN_naval_enemyGroups pushBack _grpInnerPatrol;

for "_i" from 1 to (ceil (_enemyCount * 0.25)) do {
    private _p = [_landPos, 10 + random 15, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _p) then { _p = _landPos };

    private _u = _grpInnerPatrol createUnit [selectRandom _infPool, _p, [], 0, "FORM"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.50;
        DYN_naval_enemies pushBack _u;
    };
};

_grpInnerPatrol setBehaviour "SAFE";
_grpInnerPatrol setCombatMode "YELLOW";

for "_w" from 1 to 4 do {
    private _wpPos = [_landPos, 15 + random 20, _w * 90] call DYN_fnc_posOffset;
    if (surfaceIsWater _wpPos) then {
        _wpPos = [_landPos, 10, (_w * 90) + 180] call DYN_fnc_posOffset;
    };
    private _wp = _grpInnerPatrol addWaypoint [_wpPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
};
(_grpInnerPatrol addWaypoint [_landPos, 0]) setWaypointType "CYCLE";

// --- Outer patrol group (perimeter) ---
private _grpOuterPatrol = createGroup east;
DYN_naval_enemyGroups pushBack _grpOuterPatrol;

for "_i" from 1 to (ceil (_enemyCount * 0.2)) do {
    private _p = [_landPos, 25 + random 30, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _p) then {
        _p = [_landPos, 10, _dirToSea + 180] call DYN_fnc_posOffset;
    };

    private _u = _grpOuterPatrol createUnit [selectRandom _infPool, _p, [], 0, "FORM"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.45;
        DYN_naval_enemies pushBack _u;
    };
};

_grpOuterPatrol setBehaviour "SAFE";
_grpOuterPatrol setCombatMode "YELLOW";

for "_w" from 1 to 6 do {
    private _wpPos = [_landPos, 35 + random 50, _w * 60] call DYN_fnc_posOffset;
    if (surfaceIsWater _wpPos) then {
        _wpPos = [_landPos, 20, (_w * 60) + 180] call DYN_fnc_posOffset;
    };
    private _wp = _grpOuterPatrol addWaypoint [_wpPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
};
(_grpOuterPatrol addWaypoint [_landPos, 0]) setWaypointType "CYCLE";

// --- Sentry team (watching the sea approach) ---
private _grpSentry = createGroup east;
DYN_naval_enemyGroups pushBack _grpSentry;
_grpSentry setBehaviour "AWARE";
_grpSentry setCombatMode "RED";

for "_i" from 1 to (floor (_enemyCount * 0.15)) do {
    private _p = [_landPos, 8 + random 10, _dirToSea + (-30 + random 60)] call DYN_fnc_posOffset;
    if (surfaceIsWater _p) then {
        _p = [_landPos, 5, _dirToSea + 180] call DYN_fnc_posOffset;
    };

    private _u = _grpSentry createUnit [selectRandom _infPool, _p, [], 0, "NONE"];
    if (!isNull _u) then {
        _u setUnitPos "MIDDLE";
        _u setDir _dirToSea;
        _u allowFleeing 0;
        _u setSkill 0.50;
        _u setSkill ["spotDistance", 0.60];
        DYN_naval_enemies pushBack _u;
    };
};

// ---- Crew the composition HMG ----
if (!isNull _compositionHMG) then {
    private _hmgGrp = createGroup east;
    DYN_naval_enemyGroups pushBack _hmgGrp;
    private _hmgGunner = _hmgGrp createUnit [selectRandom _infPool, getPos _compositionHMG, [], 0, "NONE"];
    _hmgGunner moveInGunner _compositionHMG;
    _hmgGunner allowFleeing 0;
    _hmgGunner setSkill 0.55;
    DYN_naval_enemies pushBack _hmgGunner;
};

// ---- Crew the Tigr vehicles ----
// Wait for vehicles to settle before crewing (damage re-enabled after 5s in _fn_spawnCompVeh)
sleep 6;

{
    if (!isNull _x && {_x isKindOf "Car"}) then {
        private _vGrp = createGroup east;
        DYN_naval_enemyGroups pushBack _vGrp;

        private _driver = _vGrp createUnit [selectRandom _infPool, getPos _x, [], 0, "NONE"];
        _driver moveInDriver _x;
        _driver allowFleeing 0;
        _driver setSkill 0.45;
        DYN_naval_enemies pushBack _driver;

        if ((_x emptyPositions "gunner") > 0) then {
            private _gunner = _vGrp createUnit [selectRandom _infPool, getPos _x, [], 0, "NONE"];
            _gunner moveInGunner _x;
            _gunner allowFleeing 0;
            _gunner setSkill 0.50;
            DYN_naval_enemies pushBack _gunner;
        };
    };
} forEach DYN_naval_enemyVehs;

// ---- Optional patrol boat ----
if (random 1 < 0.7) then {
    private _boatSpawn = [_landPos, 80, 300, 40] call DYN_fnc_findNearbyWater;
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
            private _wpW = [_landPos, 100, 350, 30] call DYN_fnc_findNearbyWater;
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
// 6. MARKER & TASK
// =====================================================
private _mkr = format ["naval_mkr_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _landPos];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [250, 250];
_mkr setMarkerColor "ColorBlue";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
DYN_naval_markers pushBack _mkr;

[
    west,
    _taskId,
    [
        "A heavily defended enemy coastal outpost has been identified. Neutralize all hostile forces in the area. Expect strong resistance.",
        "Clear Coastal Outpost",
        ""
    ],
    _landPos,
    "CREATED",
    3,
    true,
    "attack"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_naval_tasks pushBack _taskId;

["NavalMission", ["Enemy coastal outpost detected. Heavy resistance expected."]]
    remoteExecCall ["BIS_fnc_showNotification", 0];

diag_log format ["[NAVAL-OUTPOST] %1 enemies spawned at %2", count DYN_naval_enemies, _landPos];

// =====================================================
// 7. MONITOR COMPLETION & DELAYED CLEANUP
// =====================================================
private _localEnemies = +DYN_naval_enemies;
private _localGroups  = +DYN_naval_enemyGroups;
private _localVehs    = +DYN_naval_enemyVehs;
private _localMarkers = +DYN_naval_markers;
private _localObjects = +DYN_naval_objects;

[_taskId, _timeout, _repReward, _compObjects, _clearedObjects, _cleanupDelay,
 _localEnemies, _localGroups, _localVehs, _localMarkers, _localObjects] spawn {
    params [
        "_tid", "_tOut", "_rep", "_spawnedObjects", "_hiddenTerrain", "_despawnDelay",
        "_localEnemies", "_localGroups", "_localVehs", "_localMarkers", "_localObjects"
    ];
    private _startTime = diag_tickTime;

    waitUntil {
        sleep 8;
        private _alive = { !isNull _x && alive _x } count _localEnemies;
        private _total = count _localEnemies;
        private _ratio = if (_total > 0) then { 1 - (_alive / _total) } else { 1 };
        private _cleared = _ratio >= 0.85;
        private _timedOut = (diag_tickTime - _startTime) > _tOut;
        _cleared || _timedOut
    };

    private _alive = { !isNull _x && alive _x } count _localEnemies;
    private _total = count _localEnemies;
    private _ratio = if (_total > 0) then { 1 - (_alive / _total) } else { 1 };

    if (_ratio >= 0.85) then {
        [_tid, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalComplete", ["Coastal outpost cleared."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        [_rep, "Coastal Outpost Cleared"] call DYN_fnc_changeReputation;
        diag_log format ["[NAVAL-OUTPOST] SUCCESS. +%1 rep.", _rep];
    } else {
        [_tid, "FAILED"] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalFailed", ["Coastal outpost mission expired."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[NAVAL-OUTPOST] TIMED OUT.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_naval_markers = DYN_naval_markers - _localMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_naval_active = false;

    diag_log format ["[NAVAL-OUTPOST] Mission area will be cleaned up in %1 minutes", floor (_despawnDelay / 60)];

    sleep _despawnDelay;

    diag_log format ["[NAVAL-OUTPOST] Starting full cleanup of %1 composition objects", count _spawnedObjects];

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
    diag_log format ["[NAVAL-OUTPOST] Restored %1 terrain objects", count _hiddenTerrain];

    // Surgical cleanup of global arrays
    DYN_naval_enemies     = DYN_naval_enemies     - _localEnemies;
    DYN_naval_enemyGroups = DYN_naval_enemyGroups  - _localGroups;
    DYN_naval_enemyVehs   = DYN_naval_enemyVehs   - _localVehs;
    DYN_naval_objects     = DYN_naval_objects      - _localObjects;

    diag_log "[NAVAL-OUTPOST] Full cleanup complete";
};
