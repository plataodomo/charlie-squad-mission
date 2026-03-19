/*
    scripts\groundMissions\fn_fobHunting.sqf
    GROUND MISSION: FOB Hunting

    Players are tasked with infiltrating a heavily defended enemy FOB and
    destroying all four supply asset types:
        - B_Slingload_01_Repair_F   (+8 rep)
        - B_Slingload_01_Ammo_F     (+8 rep)
        - B_Slingload_01_Fuel_F     (+8 rep)
        - Box_EAF_AmmoVeh_F x2      (+5 rep each = +10 rep)
    Total possible: 34 reputation

    The FOB is located at a fixed position on the map. A garrison of OPFOR
    infantry defends the compound. All assets must be destroyed within the
    time limit for full mission success.
*/
if (!isServer) exitWith {};

diag_log "[GROUND-FOB] Setting up FOB Hunting mission...";

// =====================================================
// 1. SETTINGS
// =====================================================
private _hardcodedCenter = [7395, 6412, 0];  // Centre of the FOB composition (may be in water)
private _fobCenter       = _hardcodedCenter; // Updated to a valid land position below
private _searchRadius = 200;               // Radius for target object search
private _timeout      = 7200;             // 2 hours
private _cleanupDelay = 120;              // Seconds before entity despawn after mission end

// Reputation per destroyed asset (total 34 if all destroyed)
private _repPerSlingload = 8;   // x3 = 24
private _repPerAmmoBox   = 5;   // x2 = 10

// =====================================================
// 2. SPAWN THE FOB BUILDING
// =====================================================
diag_log "[GROUND-FOB] Creating FOB building objects...";
// ---- inlined FOB building composition ----
private _layerWhiteList = [];
private _layerBlacklist = [];
private _allWhitelisted = _layerWhiteList isEqualTo [];
private _layerRoot = (_allWhitelisted || {true in _layerWhiteList}) && {!(true in _layerBlackList)};
private _layer136 = (_allWhitelisted || {"fob_10" in _layerWhiteList}) && {!("fob_10" in _layerBlackList)};
private _layer135 = (_allWhitelisted || {"fob_9" in _layerWhiteList}) && {!("fob_9" in _layerBlackList)};
private _layer134 = (_allWhitelisted || {"fob_8" in _layerWhiteList}) && {!("fob_8" in _layerBlackList)};
private _layer133 = (_allWhitelisted || {"fob_7" in _layerWhiteList}) && {!("fob_7" in _layerBlackList)};
private _layer6 = (_allWhitelisted || {"fob_5" in _layerWhiteList}) && {!("fob_5" in _layerBlackList)};
private _layer5 = (_allWhitelisted || {"fob_4" in _layerWhiteList}) && {!("fob_4" in _layerBlackList)};
private _layer802 = (_allWhitelisted || {"walled fob v2" in _layerWhiteList}) && {!("walled fob v2" in _layerBlackList)};

// =====================================================
// FOB BUILDING COMPOSITION (inlined)
// Exported from editor, offset applied at spawn time
// =====================================================
_fobBuildingComposition = {
    params ["_fobCenter", "_delta"];
    private _dx = _delta select 0;
    private _dy = _delta select 1;

    private _layerWhiteList = [];
    private _layerBlacklist = [];

    // item 8
    private _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir -16.094;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 9
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 12.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 10
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 24.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 11
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 36.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 12
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 48.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 13
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 12.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 14
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 24.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 15
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 36.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 16
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 48.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 17 - south wall
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 18
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx + 12.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 19
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx + 24.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 20
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx + 36.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 21
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 12.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 22
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 24.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 23
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 36.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 24
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 48.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 25 - east wall
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 26
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy + 12.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 27
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy + 24.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 28
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy - 12.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 29
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy - 24.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 30
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy - 36.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 31
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 253.9;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy + 36.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 32 - west wall
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 33
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy + 12.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 34
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy + 24.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 35
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy - 12.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 36
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy - 24.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 37
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy - 36.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 38
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 73.9;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy + 36.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 39 - corner NE
    _obj = createVehicle ["Land_BagFence_Corner_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 40 - corner NW
    _obj = createVehicle ["Land_BagFence_Corner_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 41 - corner SE
    _obj = createVehicle ["Land_BagFence_Corner_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 270;
    _obj setPos [(_fobCenter select 0) + _dx + 50.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 42 - corner SW
    _obj = createVehicle ["Land_BagFence_Corner_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 180;
    _obj setPos [(_fobCenter select 0) + _dx - 50.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 43 - north wall top
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 44
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 12.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 45
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 24.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 46
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 36.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 47
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 12.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 48
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 24.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 49
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx - 36.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 50 - gate/entrance (gap in north wall)
    _obj = createVehicle ["Land_BagFence_End_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 343.9;
    _obj setPos [(_fobCenter select 0) + _dx - 44.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 51
    _obj = createVehicle ["Land_BagFence_End_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 163.9;
    _obj setPos [(_fobCenter select 0) + _dx + 44.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 52 - sandbag wall sections inside
    _obj = createVehicle ["Land_HBarrier_1_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 30.0, (_fobCenter select 1) + _dy + 30.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 53
    _obj = createVehicle ["Land_HBarrier_1_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 30.0, (_fobCenter select 1) + _dy + 30.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 54
    _obj = createVehicle ["Land_HBarrier_1_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 40.0, (_fobCenter select 1) + _dy + 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 55
    _obj = createVehicle ["Land_HBarrier_1_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 40.0, (_fobCenter select 1) + _dy + 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 56 - tents
    _obj = createVehicle ["Land_TentA_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 20.0, (_fobCenter select 1) + _dy - 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 57
    _obj = createVehicle ["Land_TentA_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 20.0, (_fobCenter select 1) + _dy - 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 58
    _obj = createVehicle ["Land_TentA_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 59 - command tent
    _obj = createVehicle ["Land_TentLarge_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 60 - crates/supplies
    _obj = createVehicle ["Land_PaperBox_01_closed_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 35.0, (_fobCenter select 1) + _dy - 10.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 61
    _obj = createVehicle ["Land_PaperBox_01_closed_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 45;
    _obj setPos [(_fobCenter select 0) + _dx - 35.0, (_fobCenter select 1) + _dy - 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 62
    _obj = createVehicle ["Land_PaperBox_01_closed_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 35.0, (_fobCenter select 1) + _dy - 10.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 63
    _obj = createVehicle ["Land_PaperBox_01_closed_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 35.0, (_fobCenter select 1) + _dy - 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 64 - fuel tanks
    _obj = createVehicle ["Land_FuelStation_Feed_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 38.0, (_fobCenter select 1) + _dy - 35.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 65
    _obj = createVehicle ["Land_FuelStation_Feed_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 38.0, (_fobCenter select 1) + _dy - 25.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 66 - generator
    _obj = createVehicle ["Land_PowerGenerator_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 38.0, (_fobCenter select 1) + _dy - 35.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 67 - vehicle
    _obj = createVehicle ["CUP_O_UAZ_RU", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 20.0, (_fobCenter select 1) + _dy + 35.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 68 - vehicle 2
    _obj = createVehicle ["CUP_O_UAZ_RU", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 20.0, (_fobCenter select 1) + _dy + 35.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 69 - sandbag positions
    _obj = createVehicle ["Land_BagBunker_Small_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 45.0, (_fobCenter select 1) + _dy + 42.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 70
    _obj = createVehicle ["Land_BagBunker_Small_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 180;
    _obj setPos [(_fobCenter select 0) + _dx - 45.0, (_fobCenter select 1) + _dy + 42.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 71
    _obj = createVehicle ["Land_BagBunker_Small_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 45.0, (_fobCenter select 1) + _dy - 42.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 72
    _obj = createVehicle ["Land_BagBunker_Small_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 270;
    _obj setPos [(_fobCenter select 0) + _dx - 45.0, (_fobCenter select 1) + _dy - 42.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 73 - radio tower
    _obj = createVehicle ["Land_Communication_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 35.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 74 - watch tower
    _obj = createVehicle ["Land_Watchtower_01_wooden_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 45;
    _obj setPos [(_fobCenter select 0) + _dx + 46.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 75
    _obj = createVehicle ["Land_Watchtower_01_wooden_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 315;
    _obj setPos [(_fobCenter select 0) + _dx - 46.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 76 - ammo crates
    _obj = createVehicle ["B_supplyCrate_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 10.0, (_fobCenter select 1) + _dy - 30.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 77
    _obj = createVehicle ["B_supplyCrate_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 10.0, (_fobCenter select 1) + _dy - 30.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 78 - light poles
    _obj = createVehicle ["Land_LampHalogen_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 48.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 79
    _obj = createVehicle ["Land_LampHalogen_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 48.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 80
    _obj = createVehicle ["Land_LampHalogen_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 81
    _obj = createVehicle ["Land_LampHalogen_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 82 - barrels
    _obj = createVehicle ["Land_BarrelWater_grey_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 42.0, (_fobCenter select 1) + _dy - 10.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 83
    _obj = createVehicle ["Land_BarrelWater_grey_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 30;
    _obj setPos [(_fobCenter select 0) + _dx - 42.0, (_fobCenter select 1) + _dy - 14.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 84
    _obj = createVehicle ["Land_BarrelWater_grey_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 42.0, (_fobCenter select 1) + _dy - 10.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 85 - sandbag line inside east
    _obj = createVehicle ["Land_HBarrier_3_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 30.0, (_fobCenter select 1) + _dy - 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 86
    _obj = createVehicle ["Land_HBarrier_3_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 30.0, (_fobCenter select 1) + _dy - 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 87 - 5-barrier walls
    _obj = createVehicle ["Land_HBarrier_5_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 15.0, (_fobCenter select 1) + _dy + 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 88
    _obj = createVehicle ["Land_HBarrier_5_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 15.0, (_fobCenter select 1) + _dy + 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 89 - wire coils
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 55.0, (_fobCenter select 1) + _dy + 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 90
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 55.0, (_fobCenter select 1) + _dy - 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 91
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 55.0, (_fobCenter select 1) + _dy + 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 92
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 55.0, (_fobCenter select 1) + _dy - 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 93 - additional bunkers
    _obj = createVehicle ["Land_BagBunker_Large_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 42.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 94 - netting
    _obj = createVehicle ["Land_CamoNetB_OPFOR_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 20.0, (_fobCenter select 1) + _dy - 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 95
    _obj = createVehicle ["Land_CamoNetB_OPFOR_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 20.0, (_fobCenter select 1) + _dy - 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 96 - pallet stacks
    _obj = createVehicle ["Land_PalletBox_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 40.0, (_fobCenter select 1) + _dy + 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 97
    _obj = createVehicle ["Land_PalletBox_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 40.0, (_fobCenter select 1) + _dy + 5.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 98 - fire extinguishers (props)
    _obj = createVehicle ["Land_FireExtinguisher_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 5.0, (_fobCenter select 1) + _dy + 14.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 99
    _obj = createVehicle ["Land_FireExtinguisher_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 5.0, (_fobCenter select 1) + _dy + 14.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 100 - additional fence sections (inner perimeter)
    _obj = createVehicle ["Land_HBarrier_Wall_4_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 101 - checkpoint markers
    _obj = createVehicle ["Land_CheckBoard_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 52.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 102 - additional tents
    _obj = createVehicle ["Land_TentA_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 35.0, (_fobCenter select 1) + _dy + 10.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 103
    _obj = createVehicle ["Land_TentA_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 35.0, (_fobCenter select 1) + _dy + 10.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 104 - additional MG position
    _obj = createVehicle ["Land_BagFence_Long_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 20.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 105
    _obj = createVehicle ["Land_BagFence_Long_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 180;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 42.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 106 - additional perimeter bags
    _obj = createVehicle ["Land_BagFence_Short_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 25.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 107
    _obj = createVehicle ["Land_BagFence_Short_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 25.0, (_fobCenter select 1) + _dy + 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 108 - additional barrier ends south
    _obj = createVehicle ["Land_BagFence_Short_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 270;
    _obj setPos [(_fobCenter select 0) + _dx + 25.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 109
    _obj = createVehicle ["Land_BagFence_Short_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 270;
    _obj setPos [(_fobCenter select 0) + _dx - 25.0, (_fobCenter select 1) + _dy - 48.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 110 - additional wire sections
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 35.0, (_fobCenter select 1) + _dy + 55.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 111
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 35.0, (_fobCenter select 1) + _dy + 55.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 112
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 35.0, (_fobCenter select 1) + _dy - 55.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 113
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 35.0, (_fobCenter select 1) + _dy - 55.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 114 - extra vehicle parking
    _obj = createVehicle ["CUP_O_Ural_RU", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 270;
    _obj setPos [(_fobCenter select 0) + _dx - 35.0, (_fobCenter select 1) + _dy + 38.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 115 - table and chairs props
    _obj = createVehicle ["Land_TableDesk_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 13.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 116
    _obj = createVehicle ["Land_ChairOffice_01_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 2.0, (_fobCenter select 1) + _dy + 11.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 117
    _obj = createVehicle ["Land_ChairOffice_01_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 180;
    _obj setPos [(_fobCenter select 0) + _dx + 2.0, (_fobCenter select 1) + _dy + 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 118 - additional bunker cover
    _obj = createVehicle ["Land_BagFence_Long_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 44.0, (_fobCenter select 1) + _dy + 8.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 119
    _obj = createVehicle ["Land_BagFence_Long_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 44.0, (_fobCenter select 1) + _dy + 8.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 120 - HMG static weapon
    _obj = createVehicle ["CUP_O_RU_HMG_DSHKM", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 45;
    _obj setPos [(_fobCenter select 0) + _dx + 46.0, (_fobCenter select 1) + _dy + 43.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 121
    _obj = createVehicle ["CUP_O_RU_HMG_DSHKM", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 315;
    _obj setPos [(_fobCenter select 0) + _dx - 46.0, (_fobCenter select 1) + _dy + 43.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 122
    _obj = createVehicle ["CUP_O_RU_HMG_DSHKM", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 135;
    _obj setPos [(_fobCenter select 0) + _dx + 46.0, (_fobCenter select 1) + _dy - 43.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 123
    _obj = createVehicle ["CUP_O_RU_HMG_DSHKM", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 225;
    _obj setPos [(_fobCenter select 0) + _dx - 46.0, (_fobCenter select 1) + _dy - 43.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 124 - extra bags around HMGs
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 45;
    _obj setPos [(_fobCenter select 0) + _dx + 43.0, (_fobCenter select 1) + _dy + 40.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 125
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 315;
    _obj setPos [(_fobCenter select 0) + _dx - 43.0, (_fobCenter select 1) + _dy + 40.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 126
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 135;
    _obj setPos [(_fobCenter select 0) + _dx + 43.0, (_fobCenter select 1) + _dy - 40.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 127
    _obj = createVehicle ["Land_BagFence_Round_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 225;
    _obj setPos [(_fobCenter select 0) + _dx - 43.0, (_fobCenter select 1) + _dy - 40.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 128 - target: HQ building (command post object)
    _obj = createVehicle ["Land_TentLarge_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 25.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 129
    _obj = createVehicle ["Land_TentLarge_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx - 18.0, (_fobCenter select 1) + _dy + 8.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 130
    _obj = createVehicle ["Land_TentLarge_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 18.0, (_fobCenter select 1) + _dy + 8.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 131 - target object: satellite dish (main target)
    _fobTarget = createVehicle ["Land_Dish_small_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _fobTarget setDir 0;
    _fobTarget setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _fobTarget;

    // item 132 - target: generator/power unit
    _obj = createVehicle ["Land_PowerGenerator_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 90;
    _obj setPos [(_fobCenter select 0) + _dx + 8.0, (_fobCenter select 1) + _dy + 0.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 133 - additional wire on south
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 15.0, (_fobCenter select 1) + _dy - 55.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 134
    _obj = createVehicle ["Land_Razorwire_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx - 15.0, (_fobCenter select 1) + _dy - 55.0, 0.0];
    DYN_ground_objects pushBack _obj;

    // item 135 - extra vehicle
    _obj = createVehicle ["CUP_O_UAZ_RU", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 180;
    _obj setPos [(_fobCenter select 0) + _dx + 35.0, (_fobCenter select 1) + _dy + 38.0, 0.0];
    DYN_ground_objects pushBack _obj;
    DYN_ground_enemyVehs pushBack _obj;

    // item 136 - additional bags interior
    _obj = createVehicle ["Land_HBarrier_1_F", [_fobCenter select 0, _fobCenter select 1, 0], [], 0, "NONE"];
    _obj setDir 0;
    _obj setPos [(_fobCenter select 0) + _dx + 0.0, (_fobCenter select 1) + _dy - 15.0, 0.0];
    DYN_ground_objects pushBack _obj;

    _fobTarget
};

// ---- end inlined FOB building composition ----

// =====================================================
// SPAWN FOB OBJECTS AT HARDCODED CENTER
// (will be shifted to valid land position below)
// =====================================================
private _fobBuildingTarget = [_hardcodedCenter, [0, 0, 0]] call _fobBuildingComposition;

// Create target supply assets inside the FOB perimeter
private _spawnRep  = createVehicle ["B_Slingload_01_Repair_F", [_hardcodedCenter#0 - 15, _hardcodedCenter#1 + 10, 0], [], 0, "NONE"];
private _spawnAmmo = createVehicle ["B_Slingload_01_Ammo_F",   [_hardcodedCenter#0,       _hardcodedCenter#1 + 10, 0], [], 0, "NONE"];
private _spawnFuel = createVehicle ["B_Slingload_01_Fuel_F",   [_hardcodedCenter#0 + 15,  _hardcodedCenter#1 + 10, 0], [], 0, "NONE"];
private _spawnBox1 = createVehicle ["Box_EAF_AmmoVeh_F",       [_hardcodedCenter#0 - 10,  _hardcodedCenter#1 - 25, 0], [], 0, "NONE"];
private _spawnBox2 = createVehicle ["Box_EAF_AmmoVeh_F",       [_hardcodedCenter#0 + 10,  _hardcodedCenter#1 - 25, 0], [], 0, "NONE"];
{ DYN_ground_objects pushBack _x } forEach [_spawnRep, _spawnAmmo, _spawnFuel, _spawnBox1, _spawnBox2];

// Snapshot all created objects for relocation and cleanup
private _objects = +DYN_ground_objects;

// =====================================================
// DYNAMIC POSITIONING — relocate FOB to valid land
// =====================================================
private _basePos  = getMarkerPos "respawn_west";
private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

for "_attempt" from 1 to 150 do {
    private _testPos = [_basePos, 2500 + random 10000, random 360] call DYN_fnc_posOffset;

    if (surfaceIsWater _testPos) then { continue };
    if (getTerrainHeightASL _testPos < 1) then { continue };
    if !(_aoCenter isEqualTo [0,0,0]) then {
        if (_testPos distance2D _aoCenter < 1000) then { continue };
    };

    // Basic flatness check — reject steep slopes
    private _heights = [0, 90, 180, 270] apply {
        getTerrainHeightASL ([_testPos, 60, _x] call DYN_fnc_posOffset)
    };
    if ((selectMax _heights) - (selectMin _heights) > 10) then { continue };

    _fobCenter = _testPos;
    break;
};

if (surfaceIsWater _fobCenter) exitWith {
    diag_log "[GROUND-FOB] ERROR: No valid land position found. Aborting.";
    { if (!isNull _x) then { deleteVehicle _x } } forEach _objects;
    DYN_ground_active = false;
};

// Shift every building object from its hardcoded position to the chosen land centre
private _delta = [
    (_fobCenter select 0) - (_hardcodedCenter select 0),
    (_fobCenter select 1) - (_hardcodedCenter select 1),
    0
];
{ if (!isNull _x) then { _x setPos (getPos _x vectorAdd _delta) } } forEach _objects;
diag_log format ["[GROUND-FOB] FOB relocated to %1", _fobCenter];

// Allow object initialisation to settle
sleep 2;

// Collect all FOB building objects for cleanup at mission end
private _fobObjects = [];
{ if (!isNull _x) then { _fobObjects pushBack _x } } forEach _objects;

diag_log format ["[GROUND-FOB] Building SQF created %1 objects.", count _fobObjects];

// =====================================================
// 3. LOCATE TARGET OBJECTS
// =====================================================
private _repairPod = objNull;
private _ammoPod   = objNull;
private _fuelPod   = objNull;
private _ammoBoxes = [];

{
    switch (typeOf _x) do {
        case "B_Slingload_01_Repair_F": { _repairPod = _x };
        case "B_Slingload_01_Ammo_F":   { _ammoPod   = _x };
        case "B_Slingload_01_Fuel_F":   { _fuelPod   = _x };
        case "Box_EAF_AmmoVeh_F":       { _ammoBoxes pushBack _x };
    };
} forEach nearestObjects [_fobCenter,
    ["B_Slingload_01_Repair_F",
     "B_Slingload_01_Ammo_F",
     "B_Slingload_01_Fuel_F",
     "Box_EAF_AmmoVeh_F"],
    _searchRadius];

// Validate all required targets were found
if (isNull _repairPod || isNull _ammoPod || isNull _fuelPod || count _ammoBoxes < 1) exitWith {
    diag_log "[GROUND-FOB] ERROR: One or more target objects not found. Aborting.";
    { if (!isNull _x) then { deleteVehicle _x } } forEach _fobObjects;
    DYN_ground_active = false;
};

diag_log format [
    "[GROUND-FOB] Targets confirmed - Repair: %1  Ammo: %2  Fuel: %3  AmmoBoxes: %4",
    !isNull _repairPod, !isNull _ammoPod, !isNull _fuelPod, count _ammoBoxes
];

// =====================================================
// 4. SPAWN ENEMY GARRISON
// =====================================================
// Six infantry groups spread around the compound interior and perimeter
private _spawnZones = [
    [30,  10],   // Near gate - north approach
    [45,  80],   // East inner wall
    [45, 160],   // South courtyard
    [45, 250],   // West inner wall
    [20,  40],   // Deep interior NE (near slingloads)
    [25, 220]    // Deep interior SW (near ammo boxes)
];

private _infantryTypes = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_SL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_MG_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn"
];

{
    private _dist = _x select 0;
    private _dir  = _x select 1;
    private _spawnPos = [_fobCenter, _dist, _dir] call DYN_fnc_posOffset;
    private _grpSize  = 4 + floor random 5;  // 4-8 per group
    private _grp = createGroup east;

    for "_i" from 1 to _grpSize do {
        private _unitPos = [_spawnPos, random 8, random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _unitPos) then { _unitPos = _spawnPos };

        private _unit = _grp createUnit [selectRandom _infantryTypes, _unitPos, [], 0, "NONE"];
        if (!isNull _unit) then {
            _unit allowFleeing 0.1;
            _unit setSkill ["aimingAccuracy", 0.40 + random 0.35];
            _unit setSkill ["aimingShake",    0.45 + random 0.30];
            _unit setSkill ["aimingSpeed",    0.45 + random 0.30];
            _unit setSkill ["spotDistance",   0.70 + random 0.30];
            _unit setSkill ["spotTime",       0.65 + random 0.30];
            _unit setSkill ["courage",        0.75 + random 0.25];
            DYN_ground_enemies pushBack _unit;
        };
    };

    if (units _grp isEqualTo []) then {
        deleteGroup _grp;
    } else {
        _grp setBehaviourStrong "AWARE";
        _grp setCombatMode "RED";
        _grp setSpeedMode "NORMAL";

        // Local patrol around spawn zone
        private _wp = _grp addWaypoint [_spawnPos, 35];
        _wp setWaypointType "LOITER";
        _wp setWaypointLoiterRadius 35;

        DYN_ground_enemyGroups pushBack _grp;
    };
} forEach _spawnZones;

// Two static MG posts near the FOB perimeter walls
private _mgPosts = [
    [60,  15],
    [65, 195]
];

{
    private _mgPos = [_fobCenter, _x select 0, _x select 1] call DYN_fnc_posOffset;
    private _mgGrp = createGroup east;

    private _gunner = _mgGrp createUnit ["CUP_O_RU_Soldier_MG_Ratnik_Autumn", _mgPos, [], 0, "NONE"];
    if (!isNull _gunner) then {
        _gunner allowFleeing 0;
        _gunner setSkill 0.85;
        _gunner disableAI "PATH";
        DYN_ground_enemies pushBack _gunner;
    };

    if (units _mgGrp isEqualTo []) then {
        deleteGroup _mgGrp;
    } else {
        _mgGrp setBehaviourStrong "COMBAT";
        _mgGrp setCombatMode "RED";
        DYN_ground_enemyGroups pushBack _mgGrp;
    };
} forEach _mgPosts;

// Outer roving patrol - 1 group circling outside the walls
private _outerPatrolGrp = createGroup east;
private _outerPatrolSize = 4 + floor random 3;

for "_i" from 1 to _outerPatrolSize do {
    private _unitPos = [_fobCenter, 80 + random 30, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _unitPos) then { _unitPos = _fobCenter };

    private _unit = _outerPatrolGrp createUnit [selectRandom _infantryTypes, _unitPos, [], 0, "NONE"];
    if (!isNull _unit) then {
        _unit allowFleeing 0.2;
        _unit setSkill 0.6;
        DYN_ground_enemies pushBack _unit;
    };
};

if (units _outerPatrolGrp isEqualTo []) then {
    deleteGroup _outerPatrolGrp;
} else {
    _outerPatrolGrp setBehaviourStrong "AWARE";
    _outerPatrolGrp setCombatMode "RED";
    _outerPatrolGrp setSpeedMode "NORMAL";

    private _wp = _outerPatrolGrp addWaypoint [_fobCenter, 90];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius 90;

    DYN_ground_enemyGroups pushBack _outerPatrolGrp;
};

diag_log format [
    "[GROUND-FOB] Garrison spawned: %1 groups, %2 infantry total.",
    count DYN_ground_enemyGroups,
    count DYN_ground_enemies
];

// Register FOB objects for global cleanup
{ DYN_ground_objects pushBack _x } forEach _fobObjects;

// =====================================================
// 5. MARKER AND TASK
// =====================================================
private _taskId = format ["ground_fob_%1", round (diag_tickTime * 1000)];

private _mkr = format ["ground_mkr_fob_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _fobCenter];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [_searchRadius * 0.6, _searchRadius * 0.6];
_mkr setMarkerColor "ColorRed";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
_mkr setMarkerText "Enemy FOB";
DYN_ground_markers pushBack _mkr;

[
    west,
    _taskId,
    [
        "Intelligence confirms an active enemy Forward Operating Base. The FOB is heavily garrisoned and houses critical supply assets that sustain enemy operations in the region.<br/><br/>Destroy the following:<br/><br/>- Repair Pod<br/>- Ammunition Pod<br/>- Fuel Pod<br/>- Ammunition Vehicles<br/><br/>Expect a heavily armed garrison. All supply assets must be eliminated.",
        "FOB Hunting",
        ""
    ],
    _fobCenter,
    "CREATED",
    3,
    true,
    "rifle"
] remoteExec ["BIS_fnc_taskCreate", 0, _taskId];

DYN_ground_tasks pushBack _taskId;

diag_log format ["[GROUND-FOB] Mission active. FOB centre: %1", _fobCenter];

// =====================================================
// 6. COMPLETION MONITOR
// =====================================================
private _localEnemies  = +DYN_ground_enemies;
private _localGroups   = +DYN_ground_enemyGroups;
private _localObjects  = +DYN_ground_objects;
private _localMarkers  = +DYN_ground_markers;

[
    _taskId, _timeout, _cleanupDelay,
    _repairPod, _ammoPod, _fuelPod, _ammoBoxes,
    _repPerSlingload, _repPerAmmoBox,
    _localEnemies, _localGroups, _localObjects, _localMarkers
] spawn {
    params [
        "_tid", "_tOut", "_despawnDelay",
        "_repairPod", "_ammoPod", "_fuelPod", "_ammoBoxes",
        "_repPerSlingload", "_repPerAmmoBox",
        "_localEnemies", "_localGroups", "_localObjects", "_localMarkers"
    ];

    private _startTime   = diag_tickTime;
    private _repairDone  = false;
    private _ammoDone    = false;
    private _fuelDone    = false;
    private _ammoBoxDone = false;

    // Helper - vehicle considered destroyed at 90 % damage or when no longer alive
    private _isDead = { (damage _this >= 0.9) || { !alive _this } || { isNull _this } };

    waitUntil {
        sleep 5;

        // ---- Track destruction (no per-asset rep, awarded all at once on completion) ----
        if (!_repairDone && (_repairPod call _isDead)) then {
            _repairDone = true;
            diag_log "[GROUND-FOB] Repair pod destroyed.";
        };

        if (!_ammoDone && (_ammoPod call _isDead)) then {
            _ammoDone = true;
            diag_log "[GROUND-FOB] Ammo pod destroyed.";
        };

        if (!_fuelDone && (_fuelPod call _isDead)) then {
            _fuelDone = true;
            diag_log "[GROUND-FOB] Fuel pod destroyed.";
        };

        if (!_ammoBoxDone) then {
            private _allGone = (_ammoBoxes findIf { !(_x call _isDead) }) isEqualTo -1;
            if (_allGone && { count _ammoBoxes > 0 }) then {
                _ammoBoxDone = true;
                diag_log "[GROUND-FOB] All ammo vehicles destroyed.";
            };
        };

        // ---- Completion check ----
        private _allDone = _repairDone && _ammoDone && _fuelDone && _ammoBoxDone;
        private _timedOut = (diag_tickTime - _startTime) > _tOut;

        _allDone || _timedOut
    };

    private _allDone = _repairDone && _ammoDone && _fuelDone && _ammoBoxDone;

    if (_allDone) then {
        private _totalRep = (_repPerSlingload * 3) + (_repPerAmmoBox * count _ammoBoxes);
        [_totalRep, "FOB Destroyed"] call DYN_fnc_changeReputation;
        [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
        ["TaskSucceeded", [
            "FOB Hunting complete! All enemy supply assets have been destroyed.",
            "FOB Hunting"
        ]] remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log format ["[GROUND-FOB] SUCCESS - all targets destroyed. +%1 rep.", _totalRep];
    } else {
        [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
        ["TaskFailed", [
            "FOB Hunting Failed",
            "Not all supply assets were destroyed before the deadline."
        ]] remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-FOB] TIMED OUT - mission failed.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_ground_markers = DYN_ground_markers - _localMarkers;

    sleep 15;
    [_tid] remoteExec ["BIS_fnc_deleteTask", 0];
    [] remoteExec ["", 0, _tid];

    DYN_ground_active = false;

    diag_log format ["[GROUND-FOB] Despawning in %1 seconds.", _despawnDelay];
    sleep _despawnDelay;

    // Delete infantry and their groups
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
    { if (!isNull _x) then { deleteGroup _x } } forEach _localGroups;

    // Delete all FOB building objects
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localObjects;

    DYN_ground_enemies     = DYN_ground_enemies     - _localEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _localGroups;
    DYN_ground_objects     = DYN_ground_objects     - _localObjects;

    diag_log "[GROUND-FOB] Full cleanup complete.";
};

diag_log "[GROUND-FOB] FOB Hunting mission initialised successfully.";
