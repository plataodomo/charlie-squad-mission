/*
    scripts\shop\fn_shopSystem.sqf
    VEHICLE SHOP - SERVER SYSTEM

    REQUIRED MARKERS (place in Eden editor):
      base_area     - ELLIPSE/RECTANGLE marker covering your base (for persistence)
      shop_spawn    - Ground vehicle spawn (Cars, Trucks, Armor)
      heli_spawn    - Helicopter spawn pad
      boat_spawn    - Boat spawn point (place near water)
      jet_spawn_1   - First jet hangar
      jet_spawn_2   - Second jet hangar
*/

if (!isServer) exitWith {};

diag_log "[SHOP] Initializing Vehicle Shop System";

// Format: [className, displayName, cost, category]
DYN_shopVehicles = [
    // ===== CARS =====
    ["CUP_B_HMMWV_Unarmed_USA", "HMMWV Unarmed", 2, "Cars"],
    ["CUP_B_HMMWV_M2_USA", "HMMWV M2", 8, "Cars"],
    ["CUP_B_HMMWV_MK19_USA", "HMMWV MK19", 10, "Cars"],
    ["CUP_B_HMMWV_TOW_USA", "HMMWV TOW", 12, "Cars"],
    ["CUP_B_HMMWV_M1114_USMC", "HMMWV M1114", 10, "Cars"],
    ["CUP_B_HMMWV_DSHKM_USA", "HMMWV DSHKM", 8, "Cars"],
    ["CUP_B_M1151_M2_US_Army", "M1151 M2", 8, "Cars"],
    ["CUP_B_M1151_Mk19_US_Army", "M1151 MK19", 10, "Cars"],
    ["CUP_B_M1165_GMV_USA", "M1165 GMV", 6, "Cars"],
    ["CUP_B_Jackal2_L2A1_GB", "Jackal 2 HMG", 7, "Cars"],
    ["CUP_B_Jackal2_GMG_GB", "Jackal 2 GMG", 9, "Cars"],
    ["CUP_B_Ridgback_HMG_GB", "Ridgback HMG", 10, "Cars"],
    ["CUP_B_Ridgback_GMG_GB", "Ridgback GMG", 12, "Cars"],
    ["CUP_B_Wolfhound_HMG_GB", "Wolfhound HMG", 10, "Cars"],
    ["CUP_B_Wolfhound_GMG_GB", "Wolfhound GMG", 12, "Cars"],
    ["CUP_B_LR_Transport_GB", "Land Rover", 2, "Cars"],
    ["CUP_B_LR_MG_GB", "Land Rover MG", 5, "Cars"],
    ["CUP_B_LR_Special_GMG_GB", "Land Rover GMG", 7, "Cars"],
    ["CUP_B_Mastiff_HMG_GB", "Mastiff HMG", 10, "Cars"],
    ["CUP_B_Mastiff_GMG_GB", "Mastiff GMG", 12, "Cars"],
    ["CUP_B_Coyote_HMG_GB", "Coyote HMG", 8, "Cars"],
    ["CUP_B_Coyote_GMG_GB", "Coyote GMG", 10, "Cars"],
    ["CUP_B_nM1038_USA", "M1038 Utility", 3, "Cars"],
    ["B_MRAP_01_F", "Hunter", 5, "Cars"],
    ["B_MRAP_01_hmg_F", "Hunter HMG", 10, "Cars"],
    ["B_MRAP_01_gmg_F", "Hunter GMG", 12, "Cars"],
    ["B_LSV_01_armed_F", "Prowler Armed", 8, "Cars"],
    ["B_LSV_01_unarmed_F", "Prowler Unarmed", 3, "Cars"],
    // --- Bundeswehr (BWA3) protected vehicles ---
    ["BWA3_Eagle_Tropen", "Eagle IV", 6, "Cars"],
    ["BWA3_Eagle_FLW100_Tropen", "Eagle IV FLW100 (Remote HMG)", 12, "Cars"],
    ["BWA3_Dingo2_FLW100_MG3_CG13_Tropen", "Dingo 2 FLW100 MG3", 10, "Cars"],
    ["BWA3_Dingo2_FLW200_M2_CG13_Tropen", "Dingo 2 FLW200 M2", 13, "Cars"],
    ["BWA3_Dingo2_FLW200_GMW_CG13_Tropen", "Dingo 2 FLW200 GMG", 15, "Cars"],

    // ===== TRUCKS =====
    ["CUP_B_MTVR_USA", "MTVR Transport", 4, "Trucks"],
    ["CUP_B_MTVR_Ammo_USA", "MTVR Ammo", 8, "Trucks"],
    ["CUP_B_MTVR_Refuel_USA", "MTVR Fuel", 6, "Trucks"],
    ["CUP_B_MTVR_Repair_USA", "MTVR Repair", 6, "Trucks"],
    ["CUP_B_MTVR_CROW_USA", "MTVR CROW", 10, "Trucks"],
    ["B_Truck_01_covered_F", "HEMTT Covered", 5, "Trucks"],
    ["B_Truck_01_transport_F", "HEMTT Transport", 4, "Trucks"],
    ["B_Truck_01_medical_F", "HEMTT Medical", 6, "Trucks"],
    ["B_Truck_01_ammo_F", "HEMTT Ammo", 8, "Trucks"],
    ["B_Truck_01_fuel_F", "HEMTT Fuel", 6, "Trucks"],
    ["B_Truck_01_Repair_F", "HEMTT Repair", 6, "Trucks"],

    // ===== ARMOR =====
    ["CUP_B_M113_USA", "M113 APC", 15, "Armor"],
    ["CUP_B_M113_Med_USA", "M113 Medical", 12, "Armor"],
    ["CUP_B_LAV25_USMC", "LAV-25", 25, "Armor"],
    ["CUP_B_LAV25_HQ_USMC", "LAV-25 HQ", 25, "Armor"],
    ["CUP_B_AAV_USMC", "AAV-7 Amtrac", 22, "Armor"],
    ["CUP_B_M1126_ICV_M2_US_Army", "Stryker ICV M2", 20, "Armor"],
    ["CUP_B_M1126_ICV_MK19_US_Army", "Stryker ICV MK19", 22, "Armor"],
    ["CUP_B_M1128_MGS_US_Army", "Stryker MGS", 30, "Armor"],
    ["CUP_B_M1135_ATGMV_US_Army", "Stryker ATGM", 28, "Armor"],
    ["CUP_B_M2Bradley_USA_W", "M2A2 Bradley", 35, "Armor"],
    ["CUP_B_M2A3Bradley_USA_W", "M2A3 Bradley", 38, "Armor"],
    ["CUP_B_M6LineBacker_USA_W", "M6 Linebacker AA", 35, "Armor"],
    ["CUP_B_M7Bradley_USA_W", "M7 Bradley BFIST", 30, "Armor"],
    ["CUP_B_M1A1SA_Woodland_US_Army", "M1A1 Abrams", 55, "Armor"],
    ["CUP_B_M1A2SEP_Woodland_US_Army", "M1A2 Abrams SEP", 60, "Armor"],
    ["CUP_B_M1A2SEP_TUSK_Woodland_US_Army", "M1A2 TUSK", 65, "Armor"],
    ["CUP_B_FV510_GB", "FV510 Warrior", 30, "Armor"],
    ["CUP_B_FV432_Bulldog_GB", "FV432 Bulldog", 18, "Armor"],
    ["CUP_B_Challenger2_2CW_GB", "Challenger 2", 60, "Armor"],
    ["CUP_B_MCV80_GB", "MCV-80 Warrior", 28, "Armor"],
    ["B_APC_Wheeled_01_cannon_F", "Marshall APC", 25, "Armor"],
    ["B_APC_Tracked_01_rcws_F", "Panther APC", 30, "Armor"],
    ["B_APC_Tracked_01_AA_F", "Cheetah AA", 35, "Armor"],
    ["B_MBT_01_cannon_F", "Slammer Tank", 50, "Armor"],
    ["B_MBT_01_TUSK_F", "Slammer TUSK", 55, "Armor"],
    // --- Bundeswehr (BWA3) / community armor ---
    ["Redd_Marder_1A5_Tropentarn", "Marder 1A5 IFV", 28, "Armor"],
    ["rnt_sppz_2a2_luchs_tropentarn", "SPPz 2 Luchs (Recon)", 22, "Armor"],
    ["BWA3_Puma_Tropen", "Puma IFV", 40, "Armor"],
    ["BWA3_Leopard2_Tropen", "Leopard 2 MBT", 60, "Armor"],

    // ===== HELICOPTERS =====
    ["CUP_B_MH6M_USA", "MH-6M Little Bird", 10, "Helicopters"],
    ["CUP_B_AH6M_USA", "AH-6M Little Bird Armed", 25, "Helicopters"],
    ["CUP_B_CH47F_USA", "CH-47F Chinook", 25, "Helicopters"],
    ["CUP_B_AH64D_DL_USA", "AH-64D Apache", 60, "Helicopters"],
    ["CUP_B_MH60L_DAP_4x_USArmy", "MH-60L DAP", 40, "Helicopters"],
    ["CUP_B_AW159_RN_Blackcat", "AW159 Wildcat", 30, "Helicopters"],
    ["CUP_B_Apache_AH1_GB", "Apache AH1", 55, "Helicopters"],
    ["B_Heli_Attack_01_dynamicLoadout_F", "AH-99 Blackfoot", 60, "Helicopters"],
    // --- Bundeswehr (BWA3) helicopters ---
    ["BWA3_NH90_TTH_M3M_Tropen", "NH-90 TTH (Armed)", 28, "Helicopters"],
    ["BWA3_Tiger_RMK", "Tiger RMK (Attack)", 55, "Helicopters"],

    // ===== JETS =====
    ["CFP_B_USMC_AV_8B_Harrier_II_DES_01", "AV-8B Harrier II", 100, "Jets"],
    ["cfp_o_syarmy_yak130", "Yak-130", 100, "Jets"],

    // ===== BOATS =====
    ["B_Boat_Transport_01_F",       "Assault Boat",          3,  "Boats"],
    ["CUP_B_RHIB_USMC",            "RHIB USMC",             5,  "Boats"],
    ["CUP_B_MK10_GB",              "MK10 Patrol Boat",      7,  "Boats"],
    ["B_SDV_01_F",                  "SDV Submersible",       5,  "Boats"],
    ["B_Boat_Armed_01_minigun_F",   "Assault Boat Armed",    8,  "Boats"],
    ["CUP_B_RHIB2Turret_USMC",     "RHIB Armed",            10, "Boats"]
];
publicVariable "DYN_shopVehicles";

// Format: [itemClass, displayName, cost, quantity, type, picture]
//   type "item"  — added directly to buyer's inventory
//   type "spawn" — spawned directly as a world object (e.g. a carryable backpack)
//   picture      — optional explicit UI icon path (used when automatic config lookup returns empty)
DYN_shopSupplies = [
    // ===== SPARE PARTS =====
    ["ACE_Track",        "Spare Track",    5, 1, "item"],
    ["ACE_Wheel",        "Spare Wheel",    5, 1, "item"],
    // ===== FUEL =====
    ["rhsusf_props_ScepterMFC_OD", "Fuel Can", 5, 1, "spawn"],
    // ===== PORTABLE STORAGE =====
    ["Box_NATO_Equip_F", "Supply Crate",   5, 1, "spawn"]
];
publicVariable "DYN_shopSupplies";

// =====================================================
// GET VEHICLE PICTURE FROM CONFIG (AUTOMATIC)
// =====================================================
DYN_fnc_getVehiclePic = {
    params ["_classname"];
    private _cfg = configFile >> "CfgVehicles" >> _classname;
    private _pic = getText (_cfg >> "editorPreview");
    if (_pic == "") then { _pic = getText (_cfg >> "overviewPicture"); };
    if (_pic == "") then { _pic = getText (_cfg >> "picture"); };
    if (_pic == "") then { _pic = "\A3\ui_f\data\map\markers\nato\b_unknown.paa"; };
    _pic
};
publicVariable "DYN_fnc_getVehiclePic";

// =====================================================
// GROUND VEHICLE SPAWN (Cars, Trucks, Armor)
// =====================================================
DYN_fnc_getShopSpawnPos = {
    private _pos = getMarkerPos "shop_spawn";
    if (!(_pos isEqualTo [0,0,0])) exitWith {_pos};
    
    private _pads = allMissionObjects "Land_HelipadEmpty_F" select {
        (_x getVariable ["DYN_shopSpawn", false])
    };
    if (count _pads > 0) exitWith {getPosATL (selectRandom _pads)};
    
    private _basePos = getMarkerPos "respawn_west";
    if (_basePos isEqualTo [0,0,0]) then {
        _basePos = [worldSize/2, worldSize/2, 0];
    };
    [_basePos, 20, 50, 5, 0, 0.5, 0] call BIS_fnc_findSafePos
};
publicVariable "DYN_fnc_getShopSpawnPos";

// =====================================================
// CATEGORY-BASED SPAWN POSITION
// Returns: [position, direction, errorMessage]
// =====================================================
DYN_fnc_getSpawnPosByCategory = {
    params ["_category"];

    private _pos = [0,0,0];
    private _dir = random 360;
    private _err = "";

    switch (_category) do {
        case "Jets": {
            private _pos1 = getMarkerPos "jet_spawn_1";
            private _pos2 = getMarkerPos "jet_spawn_2";
            private _free1 = !(_pos1 isEqualTo [0,0,0]) && { count nearestObjects [_pos1, ["Plane","Air"], 25] == 0 };
            private _free2 = !(_pos2 isEqualTo [0,0,0]) && { count nearestObjects [_pos2, ["Plane","Air"], 25] == 0 };

            if (_free1) then { _pos = _pos1; _dir = markerDir "jet_spawn_1"; }
            else { if (_free2) then { _pos = _pos2; _dir = markerDir "jet_spawn_2"; }
            else { _err = "Both jet hangars are currently occupied!"; }; };
        };
        case "Helicopters": {
            private _hPos = getMarkerPos "heli_spawn";
            if (_hPos isEqualTo [0,0,0]) then {
                _pos = [] call DYN_fnc_getShopSpawnPos;
                diag_log "[SHOP] WARNING: heli_spawn marker not found, using ground spawn";
            } else {
                if (count nearestObjects [_hPos, ["Air"], 20] > 0) then {
                    _err = "Helicopter pad is occupied!";
                } else {
                    _pos = _hPos;
                    _dir = markerDir "heli_spawn";
                };
            };
        };
        case "Boats": {
            private _bPos = getMarkerPos "boat_spawn";
            if (_bPos isEqualTo [0,0,0]) then {
                _err = "No boat_spawn marker found! Place a 'boat_spawn' marker near water in the editor.";
            } else {
                if (count nearestObjects [_bPos, ["Ship"], 15] > 0) then {
                    _err = "Boat spawn is occupied!";
                } else {
                    _pos = _bPos;
                    _dir = markerDir "boat_spawn";
                };
            };
        };
        default {
            // Cars, Trucks, Armor
            private _gPos = [] call DYN_fnc_getShopSpawnPos;
            if (count nearestObjects [_gPos, ["LandVehicle"], 10] > 0) then {
                _err = "Vehicle spawn is occupied! Move any parked vehicles.";
            } else {
                _pos = _gPos;
                _dir = markerDir "shop_spawn";
            };
        };
    };

    [_pos, _dir, _err]
};
publicVariable "DYN_fnc_getSpawnPosByCategory";

// =====================================================
// PURCHASE VEHICLE
// =====================================================
DYN_fnc_purchaseVehicle = {
    params ["_classname", "_buyerUID"];
    if (!isServer) exitWith {false};
    
    private _found = false;
    private _cost = 0;
    private _name = "";
    private _cat = "";
    
    {
        _x params ["_class", "_dname", "_dcost", "_dcat"];
        if (_class == _classname) exitWith {
            _found = true;
            _cost = _dcost;
            _name = _dname;
            _cat = _dcat;
        };
    } forEach DYN_shopVehicles;
    
    if (!_found) exitWith {
        diag_log format ["[SHOP] Vehicle not found: %1", _classname];
        false
    };
    
    // Find the buyer player object
    private _buyer = objNull;
    {
        if (getPlayerUID _x == _buyerUID) exitWith { _buyer = _x; };
    } forEach allPlayers;
    
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    
    if (_rep < _cost) exitWith {
        diag_log format ["[SHOP] Not enough points: have %1 need %2", _rep, _cost];
        if (!isNull _buyer) then {
            ["SquadError", [format ["Not enough points! Need %1, have %2", _cost, _rep]]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };
    
    if (!isClass (configFile >> "CfgVehicles" >> _classname)) exitWith {
        diag_log format ["[SHOP] ERROR: Class %1 does not exist!", _classname];
        if (!isNull _buyer) then {
            ["SquadError", ["Vehicle class not found in loaded mods!"]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };
    
    // Get category-based spawn position
    private _spawnData = [_cat] call DYN_fnc_getSpawnPosByCategory;
    _spawnData params ["_spawnPos", "_spawnDir", "_errorMsg"];
    
    if (_errorMsg != "") exitWith {
        diag_log format ["[SHOP] Spawn error: %1", _errorMsg];
        if (!isNull _buyer) then {
            ["SquadError", [_errorMsg]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };
    
    if (_spawnPos isEqualTo [0,0,0]) exitWith {
        diag_log "[SHOP] No spawn position found";
        if (!isNull _buyer) then {
            ["SquadError", ["No spawn position available!"]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };
    
    // Deduct cost
    private _negCost = _cost * -1;
    [_negCost, format ["Purchased %1", _name]] call DYN_fnc_changeReputation;
    
    // Create vehicle — jets get +0.5 m Z offset to clear hangar floor and prevent clipping/explosion
    private _finalPos = if (_cat == "Jets") then { [_spawnPos#0, _spawnPos#1, (_spawnPos#2) + 0.5] } else { _spawnPos };
    private _veh = createVehicle [_classname, _finalPos, [], 0, "NONE"];

    if (isNull _veh) exitWith {
        diag_log "[SHOP] Failed to create vehicle — refunding points";
        [_cost, format ["Refund — %1 failed to spawn", _name]] call DYN_fnc_changeReputation;
        if (!isNull _buyer) then {
            ["SquadError", ["Failed to create vehicle — points refunded!"]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };
    
    _veh setDir _spawnDir;
    _veh setPos _finalPos;
    
    // === TRACK FOR PERSISTENCE ===
    if (!isNil "DYN_fnc_trackShopVehicle") then {
        [_veh, _cat] call DYN_fnc_trackShopVehicle;
    };
    
    diag_log format ["[SHOP] Spawned %1 (%2) at %3 dir %4 for %5 pts", _name, _cat, _spawnPos, _spawnDir, _cost];
    
    ["ShopPurchase", [format ["%1 requisitioned for %2 points", _name, _cost]]] remoteExec ["BIS_fnc_showNotification", 0];
        
    true
};
publicVariable "DYN_fnc_purchaseVehicle";

// =====================================================
// PURCHASE SUPPLY
// Spawns a supply crate at shop_spawn and fills it
// with the purchased ACE 3 item(s).
// =====================================================
DYN_fnc_purchaseSupply = {
    params ["_itemClass", "_buyerUID"];
    if (!isServer) exitWith {false};

    // Strip "SUPPLY:" prefix (7 chars)
    private _class = _itemClass select [7];

    private _found = false;
    private _cost = 0;
    private _name = "";
    private _qty  = 0;
    private _type = "item";

    {
        _x params ["_c", "_n", "_co", "_q", ["_tp", "item"]];
        if (_c == _class) exitWith {
            _found = true; _cost = _co; _name = _n; _qty = _q; _type = _tp;
        };
    } forEach DYN_shopSupplies;

    if (!_found) exitWith {
        diag_log format ["[SHOP] Supply item not found: %1", _class];
        false
    };

    private _buyer = objNull;
    { if (getPlayerUID _x == _buyerUID) exitWith { _buyer = _x; }; } forEach allPlayers;

    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];

    if (_rep < _cost) exitWith {
        if (!isNull _buyer) then {
            ["SquadError", [format ["Not enough points! Need %1, have %2", _cost, _rep]]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };

    // Only validate spawn-type entries (world objects must exist in CfgVehicles/CfgBackpacks).
    // Item-type entries are hand-curated and delivered via addItemCargoGlobal which handles
    // missing classes gracefully — no client-side mod check needed here.
    if (_type == "spawn" && { !(isClass (configFile >> "CfgBackpacks" >> _class)) && !(isClass (configFile >> "CfgVehicles" >> _class)) }) exitWith {
        diag_log format ["[SHOP] ERROR: Spawn class '%1' not found in CfgVehicles or CfgBackpacks", _class];
        if (!isNull _buyer) then {
            ["SquadError", [format ["Spawn class '%1' not found in loaded mods!", _class]]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
        false
    };

    // Deduct cost before spawning
    [_cost * -1, format ["Purchased %1", _name]] call DYN_fnc_changeReputation;

    // Drop to the right side of shop_spawn (marker direction + 90 degrees)
    private _spawnPos  = [] call DYN_fnc_getShopSpawnPos;
    private _rightDir  = (markerDir "shop_spawn") + 90;
    private _dropPos   = [(_spawnPos select 0) + (sin _rightDir) * 6, (_spawnPos select 1) + (cos _rightDir) * 6, 0];

    if (_type == "spawn") then {
        // Spawn the object directly (e.g. a supply crate or fuel can players can carry)
        private _obj = createVehicle [_class, _dropPos, [], 0, "NONE"];
        if (isNull _obj) then {
            [_cost, format ["Refund — %1 failed to spawn", _name]] call DYN_fnc_changeReputation;
            if (!isNull _buyer) then {
                ["SquadError", [format ["%1 failed to spawn — points refunded!", _name]]] remoteExec ["BIS_fnc_showNotification", _buyer];
            };
        } else {
            // Clear default contents so crate arrives empty
            clearWeaponCargoGlobal   _obj;
            clearMagazineCargoGlobal _obj;
            clearItemCargoGlobal     _obj;
            clearBackpackCargoGlobal _obj;
            // Lock so only ACE carry can move it (prevents vanilla drag/climb-in)
            _obj lock 2;
            // Mark as ACE-carryable so players can pick it up via ACE interact
            _obj setVariable ["ACE_isCarryable", true, true];
            [_obj] spawn { params ["_o"]; sleep 600; if (!isNull _o) then { deleteVehicle _o; }; };
            diag_log format ["[SHOP] Spawned %1 at %2 for %3 pts", _name, _dropPos, _cost];
        };
    } else {
        // "item" type — spawn a small crate at the drop position and fill it
        private _holder = createVehicle ["Box_NATO_Equip_F", _dropPos, [], 0, "NONE"];
        if (isNull _holder) then {
            [_cost, format ["Refund — %1 failed to spawn", _name]] call DYN_fnc_changeReputation;
            if (!isNull _buyer) then {
                ["SquadError", [format ["%1 failed to spawn — points refunded!", _name]]] remoteExec ["BIS_fnc_showNotification", _buyer];
            };
        } else {
            clearWeaponCargoGlobal   _holder;
            clearMagazineCargoGlobal _holder;
            clearItemCargoGlobal     _holder;
            clearBackpackCargoGlobal _holder;
            for "_i" from 1 to _qty do { _holder addItemCargoGlobal [_class, 1]; };
            [_holder] spawn { params ["_o"]; sleep 600; if (!isNull _o) then { deleteVehicle _o; }; };
            diag_log format ["[SHOP] Spawned %1 x%2 at %3 for %4 pts", _name, _qty, _dropPos, _cost];
        };
    };

    true
};
publicVariable "DYN_fnc_purchaseSupply";

diag_log "[SHOP] Vehicle Shop System Ready";