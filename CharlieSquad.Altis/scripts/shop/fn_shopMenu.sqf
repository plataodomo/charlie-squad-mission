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

DYN_shopSelectedClass = "";
DYN_shopCurrentFilter = "Cars";

// Get vehicle picture from config
DYN_fnc_getVehiclePicClient = {
    params ["_classname"];
    private _pic = getText (configFile >> "CfgVehicles" >> _classname >> "editorPreview");
    if (_pic == "") then {
        _pic = getText (configFile >> "CfgVehicles" >> _classname >> "picture");
    };
    if (_pic == "") then {
        _pic = "\A3\ui_f\data\map\markers\nato\b_unknown.paa";
    };
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
