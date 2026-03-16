/*
    scripts\shop\fn_shopMenu.sqf
    VEHICLE SHOP - CLIENT
    Laptop init: [this] execVM "scripts\shop\fn_shopMenu.sqf";
*/
params ["_terminal"];
if (!hasInterface) exitWith {};
if (isNull _terminal) exitWith {};

// =====================================================
// JIP FIX: Wait until squad functions are loaded before
// adding the action. Without this, a player who joins
// mid-mission could click the terminal before
// DYN_fnc_isActiveLeader is defined and get a script error.
// =====================================================
waitUntil { sleep 0.5; !isNil "DYN_fnc_isActiveLeader" };

// =====================================================
// Also wait for the vehicle list to be broadcast from
// the server. DYN_shopVehicles is sent via publicVariable
// in fn_shopSystem.sqf but may not have arrived yet for
// a JIP player.
// =====================================================
waitUntil { sleep 0.5; !isNil "DYN_shopVehicles" && !isNil "DYN_shopSupplies" };

_terminal addAction [
    "<t color='#00FF00'>Vehicle Requisition</t>",
    {
        if (!([player] call DYN_fnc_isActiveLeader)) exitWith {
            hint "Only active Squad Leaders and Acting Leaders can requisition vehicles.";
            [] spawn { sleep 5; hint ""; };
        };
        createDialog "DYN_ShopDialog";
    },
    nil,
    1.5,
    true,
    true,
    "",
    "true",
    5
];

_terminal addAction [
    "<t color='#88BBFF'>Militia Support</t>",
    {
        if (!([player] call DYN_fnc_isActiveLeader)) exitWith {
            hint "Only active Squad Leaders can request militia support.";
            [] spawn { sleep 5; hint ""; };
        };
        if (missionNamespace getVariable ["DYN_militia_active", false]) exitWith {};
        if ((missionNamespace getVariable ["DYN_AO_center", [0,0,0]]) isEqualTo [0,0,0]) exitWith {};
        createDialog "DYN_MilitiaDialog";
    },
    nil,
    1.4,
    true,
    true,
    "",
    "true",
    5
];

DYN_shopSelectedClass = "";
DYN_shopCurrentFilter = "Cars";

// Get vehicle picture from config
DYN_fnc_getVehiclePicClient = {
    params ["_classname"];
    private _cfg = configFile >> "CfgVehicles" >> _classname;
    private _pic = getText (_cfg >> "editorPreview");
    if (_pic == "") then { _pic = getText (_cfg >> "overviewPicture"); };
    if (_pic == "") then { _pic = getText (_cfg >> "picture"); };
    if (_pic == "") then { _pic = "\A3\ui_f\data\map\markers\nato\b_unknown.paa"; };
    _pic
};

DYN_fnc_shopFilter = {
    params ["_category"];
    DYN_shopCurrentFilter = _category;
    private _display = findDisplay 9600;
    if (isNull _display) exitWith {};
    private _list = _display displayCtrl 9603;
    lbClear _list;
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];

    if (_category == "Supplies") then {
        {
            _x params ["_class", "_name", "_cost", "_qty", ["_type", "item"]];
            // Only validate spawn-type entries (world objects); item/magazine types
            // are hand-curated in DYN_shopSupplies and validated server-side on purchase.
            if (_type == "spawn" && { !(isClass (configFile >> "CfgBackpacks" >> _class)) && !(isClass (configFile >> "CfgVehicles" >> _class)) }) then { continue; };
            private _idx = _list lbAdd _name;
            _list lbSetData [_idx, format ["SUPPLY:%1", _class]];
            _list lbSetTextRight [_idx, format ["%1 pts", _cost]];
            if (_rep >= _cost) then {
                _list lbSetColor [_idx, [1, 1, 1, 1]];
            } else {
                _list lbSetColor [_idx, [0.5, 0.5, 0.5, 0.5]];
            };
        } forEach DYN_shopSupplies;
    } else {
        {
            _x params ["_class", "_name", "_cost", "_cat"];
            if (!isClass (configFile >> "CfgVehicles" >> _class)) then { continue; };
            if (_category == _cat) then {
                private _idx = _list lbAdd _name;
                _list lbSetData [_idx, _class];
                _list lbSetTextRight [_idx, format ["%1 pts", _cost]];
                if (_rep >= _cost) then {
                    _list lbSetColor [_idx, [1, 1, 1, 1]];
                } else {
                    _list lbSetColor [_idx, [0.5, 0.5, 0.5, 0.5]];
                };
            };
        } forEach DYN_shopVehicles;
    };
};

DYN_fnc_shopOnLoad = {
    DYN_shopSelectedClass = "";
    DYN_shopCurrentFilter = "Cars";
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    private _display = findDisplay 9600;
    if (!isNull _display) then {
        (_display displayCtrl 9610) ctrlSetText format ["Points: %1", _rep];
    };
    ["Cars"] call DYN_fnc_shopFilter;
};

DYN_fnc_shopSearch = {
    private _display = findDisplay 9600;
    if (isNull _display) exitWith {};
    private _searchText = toLower (ctrlText (_display displayCtrl 9601));
    private _list = _display displayCtrl 9603;
    lbClear _list;
    if (_searchText == "") exitWith {
        [DYN_shopCurrentFilter] call DYN_fnc_shopFilter;
    };
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    {
        _x params ["_class", "_name", "_cost", "_cat"];
        if (!isClass (configFile >> "CfgVehicles" >> _class)) then { continue; };
        if ((toLower _name) find _searchText >= 0) then {
            private _idx = _list lbAdd _name;
            _list lbSetData [_idx, _class];
            _list lbSetTextRight [_idx, format ["%1 pts", _cost]];
            if (_rep >= _cost) then {
                _list lbSetColor [_idx, [1, 1, 1, 1]];
            } else {
                _list lbSetColor [_idx, [0.5, 0.5, 0.5, 0.5]];
            };
        };
    } forEach DYN_shopVehicles;
    {
        _x params ["_class", "_name", "_cost", "_qty", ["_type", "item"]];
        if (_type == "spawn" && { !(isClass (configFile >> "CfgBackpacks" >> _class)) && !(isClass (configFile >> "CfgVehicles" >> _class)) }) then { continue; };
        if ((toLower _name) find _searchText >= 0) then {
            private _idx = _list lbAdd _name;
            _list lbSetData [_idx, format ["SUPPLY:%1", _class]];
            _list lbSetTextRight [_idx, format ["%1 pts", _cost]];
            if (_rep >= _cost) then {
                _list lbSetColor [_idx, [1, 1, 1, 1]];
            } else {
                _list lbSetColor [_idx, [0.5, 0.5, 0.5, 0.5]];
            };
        };
    } forEach DYN_shopSupplies;
};

DYN_fnc_shopSelectVehicle = {
    private _display = findDisplay 9600;
    if (isNull _display) exitWith {};
    private _list = _display displayCtrl 9603;
    private _idx = lbCurSel _list;
    if (_idx < 0) exitWith {};
    private _class = _list lbData _idx;
    DYN_shopSelectedClass = _class;
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];

    if (_class find "SUPPLY:" == 0) then {
        // Supply item — look up in DYN_shopSupplies
        private _itemClass = _class select [7];
        {
            _x params ["_c", "_name", "_cost", "_qty", ["_type", "item"], ["_overridePic", ""]];
            if (_c == _itemClass) exitWith {
                private _pic = _overridePic;
                if (_pic == "") then {
                    if (_type == "spawn") then {
                        _pic = getText (configFile >> "CfgVehicles" >> _itemClass >> "editorPreview");
                        if (_pic == "") then { _pic = getText (configFile >> "CfgVehicles" >> _itemClass >> "overviewPicture"); };
                        if (_pic == "") then { _pic = getText (configFile >> "CfgVehicles" >> _itemClass >> "picture"); };
                        if (_pic == "") then { _pic = getText (configFile >> "CfgBackpacks" >> _itemClass >> "picture"); };
                    } else {
                        _pic = getText (configFile >> "CfgWeapons" >> _itemClass >> "picture");
                        if (_pic == "") then { _pic = getText (configFile >> "CfgMagazines" >> _itemClass >> "picture"); };
                    };
                };
                if (_pic == "") then { _pic = "\A3\ui_f\data\map\markers\nato\b_unknown.paa"; };
                (_display displayCtrl 9604) ctrlSetText _pic;
                (_display displayCtrl 9605) ctrlSetText _name;
                (_display displayCtrl 9606) ctrlSetText format ["Cost: %1 points", _cost];
                if (_rep >= _cost) then {
                    (_display displayCtrl 9607) ctrlSetText "AVAILABLE";
                    (_display displayCtrl 9607) ctrlSetTextColor [0.4, 0.9, 0.4, 1];
                } else {
                    (_display displayCtrl 9607) ctrlSetText format ["NEED %1 MORE POINTS", _cost - _rep];
                    (_display displayCtrl 9607) ctrlSetTextColor [0.9, 0.3, 0.3, 1];
                };
            };
        } forEach DYN_shopSupplies;
    } else {
        // Vehicle item — existing logic
        {
            _x params ["_vClass", "_name", "_cost", "_cat"];
            if (_vClass == _class) exitWith {
                private _pic = [_class] call DYN_fnc_getVehiclePicClient;
                (_display displayCtrl 9604) ctrlSetText _pic;
                (_display displayCtrl 9605) ctrlSetText _name;
                (_display displayCtrl 9606) ctrlSetText format ["Cost: %1 points", _cost];
                if (_rep >= _cost) then {
                    (_display displayCtrl 9607) ctrlSetText "AVAILABLE";
                    (_display displayCtrl 9607) ctrlSetTextColor [0.4, 0.9, 0.4, 1];
                } else {
                    (_display displayCtrl 9607) ctrlSetText format ["NEED %1 MORE POINTS", _cost - _rep];
                    (_display displayCtrl 9607) ctrlSetTextColor [0.9, 0.3, 0.3, 1];
                };
            };
        } forEach DYN_shopVehicles;
    };
};

DYN_fnc_shopBuy = {
    if (DYN_shopSelectedClass == "") exitWith {
        hint "Select an item first!";
    };
    if (!([player] call DYN_fnc_isActiveLeader)) exitWith {
        hint "You are no longer an active Squad Leader.";
        closeDialog 0;
    };
    private _isSupply = DYN_shopSelectedClass find "SUPPLY:" == 0;
    private _cost = 0;
    private _name = "";
    if (_isSupply) then {
        private _itemClass = DYN_shopSelectedClass select [7];
        {
            _x params ["_c", "_n", "_co"];
            if (_c == _itemClass) exitWith { _cost = _co; _name = _n; };
        } forEach DYN_shopSupplies;
    } else {
        {
            _x params ["_class", "_dname", "_dcost"];
            if (_class == DYN_shopSelectedClass) exitWith { _cost = _dcost; _name = _dname; };
        } forEach DYN_shopVehicles;
    };
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    if (_rep < _cost) exitWith {
        hint format ["Not enough points!\nNeed: %1\nHave: %2", _cost, _rep];
    };
    if (_isSupply) then {
        [DYN_shopSelectedClass, getPlayerUID player] remoteExec ["DYN_fnc_purchaseSupply", 2];
        closeDialog 0;
    } else {
        [DYN_shopSelectedClass, getPlayerUID player] remoteExec ["DYN_fnc_purchaseVehicle", 2];
        closeDialog 0;
        hint format ["Requisitioning %1...", _name];
    };
};

// =====================================================
// MILITIA SUPPORT — CLIENT
// =====================================================

DYN_fnc_militiaSelectTier = {
    params ["_tier"];
    // uiNamespace so each client keeps its own selection (not a shared global)
    uiNamespace setVariable ["DYN_militia_tier", _tier];
    private _display = findDisplay 9750;
    if (isNull _display) exitWith {};

    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];

    // Reset all tier buttons: base bg + grey hover EHs; text dim if unaffordable
    {
        _x params ["_idc", "_tierCost"];
        private _ctrl = _display displayCtrl _idc;
        _ctrl ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1];
        _ctrl ctrlRemoveAllEventHandlers "MouseEnter";
        _ctrl ctrlRemoveAllEventHandlers "MouseExit";
        _ctrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.30, 0.30, 0.30, 1] }];
        _ctrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1] }];
        if (_rep >= _tierCost) then {
            _ctrl ctrlSetTextColor [0.85, 0.85, 0.85, 1];
        } else {
            _ctrl ctrlSetTextColor [0.40, 0.40, 0.40, 1];
        };
    } forEach [[9752, 50], [9753, 90], [9754, 150]];

    // Highlight selected tier blue; hover stays blue (consistent with direction buttons)
    private _idc = switch (_tier) do {
        case "ROOKIE":  { 9752 };
        case "REGULAR": { 9753 };
        case "ELITE":   { 9754 };
        default         { 9752 };
    };
    private _selCtrl = _display displayCtrl _idc;
    _selCtrl ctrlSetBackgroundColor [0.15, 0.25, 0.40, 1];
    _selCtrl ctrlRemoveAllEventHandlers "MouseEnter";
    _selCtrl ctrlRemoveAllEventHandlers "MouseExit";
    _selCtrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.22, 0.35, 0.55, 1] }];
    _selCtrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.15, 0.25, 0.40, 1] }];

    // Reset balance label to green (clears any red error state from a previous attempt)
    private _balLbl = _display displayCtrl 9751;
    _balLbl ctrlSetText format ["%1 pts", _rep];
    _balLbl ctrlSetTextColor [0.4, 0.9, 0.4, 1];
};

DYN_fnc_militiaDialogOnLoad = {
    private _display = findDisplay 9750;
    if (isNull _display) exitWith {};

    // Balance label — set directly here as a safety net before tier selection runs
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    (_display displayCtrl 9751) ctrlSetText format ["%1 pts", _rep];
    (_display displayCtrl 9751) ctrlSetTextColor [0.4, 0.9, 0.4, 1];

    // Clear any direction selected in a previous session
    uiNamespace setVariable ["DYN_militia_direction", ""];

    // Direction label and deploy button start in a blank/disabled state
    (_display displayCtrl 9756) ctrlSetText "—";
    (_display displayCtrl 9755) ctrlEnable false;

    // Default tier; this also sets the balance label and affordability colours
    ["ROOKIE"] call DYN_fnc_militiaSelectTier;
};

// Direction buttons call this — stores selection and highlights the button; no purchase yet.
DYN_fnc_militiaSelectDirection = {
    params ["_direction"];
    uiNamespace setVariable ["DYN_militia_direction", _direction];
    private _display = findDisplay 9750;
    if (isNull _display) exitWith {};

    // Reset all direction buttons: base bg + grey hover EHs
    {
        private _ctrl = _display displayCtrl _x;
        _ctrl ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1];
        _ctrl ctrlRemoveAllEventHandlers "MouseEnter";
        _ctrl ctrlRemoveAllEventHandlers "MouseExit";
        _ctrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.32, 0.32, 0.32, 1] }];
        _ctrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1] }];
    } forEach [9760, 9761, 9762, 9763];

    // Highlight selected direction button (blue); hover stays blue
    private _idc = switch (_direction) do {
        case "NORTH": { 9760 };
        case "WEST":  { 9761 };
        case "EAST":  { 9762 };
        case "SOUTH": { 9763 };
        default       { -1 };
    };
    if (_idc > 0) then {
        private _selCtrl = _display displayCtrl _idc;
        _selCtrl ctrlSetBackgroundColor [0.15, 0.25, 0.40, 1];
        _selCtrl ctrlRemoveAllEventHandlers "MouseEnter";
        _selCtrl ctrlRemoveAllEventHandlers "MouseExit";
        _selCtrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.22, 0.35, 0.55, 1] }];
        _selCtrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.15, 0.25, 0.40, 1] }];
    };

    // Update direction label and unlock the deploy button
    (_display displayCtrl 9756) ctrlSetText format ["DIRECTION: %1", _direction];
    (_display displayCtrl 9755) ctrlEnable true;
};

// DEPLOY button calls this — validates and fires the purchase.
DYN_fnc_militiaDeploy = {
    private _tier      = uiNamespace getVariable ["DYN_militia_tier",      "ROOKIE"];
    private _direction = uiNamespace getVariable ["DYN_militia_direction", ""];
    private _cost = switch (_tier) do {
        case "ROOKIE":  {  50 };
        case "REGULAR": {  90 };
        case "ELITE":   { 150 };
        default         {  50 };
    };
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    if (_rep < _cost) exitWith {
        private _display = findDisplay 9750;
        if (!isNull _display) then {
            private _lbl = _display displayCtrl 9751;
            _lbl ctrlSetText format ["Need %1 pts — have %2", _cost, _rep];
            _lbl ctrlSetTextColor [0.9, 0.2, 0.2, 1];
        };
    };
    closeDialog 0;
    [getPlayerUID player, _direction, _tier] remoteExec ["DYN_fnc_purchaseMilitia", 2];
    hint format ["Militia support purchased!\n%1 assaulting from %2 in 20 seconds.", _tier, _direction];
};

