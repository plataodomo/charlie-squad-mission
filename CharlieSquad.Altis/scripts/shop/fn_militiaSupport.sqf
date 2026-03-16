/*
    scripts/shop/fn_militiaSupport.sqf
    MILITIA SUPPORT — SERVER

    Squad leaders can spend 30 reputation points to call in 10 friendly
    CUP BLUFOR militia. After a 10-minute countdown (with notifications)
    the squad spawns just outside the AO from the chosen direction and
    assaults inward.

    Called via: [buyerUID, direction] remoteExec ["DYN_fnc_purchaseMilitia", 2]
    Directions: "NORTH" | "EAST" | "SOUTH" | "WEST"
*/
if (!isServer) exitWith {};

diag_log "[MILITIA] Militia support system initializing";

waitUntil { sleep 2; !isNil "DYN_fnc_changeReputation" };
waitUntil { sleep 1; !isNil "DYN_fnc_posOffset" };

DYN_militia_active = false;
publicVariable "DYN_militia_active";

// =====================================================
// UNIT ROSTER — CUP BLUFOR German Army (10 units)
// =====================================================
DYN_militia_units = [
    "CUP_B_GER_Soldier_TL",
    "CUP_B_GER_Soldier",
    "CUP_B_GER_Soldier",
    "CUP_B_GER_Soldier",
    "CUP_B_GER_Soldier_GL",
    "CUP_B_GER_Soldier_GL",
    "CUP_B_GER_Soldier_MG3",
    "CUP_B_GER_Soldier_AT",
    "CUP_B_GER_Medic",
    "CUP_B_GER_Soldier"
];

// =====================================================
// PURCHASE HANDLER (remoteExec target: server)
// =====================================================
// Tier definitions
//   ROOKIE  —  50 pts — 10 infantry, no vehicles (untrained)
//   REGULAR —  90 pts — 10 infantry + 2x Eagle IV (light)
//   ELITE   — 150 pts — 10 infantry + 1x Puma IFV + 1x Leopard 2 (heavy armor)
DYN_militia_tierCost = createHashMapFromArray [
    ["ROOKIE",   50],
    ["REGULAR",  90],
    ["ELITE",   150]
];

DYN_militia_tierVehicles = createHashMapFromArray [
    ["ROOKIE",  []],
    ["REGULAR", ["BWA3_Eagle_FLW100_Tropen", "BWA3_Eagle_FLW100_Tropen"]],
    ["ELITE",   ["BWA3_Puma_Tropen", "BWA3_Leopard2_Tropen"]]
];

DYN_fnc_purchaseMilitia = {
    params ["_buyerUID", "_direction", ["_tier", "ROOKIE"]];
    if (!isServer) exitWith {};

    _tier = toUpper _tier;
    private _cost = DYN_militia_tierCost getOrDefault [_tier, 20];

    // Locate buyer
    private _buyer = objNull;
    { if (getPlayerUID _x == _buyerUID) exitWith { _buyer = _x } } forEach allPlayers;

    private _fnErr = {
        params ["_msg"];
        diag_log format ["[MILITIA] Purchase rejected: %1", _msg];
        if (!isNull _buyer) then {
            ["SquadError", [_msg]] remoteExec ["BIS_fnc_showNotification", _buyer];
        };
    };

    // --- guards ---
    if (DYN_militia_active) exitWith {
        ["Militia already deployed! Wait for them to finish."] call _fnErr;
    };

    private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];
    if (_aoCenter isEqualTo [0,0,0]) exitWith {
        ["No active AO. Cannot deploy militia support."] call _fnErr;
    };

    private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
    if (_rep < _cost) exitWith {
        [format ["Not enough points! Need %1, have %2.", _cost, _rep]] call _fnErr;
    };

    // --- pre-flight: verify unit classnames exist (catches missing CUP mod) ---
    private _missingClass = "";
    {
        if (isClass (configFile >> "CfgVehicles" >> _x)) then {} else { _missingClass = _x };
    } forEach DYN_militia_units;
    if (_missingClass != "") exitWith {
        [format ["Militia unit class not found: %1 — is CUP Units loaded?", _missingClass]] call _fnErr;
    };

    // --- confirmed: deduct and lock ---
    [_cost * -1, "Militia Support"] call DYN_fnc_changeReputation;
    DYN_militia_active = true;
    publicVariable "DYN_militia_active";

    private _vehicleClasses = DYN_militia_tierVehicles getOrDefault [_tier, []];
    diag_log format ["[MILITIA] Purchase confirmed by %1 — direction: %2  tier: %3", _buyerUID, _direction, _tier];

    private _bearing = switch (toUpper _direction) do {
        case "NORTH": { 0 };
        case "EAST":  { 90 };
        case "SOUTH": { 180 };
        case "WEST":  { 270 };
        default       { 0 };
    };
    private _aoRadius = missionNamespace getVariable ["DYN_AO_radius", 600];

    // --- approach marker ---
    private _markerPos  = [_aoCenter, _aoRadius + 900, _bearing] call DYN_fnc_posOffset;
    private _etaMkr     = format ["militia_eta_%1", round (diag_tickTime * 1000)];
    createMarker [_etaMkr, _markerPos];
    _etaMkr setMarkerShape "ICON";
    _etaMkr setMarkerType  "b_inf";
    _etaMkr setMarkerColor "ColorWEST";
    _etaMkr setMarkerText  format ["Militia ETA 20sec | %1", _direction];
    _etaMkr setMarkerSize  [0.8, 0.8];

    // --- announce ---
    private _tierLabel = switch (_tier) do {
        case "ROOKIE":  { "Rookie infantry" };
        case "REGULAR": { "Regular infantry + light vehicles" };
        case "ELITE":   { "Elite infantry + heavy armor" };
        default         { "Militia" };
    };
    ["MilitiaInbound",
        [format ["Militia inbound from %1 in 20 sec! (%2)", _direction, _tierLabel]]
    ] remoteExec ["BIS_fnc_showNotification", 0];

    // --- countdown + spawn thread ---
    [_direction, _bearing, _aoCenter, _aoRadius, _etaMkr, _vehicleClasses, _cost, _tier, _buyer] spawn {
        params ["_direction", "_bearing", "_aoCenter", "_aoRadius", "_etaMkr", "_vehicleClasses", "_cost", "_tier", "_buyer"];

        // 10-second warning — buyer only  [TEST: reduced from 10 min]
        sleep 10;
        ["MilitiaInbound",
            [format ["Militia assault in 10 seconds from %1!", _direction]]
        ] remoteExec ["BIS_fnc_showNotification", _buyer];
        _etaMkr setMarkerText format ["Militia 10 SEC | %1", _direction];

        sleep 10;
        deleteMarker _etaMkr;

        // =====================================================
        // FIND SPAWN POSITION — land, outside AO edge
        // =====================================================
        private _spawnDist = _aoRadius + 700;
        private _spawnPos  = [];

        // Sweep primary bearing first, fan out ±10° steps up to ±180°
        {
            private _spread   = _x;
            private _testDist = _spawnDist + (abs _spread) * 3;
            private _testPos  = [_aoCenter, _testDist, _bearing + _spread] call DYN_fnc_posOffset;
            private _tx = _testPos select 0;
            private _ty = _testPos select 1;
            if (!surfaceIsWater _testPos
                && _tx > 100 && _ty > 100
                && _tx < (worldSize - 100) && _ty < (worldSize - 100)) exitWith {
                _spawnPos = _testPos;
            };
        } forEach [0, -10, 10, -20, 20, -30, 30, -45, 45, -60, 60, -90, 90, -135, 135, 180];

        if (_spawnPos isEqualTo []) then {
            // Last-resort fallback (may be in water — very unlikely on Altis)
            _spawnPos = [_aoCenter, _spawnDist, _bearing] call DYN_fnc_posOffset;
            diag_log "[MILITIA] WARNING: fallback spawn position used — may be in water";
        };

        diag_log format ["[MILITIA] Spawn position: %1 (bearing %2, ~%3m from AO centre)", _spawnPos, _bearing, _spawnDist];

        // =====================================================
        // SPAWN GROUP
        // =====================================================
        private _grp = createGroup [west, true];   // deleteWhenEmpty = true
        _grp setBehaviourStrong "AWARE";
        _grp setCombatMode "YELLOW";

        // Skill multiplier by tier: ROOKIE is untrained, ELITE is veteran
        private _skillBase = switch (_tier) do {
            case "ROOKIE":  { 0.25 };
            case "REGULAR": { 0.50 };
            case "ELITE":   { 0.75 };
            default         { 0.50 };
        };

        private _spawnedUnits = [];
        {
            private _unit = _grp createUnit [_x, _spawnPos, [], 4 + random 6, "NONE"];
            if (!isNull _unit) then {
                _spawnedUnits pushBack _unit;
                _unit setSkill ["aimingAccuracy", _skillBase + random 0.08];
                _unit setSkill ["aimingSpeed",    _skillBase + random 0.08];
                _unit setSkill ["spotDistance",   _skillBase + random 0.10];
                _unit setSkill ["courage",        0.50 + _skillBase * 0.4];
                _unit allowFleeing (0.20 - _skillBase * 0.15);
            };
        } forEach DYN_militia_units;

        if (count _spawnedUnits == 0) exitWith {
            diag_log "[MILITIA] ERROR: No units created — verify CUP class names in DYN_militia_units";
            deleteGroup _grp;
            [_cost, "Militia Refund (spawn failed)"] call DYN_fnc_changeReputation;
            DYN_militia_active = false;
            publicVariable "DYN_militia_active";
            if (!isNull _buyer) then {
                ["SquadError", ["Militia failed to spawn — refund issued."]] remoteExec ["BIS_fnc_showNotification", _buyer];
            };
        };

        diag_log format ["[MILITIA] %1 units spawned", count _spawnedUnits];

        // =====================================================
        // WAYPOINTS: approach → AO edge (AWARE) → AO centre (COMBAT, cycle)
        // =====================================================
        private _aoEdge = [_aoCenter, _aoRadius + 150, _bearing] call DYN_fnc_posOffset;

        // =====================================================
        // TIER VEHICLES — spawn and assign independent waypoints
        // =====================================================
        private _allCrewUnits = [];
        private _allVehicles  = [];   // tracked separately so hulls can be deleted
        {
            private _vClass = _x;
            if (isClass (configFile >> "CfgVehicles" >> _vClass)) then {
            private _veh = _vClass createVehicle _spawnPos;
            if (isNull _veh) then {
                diag_log format ["[MILITIA] WARNING: vehicle failed to create: %1", _vClass];
            } else {
            createVehicleCrew _veh;
            private _vGrp = createGroup [west, true];
            (crew _veh) joinSilent _vGrp;
            _vGrp setCombatMode "YELLOW";
            _vGrp setBehaviourStrong "AWARE";

            private _vWp1 = _vGrp addWaypoint [_aoEdge, 80];
            _vWp1 setWaypointType "MOVE"; _vWp1 setWaypointBehaviour "AWARE";
            _vWp1 setWaypointSpeed "FULL"; _vWp1 setWaypointCombatMode "YELLOW";

            private _vWp2 = _vGrp addWaypoint [_aoCenter, 100];
            _vWp2 setWaypointType "MOVE"; _vWp2 setWaypointBehaviour "COMBAT";
            _vWp2 setWaypointCombatMode "RED";

            private _vWp3 = _vGrp addWaypoint [_aoCenter, 150];
            _vWp3 setWaypointType "CYCLE"; _vWp3 setWaypointCombatMode "RED";

            _allCrewUnits append (crew _veh);
            _allVehicles pushBack _veh;
            diag_log format ["[MILITIA] Vehicle spawned: %1", _vClass];
            }; // end isNull _veh check
        }; // end isClass _vClass check
        } forEach _vehicleClasses;

        private _wp1 = _grp addWaypoint [_aoEdge, 80];
        _wp1 setWaypointType             "MOVE";
        _wp1 setWaypointBehaviour        "AWARE";
        _wp1 setWaypointSpeed            "FULL";
        _wp1 setWaypointCombatMode       "YELLOW";
        _wp1 setWaypointCompletionRadius 50;

        private _wp2 = _grp addWaypoint [_aoCenter, 100];
        _wp2 setWaypointType             "MOVE";
        _wp2 setWaypointBehaviour        "COMBAT";
        _wp2 setWaypointSpeed            "NORMAL";
        _wp2 setWaypointCombatMode       "RED";
        _wp2 setWaypointCompletionRadius 60;

        private _wp3 = _grp addWaypoint [_aoCenter, 150];
        _wp3 setWaypointType             "CYCLE";
        _wp3 setWaypointBehaviour        "COMBAT";
        _wp3 setWaypointCombatMode       "RED";

        // =====================================================
        // MAP MARKER — live position indicator
        // =====================================================
        private _liveMkr = format ["militia_active_%1", round (diag_tickTime * 1000)];
        createMarker [_liveMkr, _aoEdge];
        _liveMkr setMarkerShape "ICON";
        _liveMkr setMarkerType  "b_inf";
        _liveMkr setMarkerColor "ColorWEST";
        _liveMkr setMarkerText  "Militia";
        _liveMkr setMarkerSize  [0.8, 0.8];

        // Notify arrival
        ["MilitiaEngaging",
            [format ["Militia engaging from %1! 10 friendly units assaulting the AO.", _direction]]
        ] remoteExec ["BIS_fnc_showNotification", 0];

        // =====================================================
        // MONITOR — clean up when done or after 30-minute timeout
        // =====================================================
        private _watchUnits = _spawnedUnits + _allCrewUnits;
        private _timeout    = diag_tickTime + 1800;
        [_watchUnits, _allVehicles, _timeout, _liveMkr] spawn {
            params ["_units", "_vehicles", "_timeout", "_mkr"];
            waitUntil {
                sleep 15;
                ({ alive _x } count _units) == 0
                || diag_tickTime > _timeout
            };
            { if (alive _x) then { deleteVehicle _x } } forEach _units;
            { if (!isNull _x) then { deleteVehicle _x } } forEach _vehicles;
            deleteMarker _mkr;
            DYN_militia_active = false;
            publicVariable "DYN_militia_active";
            diag_log "[MILITIA] Support complete — all units down or 30-min timeout.";
        };
    };
};
publicVariable "DYN_fnc_purchaseMilitia";

diag_log "[MILITIA] Militia support system ready (ROOKIE=50pts REGULAR=90pts ELITE=150pts | delay: 20 sec [TEST] | units: 10)";
