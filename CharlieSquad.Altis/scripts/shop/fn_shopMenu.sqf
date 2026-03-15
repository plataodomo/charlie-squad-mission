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
waitUntil { !isNil "DYN_fnc_isActiveLeader" };

// =====================================================
// Also wait for the vehicle list to be broadcast from
// the server. DYN_shopVehicles is sent via publicVariable
// in fn_shopSystem.sqf but may not have arrived yet for
// a JIP player.
// =====================================================
waitUntil { !isNil "DYN_shopVehicles" };

_terminal addAction [
    "<t color='#00FF00'>Vehicle Requisition</t>",
    {
        if (!([player] call DYN_fnc_isActiveLeader)) exitWith {
            hint "Only active Squad Leaders and Acting Leaders can requisition vehicles.";
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
        };
        if (missionNamespace getVariable ["DYN_militia_active", false]) exitWith {
            hint "Friendly militia are already deployed! Wait for them to finish.";
        };
        if ((missionNamespace getVariable ["DYN_AO_center", [0,0,0]]) isEqualTo [0,0,0]) exitWith {
            hint "No active AO. Cannot deploy militia support.";
        };
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

DYN_fnc_shopFilter = {
    params ["_category"];
    DYN_shopCurrentFilter = _category;
    private _display = findDisplay 9600;
    if (isNull _display) exitWith {};
    private _list = _display displayCtrl 9603;
    lbClear _list;
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    {
        _x params ["_class", "_name", "_cost", "_cat"];
        if (!isClass (configFile >> "CfgVehicles" >> _class)) then {
            continue;
        };
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
        if (!isClass (configFile >> "CfgVehicles" >> _class)) then {
            continue;
        };
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
};

DYN_fnc_shopSelectVehicle = {
    private _display = findDisplay 9600;
    if (isNull _display) exitWith {};
    private _list = _display displayCtrl 9603;
    private _idx = lbCurSel _list;
    if (_idx < 0) exitWith {};
    private _class = _list lbData _idx;
    DYN_shopSelectedClass = _class;
    {
        _x params ["_vClass", "_name", "_cost", "_cat"];
        if (_vClass == _class) exitWith {
            private _pic = [_class] call DYN_fnc_getVehiclePicClient;
            (_display displayCtrl 9604) ctrlSetText _pic;
            (_display displayCtrl 9605) ctrlSetText _name;
            (_display displayCtrl 9606) ctrlSetText format ["Cost: %1 points", _cost];
            private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
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

DYN_fnc_shopBuy = {
    if (DYN_shopSelectedClass == "") exitWith {
        hint "Select a vehicle first!";
    };
    if (!([player] call DYN_fnc_isActiveLeader)) exitWith {
        hint "You are no longer an active Squad Leader.";
        closeDialog 0;
    };
    private _cost = 0;
    private _name = "";
    {
        _x params ["_class", "_dname", "_dcost"];
        if (_class == DYN_shopSelectedClass) exitWith {
            _cost = _dcost;
            _name = _dname;
        };
    } forEach DYN_shopVehicles;
    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    if (_rep < _cost) exitWith {
        hint format ["Not enough points!\nNeed: %1\nHave: %2", _cost, _rep];
    };
    [DYN_shopSelectedClass, getPlayerUID player] remoteExec ["DYN_fnc_purchaseVehicle", 2];
    closeDialog 0;
    hint format ["Requisitioning %1...", _name];
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

    // Reset all tier buttons: default bg, text color reflects affordability
    {
        _x params ["_idc", "_tierCost"];
        private _ctrl = _display displayCtrl _idc;
        _ctrl ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1];
        if (_rep >= _tierCost) then {
            _ctrl ctrlSetTextColor [0.85, 0.85, 0.85, 1];
        } else {
            _ctrl ctrlSetTextColor [0.40, 0.40, 0.40, 1];
        };
        _ctrl ctrlRemoveAllEventHandlers "MouseEnter";
        _ctrl ctrlRemoveAllEventHandlers "MouseExit";
        _ctrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.40, 0.40, 0.40, 1] }];
        _ctrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1] }];
    } forEach [[9752, 50], [9753, 90], [9754, 150]];

    // Highlight selected tier green; hover also stays green
    private _idc = switch (_tier) do {
        case "ROOKIE":  { 9752 };
        case "REGULAR": { 9753 };
        case "ELITE":   { 9754 };
        default         { 9752 };
    };
    private _selCtrl = _display displayCtrl _idc;
    _selCtrl ctrlSetBackgroundColor [0.18, 0.30, 0.18, 1];
    _selCtrl ctrlRemoveAllEventHandlers "MouseEnter";
    _selCtrl ctrlRemoveAllEventHandlers "MouseExit";
    _selCtrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.25, 0.42, 0.25, 1] }];
    _selCtrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.18, 0.30, 0.18, 1] }];

    // Reset balance label to green (clears any red error state from a previous attempt)
    private _balLbl = _display displayCtrl 9751;
    _balLbl ctrlSetText format ["%1 pts", _rep];
    _balLbl ctrlSetTextColor [0.4, 0.9, 0.4, 1];
};

DYN_fnc_militiaDialogOnLoad = {
    private _display = findDisplay 9750;
    if (isNull _display) exitWith {};

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

    // Reset all direction buttons
    {
        private _ctrl = _display displayCtrl _x;
        _ctrl ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1];
        _ctrl ctrlRemoveAllEventHandlers "MouseEnter";
        _ctrl ctrlRemoveAllEventHandlers "MouseExit";
        _ctrl ctrlAddEventHandler ["MouseEnter", { (_this select 0) ctrlSetBackgroundColor [0.32, 0.32, 0.32, 1] }];
        _ctrl ctrlAddEventHandler ["MouseExit",  { (_this select 0) ctrlSetBackgroundColor [0.20, 0.20, 0.20, 1] }];
    } forEach [9760, 9761, 9762, 9763];

    // Highlight selected direction button (blue)
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
    hint format ["Militia support purchased!\n%1 assaulting from %2 in 10 minutes.", _tier, _direction];
};

