/*
    scripts\fn_squadMenu.sqf
    GROUP MANAGEMENT - MULTIPLAYER COMPATIBLE
    UPDATED: Slot-based role detection using roleDescription, group leak fixes, deterministic acting leader
*/

if (!hasInterface) exitWith {};

// =====================================================
// CONFIG
// =====================================================

DYN_SQUAD_NAMES = ["ALPHA", "BRAVO", "CHARLIE", "DELTA", "ECHO", "FOXTROT", "GOLF", "HOTEL"];
DYN_SQUAD_MAX_SIZE = 11;

// Role icon for player list
DYN_ROLE_ICON = "\A3\Ui_f\data\GUI\Cfg\Ranks\private_gs.paa";

DYN_ROLE_COLORS = createHashMapFromArray [
    ["SL",    [0.40, 0.90, 0.40, 1]],
    ["TL",    [0.30, 0.85, 0.55, 1]],
    ["MEDIC", [0.40, 0.85, 0.95, 1]],
    ["LAT",   [0.95, 0.55, 0.45, 1]],
    ["ENG",   [0.95, 0.80, 0.30, 1]],
    ["SNP",   [0.35, 0.70, 0.65, 1]],
    ["SPT",   [0.60, 0.75, 0.60, 1]],
    ["RFL",   [0.80, 0.80, 0.80, 1]]
];

DYN_ROLE_NAMES = createHashMapFromArray [
    ["SL",    "SQUAD LEADERS"],
    ["TL",    "TEAM LEADERS"],
    ["MEDIC", "MEDICS"],
    ["LAT",   "ANTI-TANK"],
    ["ENG",   "ENGINEERS"],
    ["SNP",   "SNIPERS"],
    ["SPT",   "SPOTTERS"],
    ["RFL",   "RIFLEMEN"]
];

DYN_ROLE_ORDER = ["SL", "TL", "MEDIC", "LAT", "ENG", "SNP", "SPT", "RFL"];

// State
if (isNil "DYN_pendingInvites") then { DYN_pendingInvites = []; };
if (isNil "DYN_expandedSquads") then { DYN_expandedSquads = []; };
if (isNil "DYN_expandedRoles") then { DYN_expandedRoles = []; };
if (isNil "DYN_squadListData") then { DYN_squadListData = []; };
if (isNil "DYN_ungroupedListData") then { DYN_ungroupedListData = []; };
if (isNil "DYN_cacheHash") then { DYN_cacheHash = ""; };
if (isNil "DYN_lastActingLeader") then { DYN_lastActingLeader = objNull; };

// =====================================================
// NOTIFICATION SYSTEM
// =====================================================

DYN_fnc_notifyLocal = {
    params ["_type", "_message"];
    [_type, [_message]] call BIS_fnc_showNotification;
};

DYN_fnc_notifyPlayer = {
    params ["_target", "_type", "_message"];
    if (isNull _target) exitWith {};
    [_type, _message] remoteExec ["DYN_fnc_notifyLocal", _target];
};

DYN_fnc_notifySquad = {
    params ["_grp", "_type", "_message", ["_exclude", objNull]];
    if (isNull _grp) exitWith {};
    {
        if (isPlayer _x && _x != _exclude) then {
            [_x, _type, _message] call DYN_fnc_notifyPlayer;
        };
    } forEach units _grp;
};

// =====================================================
// NOTIFICATION WRAPPERS
// =====================================================

DYN_fnc_notifySquadCreated = {
    params ["_squadName"];
    ["SquadCreated", format ["You are now leading %1", _squadName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifySquadJoined = {
    params ["_squadName"];
    ["SquadJoined", format ["Welcome to %1", _squadName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifySquadLeft = {
    params ["_squadName"];
    ["SquadLeft", format ["You left %1", _squadName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifySquadDisbanded = {
    params ["_squadName"];
    ["SquadDisbanded", format ["%1 no longer exists", _squadName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifySquadKicked = {
    params ["_squadName"];
    ["SquadKicked", format ["You were removed from %1", _squadName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifySquadInvite = {
    params ["_fromName", "_squadName"];
    ["SquadInvite", format ["%1 invites you to %2 | Press U", _fromName, _squadName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyInviteSent = {
    params ["_targetName"];
    ["SquadInviteSent", format ["Invitation sent to %1", _targetName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyPromotedToSL = {
    ["SquadPromoted", "You are now Squad Leader"] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyPromotedToAL = {
    ["SquadActingLeader", "Squad Leader is down. You have tactical command."] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifySLResumed = {
    ["SquadSLActive", "Squad Leader has resumed command"] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyMemberJoined = {
    params ["_memberName"];
    ["SquadMemberJoined", format ["%1 joined the squad", _memberName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyMemberLeft = {
    params ["_memberName"];
    ["SquadMemberLeft", format ["%1 left the squad", _memberName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyMemberKicked = {
    params ["_memberName"];
    ["SquadMemberKicked", format ["%1 was removed", _memberName]] call DYN_fnc_notifyLocal;
};

DYN_fnc_notifyError = {
    params ["_reason"];
    ["SquadError", _reason] call DYN_fnc_notifyLocal;
};

// =====================================================
// HELPER FUNCTIONS
// =====================================================

DYN_fnc_getPlayerStatus = {
    params ["_unit"];
    if (isNull _unit) exitWith { "DEAD" };
    if (!alive _unit) exitWith { "DEAD" };
    if (_unit getVariable ["ACE_isUnconscious", false]) exitWith { "DOWN" };
    if (lifeState _unit == "INCAPACITATED") exitWith { "DOWN" };
    "OK"
};

// =====================================================
// ROLE DETECTION — Based on editor roleDescription (primary)
// Falls back to classname/displayName if roleDescription is empty
//
// Editor slots:
//   Rifleman@Rifleman           -> RFL
//   Engineer@Engineer           -> ENG
//   Team Leader@Squad Leader    -> TL
//   Medic@Medic                 -> MEDIC
//   Sniper@Recon                -> SNP
//   Spotter@Recon               -> SPT
//   Light Anti-Tank@Light Anti-Tank -> LAT
// =====================================================

DYN_fnc_getPlayerRole = {
    params ["_unit"];
    if (isNull _unit) exitWith { "RFL" };

    // Primary detection: roleDescription set in the editor
    // Format is "Role@Group" — we parse the part BEFORE the @ sign
    private _roleDesc = roleDescription _unit;
    private _rolePart = _roleDesc;
    private _atIndex = _roleDesc find "@";
    if (_atIndex >= 0) then {
        _rolePart = _roleDesc select [0, _atIndex];
    };
    _rolePart = toUpper _rolePart;

    // Check roleDescription first
    if (_rolePart != "") exitWith {
        // Order matters: check specific roles before generic ones

        // TEAM LEADER — check before generic "leader" matches
        if ("TEAM LEADER" in _rolePart) exitWith { "TL" };

        // MEDIC
        if ("MEDIC" in _rolePart || "CORPSMAN" in _rolePart || "COMBAT AID" in _rolePart) exitWith { "MEDIC" };

        // LIGHT ANTI-TANK / ANTI-TANK
        if ("ANTI-TANK" in _rolePart || "ANTI TANK" in _rolePart || "LAT" in _rolePart || "ANTITANK" in _rolePart) exitWith { "LAT" };

        // ENGINEER
        if ("ENGINEER" in _rolePart || "EOD" in _rolePart || "DEMOLITION" in _rolePart || "SAPPER" in _rolePart) exitWith { "ENG" };

        // SNIPER
        if ("SNIPER" in _rolePart || "MARKSMAN" in _rolePart || "SHARPSHOOTER" in _rolePart) exitWith { "SNP" };

        // SPOTTER
        if ("SPOTTER" in _rolePart || "OBSERVER" in _rolePart || "JTAC" in _rolePart) exitWith { "SPT" };

        // SQUAD LEADER — only if explicitly named in roleDescription
        if ("SQUAD LEADER" in _rolePart) exitWith { "SL" };

        // RIFLEMAN (explicit or anything else)
        "RFL"
    };

    // Fallback: classname and config displayName
    private _className   = toLower (typeOf _unit);
    private _displayName = toUpper (getText (configFile >> "CfgVehicles" >> typeOf _unit >> "displayName"));

    // TEAM LEADER — before SL to avoid false match
    if (
        ("_tl_" in _className) ||
        ("_ftl_" in _className) ||
        ("teamlead" in _className) ||
        ("fireteamlead" in _className) ||
        ("TEAM LEAD" in _displayName) ||
        ("FIRE TEAM LEAD" in _displayName)
    ) exitWith { "TL" };

    // SQUAD LEADER
    if (
        ("_sl_" in _className) ||
        ("squadleader" in _className) ||
        ("SQUAD LEAD" in _displayName)
    ) exitWith { "SL" };

    // MEDIC
    if (
        ("medic" in _className) ||
        ("_cls_" in _className) ||
        ("_cls" in _className) ||
        ("corpsman" in _className) ||
        ("MEDIC" in _displayName) ||
        ("CORPSMAN" in _displayName) ||
        (_unit getUnitTrait "Medic")
    ) exitWith { "MEDIC" };

    // LIGHT ANTI-TANK
    if (
        ("_lat_" in _className) ||
        ("_lat2" in _className) ||
        ("_at_" in _className) ||
        ("_hat_" in _className) ||
        ("_mat_" in _className) ||
        ("_aa_" in _className) ||
        ("javelin" in _className) ||
        ("maaws" in _className) ||
        ("stinger" in _className) ||
        ("ANTI-TANK" in _displayName) ||
        ("ANTITANK" in _displayName) ||
        ("ANTI-AIR" in _displayName) ||
        ("(AT)" in _displayName) ||
        ("(AA)" in _displayName) ||
        ("LAUNCHER" in _displayName)
    ) exitWith { "LAT" };

    // ENGINEER
    if (
        ("engineer" in _className) ||
        ("_eng_" in _className) ||
        ("_repair_" in _className) ||
        ("_exp_" in _className) ||
        ("sapper" in _className) ||
        ("ENGINEER" in _displayName) ||
        ("EXPLOSIVE" in _displayName) ||
        ("DEMOLITION" in _displayName) ||
        ("SAPPER" in _displayName) ||
        ("EOD" in _displayName) ||
        (_unit getUnitTrait "Engineer")
    ) exitWith { "ENG" };

    // SNIPER
    if (
        ("sniper" in _className) ||
        ("_snp_" in _className) ||
        ("sharpshooter" in _className) ||
        ("marksman" in _className) ||
        ("ghillie" in _className) ||
        ("SNIPER" in _displayName) ||
        ("SHARPSHOOTER" in _displayName) ||
        ("MARKSMAN" in _displayName)
    ) exitWith { "SNP" };

    // SPOTTER
    if (
        ("spotter" in _className) ||
        ("_spt_" in _className) ||
        ("observer" in _className) ||
        ("_jtac" in _className) ||
        ("_fac_" in _className) ||
        ("SPOTTER" in _displayName) ||
        ("OBSERVER" in _displayName) ||
        ("JTAC" in _displayName) ||
        ("FORWARD AIR" in _displayName)
    ) exitWith { "SPT" };

    // DEFAULT
    "RFL"
};

DYN_fnc_getRoleColor = {
    params ["_role"];
    DYN_ROLE_COLORS getOrDefault [_role, [0.80, 0.80, 0.80, 1]]
};

DYN_fnc_getRoleName = {
    params ["_role"];
    DYN_ROLE_NAMES getOrDefault [_role, "RIFLEMEN"]
};

DYN_fnc_isInCustomSquad = {
    params ["_unit"];
    (group _unit) getVariable ["DYN_isCustomSquad", false]
};

DYN_fnc_getActingLeader = {
    params ["_grp"];
    if (isNull _grp) exitWith { objNull };

    private _leader = leader _grp;
    private _leaderStatus = [_leader] call DYN_fnc_getPlayerStatus;

    if (_leaderStatus == "OK") exitWith {
        _grp setVariable ["DYN_actingLeader", nil, true];
        _leader
    };

    private _available = (units _grp) select { isPlayer _x && (([_x] call DYN_fnc_getPlayerStatus) == "OK") };
    if (count _available == 0) exitWith { _leader };

    private _currentActing = _grp getVariable ["DYN_actingLeader", objNull];
    if (!isNull _currentActing && {_currentActing in _available} && {([_currentActing] call DYN_fnc_getPlayerStatus) == "OK"}) exitWith { _currentActing };

    // Deterministic: sort by UID so every client picks the same player
    _available = [_available, [], {getPlayerUID _x}, "ASCEND"] call BIS_fnc_sortBy;
    private _newActing = _available select 0;
    _grp setVariable ["DYN_actingLeader", _newActing, true];
    _newActing
};

DYN_fnc_getPlayerColor = {
    params ["_unit", ["_isYou", false], ["_isLeader", false], ["_isActing", false]];

    private _status = [_unit] call DYN_fnc_getPlayerStatus;
    private _role = [_unit] call DYN_fnc_getPlayerRole;

    if (_status == "DOWN") exitWith { [0.90, 0.35, 0.35, 1] };
    if (_status == "DEAD") exitWith { [0.60, 0.30, 0.30, 1] };
    if (_isYou && _isLeader) exitWith { [0.35, 0.95, 0.35, 1] };
    if (_isYou && _isActing) exitWith { [0.95, 0.85, 0.30, 1] };
    if (_isYou) exitWith {
        private _roleColor = [_role] call DYN_fnc_getRoleColor;
        [(_roleColor#0 + 0.15) min 1, (_roleColor#1 + 0.15) min 1, (_roleColor#2 + 0.15) min 1, 1]
    };
    if (_isActing) exitWith { [0.90, 0.70, 0.25, 1] };
    [_role] call DYN_fnc_getRoleColor
};

// =====================================================
// ACTIVE LEADERSHIP CHECK
// =====================================================

DYN_fnc_isActiveLeader = {
    params ["_unit"];
    if (isNull _unit) exitWith { false };
    if (!alive _unit) exitWith { false };

    if (!([_unit] call DYN_fnc_isInCustomSquad)) exitWith { false };

    if (leader group _unit == _unit) exitWith { true };

    private _grp = group _unit;
    private _actingLeader = [_grp] call DYN_fnc_getActingLeader;
    if (_actingLeader == _unit && _actingLeader != leader _grp) exitWith { true };

    false
};

// =====================================================
// ACTING LEADER MONITOR
// =====================================================

DYN_fnc_startActingLeaderMonitor = {
    if (!isNil "DYN_actingLeaderMonitorRunning") exitWith {};
    DYN_actingLeaderMonitorRunning = true;

    [] spawn {
        while {true} do {
            sleep 2;

            if (!([player] call DYN_fnc_isInCustomSquad)) then {
                DYN_lastActingLeader = objNull;
            } else {
                private _grp = group player;
                private _squadLeader = leader _grp;
                private _slStatus = [_squadLeader] call DYN_fnc_getPlayerStatus;
                private _actingLeader = [_grp] call DYN_fnc_getActingLeader;

                if (_actingLeader == player && _actingLeader != _squadLeader && _slStatus == "DOWN") then {
                    if (DYN_lastActingLeader != player) then {
                        DYN_lastActingLeader = player;
                        [] call DYN_fnc_notifyPromotedToAL;
                    };
                } else {
                    if (DYN_lastActingLeader == player && _slStatus == "OK" && _squadLeader != player) then {
                        DYN_lastActingLeader = objNull;
                        [] call DYN_fnc_notifySLResumed;
                    };
                };
            };
        };
    };
};

[] call DYN_fnc_startActingLeaderMonitor;

// =====================================================
// MENU FUNCTIONS
// =====================================================

DYN_fnc_openSquadMenu = {
    if (!isNull findDisplay 9500) then { closeDialog 0; } else { createDialog "DYN_SquadMenu"; };
};

DYN_fnc_squadMenuInit = {
    disableSerialization;

    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    DYN_cacheHash = "";
    DYN_squadListData = [];
    DYN_ungroupedListData = [];

    private _nameCombo = _display displayCtrl 9512;
    lbClear _nameCombo;
    { _nameCombo lbAdd _x; } forEach DYN_SQUAD_NAMES;
    _nameCombo lbSetCurSel 0;

    (_display displayCtrl 9561) ctrlShow false;
    (_display displayCtrl 9562) ctrlShow false;

    (_display displayCtrl 9502) ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_index"];
        if (_index >= 0 && _index < count DYN_ungroupedListData) then {
            private _rowData = DYN_ungroupedListData#_index;
            if (_rowData#0 == "ROLE_HEADER") then {
                private _roleName = _rowData#1;
                if (_roleName in DYN_expandedRoles) then { DYN_expandedRoles = DYN_expandedRoles - [_roleName]; }
                else { DYN_expandedRoles pushBackUnique _roleName; };
                DYN_cacheHash = "";
                [] call DYN_fnc_refreshUngroupedList;
            };
        };
        [] call DYN_fnc_refreshButtons;
    }];

    (_display displayCtrl 9511) ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_index"];
        if (_index >= 0 && _index < count DYN_squadListData) then {
            private _rowData = DYN_squadListData#_index;
            if (_rowData#0 == "HEADER") then {
                private _squadName = _rowData#1;
                if (_squadName in DYN_expandedSquads) then { DYN_expandedSquads = DYN_expandedSquads - [_squadName]; }
                else { DYN_expandedSquads pushBackUnique _squadName; };
                DYN_cacheHash = "";
                [] call DYN_fnc_refreshSquadList;
            };
        };
        [] call DYN_fnc_refreshButtons;
    }];

    (_display displayCtrl 9525) ctrlAddEventHandler ["LBSelChanged", { [] call DYN_fnc_refreshButtons; }];

    [] call DYN_fnc_fullMenuRefresh;

    [] spawn {
        disableSerialization;
        while { !isNull findDisplay 9500 } do { sleep 1; [] call DYN_fnc_smartMenuRefresh; };
    };
};

// =====================================================
// HASH & REFRESH
// =====================================================

DYN_fnc_buildDataHash = {
    private _hash = "";
    { if (!([_x] call DYN_fnc_isInCustomSquad) && (side group _x == playerSide) && alive _x) then {
        _hash = _hash + (getPlayerUID _x) + ([_x] call DYN_fnc_getPlayerStatus) + ([_x] call DYN_fnc_getPlayerRole);
    }; } forEach allPlayers;

    { if ((side _x == playerSide) && (_x getVariable ["DYN_isCustomSquad", false])) then {
        _hash = _hash + (_x getVariable ["DYN_squadName", ""]);
        _hash = _hash + str({ isPlayer _x && alive _x } count units _x) + str(_x getVariable ["DYN_squadLocked", false]);
        _hash = _hash + ([leader _x] call DYN_fnc_getPlayerStatus);
        if ((_x getVariable ["DYN_squadName", ""]) in DYN_expandedSquads) then {
            { if (isPlayer _x && alive _x) then { _hash = _hash + (getPlayerUID _x) + ([_x] call DYN_fnc_getPlayerStatus) + ([_x] call DYN_fnc_getPlayerRole); }; } forEach units _x;
        };
    }; } forEach allGroups;

    if ([player] call DYN_fnc_isInCustomSquad) then {
        { if (isPlayer _x && alive _x) then { _hash = _hash + (getPlayerUID _x) + ([_x] call DYN_fnc_getPlayerStatus) + ([_x] call DYN_fnc_getPlayerRole); }; } forEach units group player;
    };

    _hash + str(DYN_expandedRoles) + str(count DYN_pendingInvites)
};

DYN_fnc_smartMenuRefresh = {
    private _newHash = [] call DYN_fnc_buildDataHash;
    if (_newHash != DYN_cacheHash) then { DYN_cacheHash = _newHash; [] call DYN_fnc_fullMenuRefresh; };
};

DYN_fnc_fullMenuRefresh = {
    disableSerialization;
    if (isNull findDisplay 9500) exitWith {};
    [] call DYN_fnc_refreshVisibility;
    [] call DYN_fnc_refreshUngroupedList;
    [] call DYN_fnc_refreshSquadList;
    [] call DYN_fnc_refreshYourSquad;
    [] call DYN_fnc_refreshButtons;
    [] call DYN_fnc_refreshInvites;
};

// =====================================================
// VISIBILITY
// =====================================================

DYN_fnc_refreshVisibility = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _inSquad = [player] call DYN_fnc_isInCustomSquad;
    private _isLeader = leader group player == player;

    { (_display displayCtrl _x) ctrlShow (!_inSquad); } forEach [9540, 9512, 9513];
    { (_display displayCtrl _x) ctrlShow (_inSquad && _isLeader); } forEach [9534, 9535, 9514, 9536, 9530];
    (_display displayCtrl 9533) ctrlShow _inSquad;
    (_display displayCtrl 9532) ctrlShow (!_inSquad);
};

// =====================================================
// UNGROUPED LIST
// =====================================================

DYN_fnc_refreshUngroupedList = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _list = _display displayCtrl 9502;
    lnbClear _list;
    DYN_ungroupedListData = [];

    private _ungrouped = allPlayers select { !([_x] call DYN_fnc_isInCustomSquad) && (side group _x == playerSide) && alive _x };

    private _roleGroups = createHashMap;
    {
        private _role = [_x] call DYN_fnc_getPlayerRole;
        private _arr = _roleGroups getOrDefault [_role, []];
        _arr pushBack _x;
        _roleGroups set [_role, _arr];
    } forEach _ungrouped;

    {
        private _role = _x;
        private _players = _roleGroups getOrDefault [_role, []];

        if (count _players > 0) then {
            private _roleName = [_role] call DYN_fnc_getRoleName;
            private _roleColor = [_role] call DYN_fnc_getRoleColor;
            private _isExpanded = _role in DYN_expandedRoles;

            private _headerText = format ["%1 (%2)", _roleName, count _players];

            private _row = _list lnbAddRow ["", _headerText];
            _list lnbSetColor [[_row, 1], _roleColor];
            DYN_ungroupedListData pushBack ["ROLE_HEADER", _role, objNull];

            if (_isExpanded) then {
                _players = [_players, [], { name _x }, "ASCEND"] call BIS_fnc_sortBy;
                {
                    private _unit = _x;
                    private _name = name _unit;
                    private _status = [_unit] call DYN_fnc_getPlayerStatus;
                    private _isYou = _unit == player;
                    private _unitRole = [_unit] call DYN_fnc_getPlayerRole;

                    private _displayName = _name;
                    if (_status == "DOWN") then { _displayName = _displayName + " [DOWN]"; };

                    private _textColor = [_unit, _isYou, false, false] call DYN_fnc_getPlayerColor;
                    private _iconColor = [_unitRole] call DYN_fnc_getRoleColor;

                    private _row = _list lnbAddRow ["", _displayName];
                    _list lnbSetPicture [[_row, 0], DYN_ROLE_ICON];
                    _list lnbSetColor [[_row, 0], _iconColor];
                    _list lnbSetColor [[_row, 1], _textColor];
                    _list lnbSetData [[_row, 0], getPlayerUID _unit];
                    DYN_ungroupedListData pushBack ["PLAYER", _role, _unit];
                } forEach _players;
            };
        };
    } forEach DYN_ROLE_ORDER;

    (_display displayCtrl 9501) ctrlSetText str(count _ungrouped);
};

// =====================================================
// SQUAD LIST
// =====================================================

DYN_fnc_refreshSquadList = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _list = _display displayCtrl 9511;
    lnbClear _list;
    DYN_squadListData = [];

    private _squads = allGroups select { (side _x == playerSide) && (_x getVariable ["DYN_isCustomSquad", false]) && ({ isPlayer _x && alive _x } count units _x >= 1) };
    _squads = [_squads, [], { if (_x == group player) then { "!!" } else { _x getVariable ["DYN_squadName", "ZZ"] } }, "ASCEND"] call BIS_fnc_sortBy;

    {
        private _grp = _x;
        private _squadName = _grp getVariable ["DYN_squadName", "SQUAD"];
        private _memberCount = { isPlayer _x && alive _x } count units _grp;
        private _isLocked = _grp getVariable ["DYN_squadLocked", false];
        private _isYourSquad = _grp == group player;
        private _isExpanded = _squadName in DYN_expandedSquads;

        private _headerText = if (_isLocked) then {
            format ["%1 %2/%3 [LOCKED]", _squadName, _memberCount, DYN_SQUAD_MAX_SIZE]
        } else {
            format ["%1 %2/%3", _squadName, _memberCount, DYN_SQUAD_MAX_SIZE]
        };

        private _headerColor = switch (true) do {
            case (_isYourSquad): { [0.40, 0.90, 0.40, 1] };
            case (_isLocked): { [0.75, 0.50, 0.50, 1] };
            default { [0.80, 0.80, 0.80, 1] };
        };

        private _row = _list lnbAddRow ["", _headerText];
        _list lnbSetColor [[_row, 1], _headerColor];
        DYN_squadListData pushBack ["HEADER", _squadName, _grp];

        if (_isExpanded) then {
            private _members = (units _grp) select { isPlayer _x && alive _x };
            private _squadLeader = leader _grp;
            private _actingLeader = [_grp] call DYN_fnc_getActingLeader;

            _members = [_members, [], {
                if (_x == _squadLeader) then { "!!!" } else {
                    private _r = [_x] call DYN_fnc_getPlayerRole;
                    private _i = DYN_ROLE_ORDER find _r;
                    format ["%1%2", if (_i < 0) then { 99 } else { _i }, name _x]
                }
            }, "ASCEND"] call BIS_fnc_sortBy;

            {
                private _unit = _x;
                private _role = [_unit] call DYN_fnc_getPlayerRole;
                private _status = [_unit] call DYN_fnc_getPlayerStatus;
                private _isLeader = _unit == _squadLeader;
                private _isActing = (_unit == _actingLeader) && (_actingLeader != _squadLeader);
                private _isYou = _unit == player;

                private _suffix = "";
                if (_isLeader) then { _suffix = " [SL]"; };
                if (_isActing) then { _suffix = " [AL]"; };
                if (_status == "DOWN") then { _suffix = _suffix + " [DOWN]"; };

                private _memberColor = [_unit, _isYou, _isLeader, _isActing] call DYN_fnc_getPlayerColor;
                private _iconColor = [_role] call DYN_fnc_getRoleColor;

                private _row = _list lnbAddRow ["", (name _unit) + _suffix];
                _list lnbSetPicture [[_row, 0], DYN_ROLE_ICON];
                _list lnbSetColor [[_row, 0], _iconColor];
                _list lnbSetColor [[_row, 1], _memberColor];
                DYN_squadListData pushBack ["MEMBER", getPlayerUID _unit, _grp];
            } forEach _members;
        };
    } forEach _squads;

    (_display displayCtrl 9510) ctrlSetText str(count _squads);
};

// =====================================================
// YOUR SQUAD
// =====================================================

DYN_fnc_refreshYourSquad = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _nameCtrl = _display displayCtrl 9520;
    private _statusCtrl = _display displayCtrl 9521;
    private _leaderCtrl = _display displayCtrl 9522;
    private _actingCtrl = _display displayCtrl 9523;
    private _countCtrl = _display displayCtrl 9524;
    private _list = _display displayCtrl 9525;

    lnbClear _list;

    private _inSquad = [player] call DYN_fnc_isInCustomSquad;

    if (!_inSquad) exitWith {
        _nameCtrl ctrlSetText "NOT IN SQUAD";
        _nameCtrl ctrlSetTextColor [0.55, 0.55, 0.55, 1];
        _statusCtrl ctrlSetText "";
        _leaderCtrl ctrlSetText "---";
        _leaderCtrl ctrlSetTextColor [0.55, 0.55, 0.55, 1];
        _actingCtrl ctrlSetText "---";
        _actingCtrl ctrlSetTextColor [0.55, 0.55, 0.55, 1];
        _countCtrl ctrlSetText "---";
    };

    private _grp = group player;
    private _squadName = _grp getVariable ["DYN_squadName", "SQUAD"];
    private _isLocked = _grp getVariable ["DYN_squadLocked", false];
    private _squadLeader = leader _grp;
    private _actingLeader = [_grp] call DYN_fnc_getActingLeader;
    private _members = (units _grp) select { isPlayer _x && alive _x };

    _nameCtrl ctrlSetText _squadName;
    _nameCtrl ctrlSetTextColor [0.95, 0.95, 0.95, 1];

    _statusCtrl ctrlSetText (if (_isLocked) then { "LOCKED" } else { "OPEN" });
    _statusCtrl ctrlSetTextColor (if (_isLocked) then { [0.80, 0.50, 0.50, 1] } else { [0.50, 0.80, 0.50, 1] });

    private _leaderStatus = [_squadLeader] call DYN_fnc_getPlayerStatus;
    private _leaderText = name _squadLeader;
    if (_leaderStatus == "DOWN") then { _leaderText = _leaderText + " [DOWN]"; };
    if (_leaderStatus == "DEAD") then { _leaderText = _leaderText + " [DEAD]"; };
    _leaderCtrl ctrlSetText _leaderText;

    _leaderCtrl ctrlSetTextColor (switch (true) do {
        case (_leaderStatus == "DOWN"): { [0.90, 0.35, 0.35, 1] };
        case (_leaderStatus == "DEAD"): { [0.60, 0.30, 0.30, 1] };
        case (_squadLeader == player): { [0.35, 0.95, 0.35, 1] };
        default { [0.95, 0.95, 0.95, 1] };
    });

    private _actingIsDifferent = _actingLeader != _squadLeader;
    if (_actingIsDifferent && !isNull _actingLeader) then {
        _actingCtrl ctrlSetText (name _actingLeader);
        _actingCtrl ctrlSetTextColor (if (_actingLeader == player) then { [0.95, 0.85, 0.30, 1] } else { [0.90, 0.70, 0.25, 1] });
    } else {
        _actingCtrl ctrlSetText (name _squadLeader);
        _actingCtrl ctrlSetTextColor (if (_squadLeader == player) then { [0.35, 0.95, 0.35, 1] } else { [0.95, 0.95, 0.95, 1] });
    };

    _countCtrl ctrlSetText format ["%1/%2", count _members, DYN_SQUAD_MAX_SIZE];

    _members = [_members, [], {
        if (_x == leader group player) then { "!!!" } else {
            private _r = [_x] call DYN_fnc_getPlayerRole;
            private _i = DYN_ROLE_ORDER find _r;
            format ["%1%2", if (_i < 0) then { 99 } else { _i }, name _x]
        }
    }, "ASCEND"] call BIS_fnc_sortBy;

    {
        private _unit = _x;
        private _role = [_unit] call DYN_fnc_getPlayerRole;
        private _status = [_unit] call DYN_fnc_getPlayerStatus;
        private _isLeader = _unit == _squadLeader;
        private _isActing = (_unit == _actingLeader) && (_actingLeader != _squadLeader);
        private _isYou = _unit == player;

        private _suffix = "";
        if (_isLeader) then { _suffix = " [SL]"; };
        if (_isActing) then { _suffix = " [AL]"; };
        if (_status == "DOWN") then { _suffix = _suffix + " [DOWN]"; };

        private _textColor = [_unit, _isYou, _isLeader, _isActing] call DYN_fnc_getPlayerColor;
        private _iconColor = [_role] call DYN_fnc_getRoleColor;

        private _row = _list lnbAddRow ["", (name _unit) + _suffix];
        _list lnbSetPicture [[_row, 0], DYN_ROLE_ICON];
        _list lnbSetColor [[_row, 0], _iconColor];
        _list lnbSetColor [[_row, 1], _textColor];
        _list lnbSetData [[_row, 0], getPlayerUID _unit];
    } forEach _members;
};

// =====================================================
// BUTTONS
// =====================================================

DYN_fnc_refreshButtons = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _inSquad = [player] call DYN_fnc_isInCustomSquad;
    private _isLeader = leader group player == player;

    private _squadList = _display displayCtrl 9511;
    private _squadSel = lnbCurSelRow _squadList;
    private _squadRowType = "";
    private _selectedGrp = grpNull;
    if (_squadSel >= 0 && _squadSel < count DYN_squadListData) then {
        _squadRowType = (DYN_squadListData#_squadSel)#0;
        _selectedGrp = (DYN_squadListData#_squadSel)#2;
    };

    private _ungroupedList = _display displayCtrl 9502;
    private _ungroupedSel = lnbCurSelRow _ungroupedList;
    private _ungroupedRowType = "";
    private _ungroupedUID = "";
    if (_ungroupedSel >= 0 && _ungroupedSel < count DYN_ungroupedListData) then {
        _ungroupedRowType = (DYN_ungroupedListData#_ungroupedSel)#0;
        if (_ungroupedRowType == "PLAYER") then {
            private _unit = (DYN_ungroupedListData#_ungroupedSel)#2;
            if (!isNull _unit) then { _ungroupedUID = getPlayerUID _unit; };
        };
    };

    private _yourList = _display displayCtrl 9525;
    private _yourSel = lnbCurSelRow _yourList;
    private _selectedUID = if (_yourSel >= 0) then { _yourList lnbData [_yourSel, 0] } else { "" };
    private _selectedIsOther = (_selectedUID != "") && (_selectedUID != getPlayerUID player);

    private _canJoin = (!_inSquad) && (_squadRowType == "HEADER") && (!isNull _selectedGrp) && (!(_selectedGrp getVariable ["DYN_squadLocked", false]));
    (_display displayCtrl 9532) ctrlEnable _canJoin;
    (_display displayCtrl 9533) ctrlEnable _inSquad;
    (_display displayCtrl 9534) ctrlEnable (_isLeader && _inSquad && _selectedIsOther);
    (_display displayCtrl 9535) ctrlEnable (_isLeader && _inSquad && _selectedIsOther);
    (_display displayCtrl 9530) ctrlEnable (_isLeader && _inSquad && _ungroupedRowType == "PLAYER" && _ungroupedUID != "");
    (_display displayCtrl 9513) ctrlEnable (!_inSquad);

    private _lockBtn = _display displayCtrl 9514;
    _lockBtn ctrlEnable (_isLeader && _inSquad);
    _lockBtn ctrlSetText (if ((group player) getVariable ["DYN_squadLocked", false]) then { "UNLOCK" } else { "LOCK" });

    (_display displayCtrl 9536) ctrlEnable (_isLeader && _inSquad);
};

// =====================================================
// INVITES
// =====================================================

DYN_fnc_refreshInvites = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _notifCtrl = _display displayCtrl 9560;
    private _acceptBtn = _display displayCtrl 9561;
    private _declineBtn = _display displayCtrl 9562;

    if (count DYN_pendingInvites > 0) then {
        private _invite = DYN_pendingInvites#0;
        _notifCtrl ctrlSetText format ["Invite: %1 > %2", _invite#1, _invite#2];
        _acceptBtn ctrlShow true;
        _declineBtn ctrlShow true;
    } else {
        _notifCtrl ctrlSetText "";
        _acceptBtn ctrlShow false;
        _declineBtn ctrlShow false;
    };
};

// =====================================================
// ACTIONS
// =====================================================

DYN_fnc_squadCreate = {
    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};
    if ([player] call DYN_fnc_isInCustomSquad) exitWith {};

    private _nameSel = lbCurSel (_display displayCtrl 9512);
    if (_nameSel < 0) exitWith {};

    private _squadName = (_display displayCtrl 9512) lbText _nameSel;

    if (count (allGroups select { (_x getVariable ["DYN_squadName", ""]) == _squadName && _x getVariable ["DYN_isCustomSquad", false] }) > 0) exitWith {
        [format ["%1 already exists", _squadName]] call DYN_fnc_notifyError;
    };

    private _newGrp = createGroup playerSide;
    [player] joinSilent _newGrp;
    _newGrp setVariable ["DYN_squadName", _squadName, true];
    _newGrp setVariable ["DYN_isCustomSquad", true, true];
    _newGrp setVariable ["DYN_squadLocked", false, true];
    _newGrp setGroupIdGlobal [_squadName];

    DYN_expandedSquads pushBackUnique _squadName;
    [_squadName] call DYN_fnc_notifySquadCreated;
    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadToggleLock = {
    if (leader group player != player) exitWith {};
    if (!([player] call DYN_fnc_isInCustomSquad)) exitWith {};

    private _grp = group player;
    _grp setVariable ["DYN_squadLocked", !(_grp getVariable ["DYN_squadLocked", false]), true];
    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadInvite = {
    disableSerialization;
    if (leader group player != player) exitWith {};
    if (!([player] call DYN_fnc_isInCustomSquad)) exitWith {};

    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _sel = lnbCurSelRow (_display displayCtrl 9502);
    if (_sel < 0 || _sel >= count DYN_ungroupedListData) exitWith {};

    private _rowData = DYN_ungroupedListData#_sel;
    if (_rowData#0 != "PLAYER") exitWith {};

    private _target = _rowData#2;
    if (isNull _target || _target == player) exitWith {};

    private _squadName = (group player) getVariable ["DYN_squadName", ""];
    private _grp = group player;

    [getPlayerUID player, name player, _squadName, _grp] remoteExec ["DYN_fnc_receiveInvite", _target];
    [name _target] call DYN_fnc_notifyInviteSent;
};

DYN_fnc_receiveInvite = {
    params ["_fromUID", "_fromName", "_squadName", "_grp"];

    DYN_pendingInvites = DYN_pendingInvites select { _x#0 != _fromUID };
    DYN_pendingInvites pushBack [_fromUID, _fromName, _squadName, _grp];

    [_fromName, _squadName] call DYN_fnc_notifySquadInvite;

    DYN_cacheHash = "";
    if (!isNull findDisplay 9500) then { [] call DYN_fnc_fullMenuRefresh; };
};

DYN_fnc_squadAcceptInvite = {
    if (count DYN_pendingInvites == 0) exitWith {};

    private _invite = DYN_pendingInvites deleteAt 0;
    private _grp = _invite#3;
    private _squadName = _invite#2;

    if (isNull _grp) exitWith { ["Squad no longer exists"] call DYN_fnc_notifyError; };
    if ({ isPlayer _x && alive _x } count units _grp >= DYN_SQUAD_MAX_SIZE) exitWith { ["Squad is full"] call DYN_fnc_notifyError; };

    private _myName = name player;

    [player] joinSilent _grp;

    DYN_expandedSquads pushBackUnique _squadName;
    [_squadName] call DYN_fnc_notifySquadJoined;

    [_grp, "SquadMemberJoined", format ["%1 joined the squad", _myName], player] call DYN_fnc_notifySquad;

    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadDeclineInvite = {
    if (count DYN_pendingInvites == 0) exitWith {};
    DYN_pendingInvites deleteAt 0;
    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadJoin = {
    disableSerialization;
    if ([player] call DYN_fnc_isInCustomSquad) exitWith {};

    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _sel = lnbCurSelRow (_display displayCtrl 9511);
    if (_sel < 0 || _sel >= count DYN_squadListData) exitWith {};

    private _rowData = DYN_squadListData#_sel;
    if (_rowData#0 != "HEADER") exitWith {};

    private _squadName = _rowData#1;
    private _grp = _rowData#2;

    if (isNull _grp) exitWith {};
    if (_grp getVariable ["DYN_squadLocked", false]) exitWith { ["Squad is locked"] call DYN_fnc_notifyError; };
    if ({ isPlayer _x && alive _x } count units _grp >= DYN_SQUAD_MAX_SIZE) exitWith { ["Squad is full"] call DYN_fnc_notifyError; };

    private _myName = name player;

    [player] joinSilent _grp;

    DYN_expandedSquads pushBackUnique _squadName;
    [_squadName] call DYN_fnc_notifySquadJoined;

    [_grp, "SquadMemberJoined", format ["%1 joined the squad", _myName], player] call DYN_fnc_notifySquad;

    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadLeave = {
    if (!([player] call DYN_fnc_isInCustomSquad)) exitWith {};

    private _grp = group player;
    private _squadName = _grp getVariable ["DYN_squadName", ""];
    private _isLeader = leader _grp == player;
    private _myName = name player;

    if (_isLeader) then {
        {
            if (_x != player && isPlayer _x) then {
                [_x, _squadName] remoteExec ["DYN_fnc_beKickedWithNotify", _x];
            };
        } forEach units _grp;
        [_squadName] call DYN_fnc_notifySquadDisbanded;
    } else {
        [_grp, "SquadMemberLeft", format ["%1 left the squad", _myName], player] call DYN_fnc_notifySquad;
        [_squadName] call DYN_fnc_notifySquadLeft;
    };

    [player] joinSilent (createGroup [playerSide, true]);

    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadDisband = {
    if (leader group player != player) exitWith {};
    if (!([player] call DYN_fnc_isInCustomSquad)) exitWith {};

    private _grp = group player;
    private _squadName = _grp getVariable ["DYN_squadName", ""];

    {
        if (_x != player && isPlayer _x) then {
            [_x, _squadName] remoteExec ["DYN_fnc_beKickedWithNotify", _x];
        };
    } forEach units _grp;

    [player] joinSilent (createGroup [playerSide, true]);

    DYN_expandedSquads = DYN_expandedSquads - [_squadName];
    [_squadName] call DYN_fnc_notifySquadDisbanded;
    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadPromote = {
    if (leader group player != player) exitWith {};
    if (!([player] call DYN_fnc_isInCustomSquad)) exitWith {};

    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _sel = lnbCurSelRow (_display displayCtrl 9525);
    if (_sel < 0) exitWith {};

    private _targetUID = (_display displayCtrl 9525) lnbData [_sel, 0];
    if (_targetUID == "" || _targetUID == getPlayerUID player) exitWith {};

    private _target = objNull;
    { if (getPlayerUID _x == _targetUID) exitWith { _target = _x }; } forEach allPlayers;
    if (isNull _target) exitWith {};

    (group player) selectLeader _target;
    [] remoteExec ["DYN_fnc_notifyPromotedToSL", _target];

    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_squadKick = {
    if (leader group player != player) exitWith {};
    if (!([player] call DYN_fnc_isInCustomSquad)) exitWith {};

    disableSerialization;
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _sel = lnbCurSelRow (_display displayCtrl 9525);
    if (_sel < 0) exitWith {};

    private _targetUID = (_display displayCtrl 9525) lnbData [_sel, 0];
    if (_targetUID == "" || _targetUID == getPlayerUID player) exitWith {};

    private _target = objNull;
    { if (getPlayerUID _x == _targetUID) exitWith { _target = _x }; } forEach allPlayers;
    if (isNull _target) exitWith {};

    private _squadName = (group player) getVariable ["DYN_squadName", ""];
    private _targetName = name _target;
    private _grp = group player;

    [_target, _squadName] remoteExec ["DYN_fnc_beKickedWithNotify", _target];
    [_grp, "SquadMemberKicked", format ["%1 was removed", _targetName], _target] call DYN_fnc_notifySquad;

    DYN_cacheHash = "";
    [] call DYN_fnc_fullMenuRefresh;
};

DYN_fnc_beKickedWithNotify = {
    params ["_unit", "_squadName"];
    [_unit] joinSilent (createGroup [playerSide, true]);

    [_squadName] call DYN_fnc_notifySquadKicked;
    DYN_cacheHash = "";
    if (!isNull findDisplay 9500) then { [] call DYN_fnc_fullMenuRefresh; };
};

// =====================================================
// KEYBIND
// =====================================================

if (isNil "DYN_squadKeyBound") then {
    DYN_squadKeyBound = true;
    [] spawn {
        waitUntil { !isNull findDisplay 46 };
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            if (_this#1 == 22) then { [] call DYN_fnc_openSquadMenu; true } else { false };
        }];
    };
};