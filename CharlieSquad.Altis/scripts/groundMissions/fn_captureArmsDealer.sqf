/*
    scripts\groundMissions\fn_captureArmsDealer.sqf
    GROUND MISSION: Capture Arms Dealer

    An enemy arms dealer is operating at a position outside the AO.
    He is guarded by infantry and has an escape plan ready:
      - 50% chance: ground vehicle escape (armed convoy)
      - 50% chance: helicopter extraction

    Once players are spotted, the arms dealer attempts to escape.
    Capture him alive using ACE restraints and deliver to prison at base.

    Fail conditions: Arms dealer killed, escapes, or 2-hour timer expires.
    Success: Arms dealer captured and delivered to prison_dropoff.

    Uses existing systems:
      - DYN_fnc_registerAceCapture (ACE restraint detection)
      - DYN_fnc_applySurrenderState (surrender animation)
      - Prison delivery system (fn_prisonSystem.sqf)

    CUP RUSSIAN FORCES
*/
if (!isServer) exitWith {};

diag_log "[GROUND-DEALER] Setting up Capture Arms Dealer mission...";

if (isNil "DYN_ground_enemies") then { DYN_ground_enemies = [] };
if (isNil "DYN_ground_enemyVehs") then { DYN_ground_enemyVehs = [] };
if (isNil "DYN_ground_enemyGroups") then { DYN_ground_enemyGroups = [] };
if (isNil "DYN_ground_objects") then { DYN_ground_objects = [] };
if (isNil "DYN_ground_tasks") then { DYN_ground_tasks = [] };
if (isNil "DYN_ground_markers") then { DYN_ground_markers = [] };

private _basePos = getMarkerPos "respawn_west";
private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

// =====================================================
// 1. SETTINGS
// =====================================================
private _timeout       = 7200;    // 2 hours
private _repReward     = 35 + floor (random 11); // 35-45 rep
private _cleanupDelay  = 120;     // 2 minutes before entities are deleted
private _zoneRadius    = 200;     // Operation zone size
private _escapeIsHeli  = (random 1) > 0.50; // 50/50 ground vs heli

// CUP Russian unit pools
private _dealerClass      = "CUP_O_RU_Officer_EMR";
private _guardPool     = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_MG_Ratnik_Autumn"
];
private _pilotClass    = "CUP_O_RU_Pilot";
private _heliClass     = "CUP_O_Mi8AMT_RU";
private _escortVehPool = [
    "CUP_O_GAZ_Vodnik_PK_RU",
    "CUP_O_GAZ_Vodnik_AGS_RU",
    "CUP_O_UAZ_MG_RU",
    "CUP_O_BTR80_GREEN_RU"
];
private _dealerVehClass   = "CUP_O_UAZ_Unarmed_RU";

diag_log format ["[GROUND-DEALER] Escape type: %1", if (_escapeIsHeli) then {"HELICOPTER"} else {"GROUND VEHICLE"}];

// =====================================================
// 2. FIND MISSION POSITION
// =====================================================
private _missionPos = [];
private _mapSz = worldSize;

for "_i" from 1 to 300 do {
    private _x = 300 + random (_mapSz - 600);
    private _y = 300 + random (_mapSz - 600);
    private _p = [_x, _y, 0];

    if (surfaceIsWater _p) then { continue };
    if (_p distance2D _basePos < 2500) then { continue };
    if !(_aoCenter isEqualTo [0,0,0]) then {
        if (_p distance2D _aoCenter < 1500) then { continue };
    };

    // Need some buildings or flat ground
    private _nearBuildings = count (nearestObjects [_p, ["House", "Building"], 150]);
    private _nearRoads = _p nearRoads 200;

    // Prefer locations with road access and some structures
    if (count _nearRoads == 0) then { continue };
    if (_nearBuildings < 1) then { continue };

    // Slope check
    private _heights = [];
    {
        private _chkPos = [_p, 30, _x] call DYN_fnc_posOffset;
        _heights pushBack (getTerrainHeightASL _chkPos);
    } forEach [0, 90, 180, 270];
    private _slopeRange = (selectMax _heights) - (selectMin _heights);
    if (_slopeRange > 6) then { continue };

    _missionPos = _p;
    break;
};

if (_missionPos isEqualTo []) exitWith {
    diag_log "[GROUND-DEALER] Could not find mission position. Aborting.";
    DYN_ground_active = false;
};

diag_log format ["[GROUND-DEALER] Mission position: %1", _missionPos];

// =====================================================
// 3. FIND ESCAPE DESTINATION (far away from mission pos)
// =====================================================
private _escapePos = [];

for "_i" from 1 to 100 do {
    private _dir = random 360;
    private _dist = 3000 + random 3000;
    private _p = _missionPos getPos [_dist, _dir];

    if (surfaceIsWater _p) then { continue };
    if (_p select 0 < 100 || _p select 0 > (_mapSz - 100)) then { continue };
    if (_p select 1 < 100 || _p select 1 > (_mapSz - 100)) then { continue };

    if (!_escapeIsHeli) then {
        // Ground escape needs roads
        if (count (_p nearRoads 300) == 0) then { continue };
    };

    _escapePos = _p;
    break;
};

if (_escapePos isEqualTo []) then {
    // Fallback: just pick a far point
    _escapePos = _missionPos getPos [4000, random 360];
};

diag_log format ["[GROUND-DEALER] Escape destination: %1 (dist: %2m)", _escapePos, round (_missionPos distance2D _escapePos)];

// =====================================================
// 4. SPAWN ARMS DEALER
// =====================================================
private _dealerGrp = createGroup east;
DYN_ground_enemyGroups pushBack _dealerGrp;

private _dealer = _dealerGrp createUnit [_dealerClass, _missionPos, [], 0, "NONE"];

if (isNull _dealer) exitWith {
    diag_log "[GROUND-DEALER] Failed to create arms dealer unit. Aborting.";
    DYN_ground_active = false;
};

_dealer setPosATL _missionPos;
removeAllWeapons _dealer;
_dealer setCaptive true;
_dealer disableAI "MOVE";
_dealer disableAI "PATH";
_dealer disableAI "AUTOCOMBAT";
_dealer disableAI "TARGET";
_dealer setUnitPos "UP";
_dealer allowFleeing 0;
_dealer setSkill 0.3;

_dealer setVariable ["DYN_isArmsDealer", true, true];
_dealer setVariable ["DYN_dealerAlert", false, true];
_dealer setVariable ["DYN_dealerEscaped", false, true];
_dealer setVariable ["DYN_dealerCaptured", false, true];

DYN_ground_enemies pushBack _dealer;

diag_log "[GROUND-DEALER] Arms dealer spawned.";

// =====================================================
// 5. SPAWN INFANTRY GUARDS
// =====================================================
private _guardGrp = createGroup east;
DYN_ground_enemyGroups pushBack _guardGrp;
_guardGrp setBehaviour "SAFE";
_guardGrp setCombatMode "YELLOW";

private _guardCount = 12 + floor (random 7); // 12-18 guards

for "_i" from 1 to _guardCount do {
    private _gPos = [_missionPos, 5 + random 25, random 360] call DYN_fnc_posOffset;
    private _u = _guardGrp createUnit [selectRandom _guardPool, _gPos, [], 0, "NONE"];
    if (!isNull _u) then {
        _u allowFleeing 0;
        _u setSkill 0.45;
        DYN_ground_enemies pushBack _u;
    };
};

// Patrol waypoints around mission area
for "_w" from 1 to 5 do {
    private _wpPos = [_missionPos, 30 + random 40, _w * 72] call DYN_fnc_posOffset;
    private _wp = _guardGrp addWaypoint [_wpPos, 10];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointCompletionRadius 15;
};
(_guardGrp addWaypoint [_missionPos, 0]) setWaypointType "CYCLE";

diag_log format ["[GROUND-DEALER] %1 guards spawned.", _guardCount];

// =====================================================
// 6. SPAWN ESCAPE ASSETS
// =====================================================
private _escapeVeh = objNull;
private _escortVehs = [];
private _pilotUnit = objNull;

if (_escapeIsHeli) then {
    // === HELICOPTER VARIANT ===
    // Find flat spot close to dealer for helicopter
    private _heliPos = [_missionPos, 0, 40, 15, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_heliPos isEqualTo [0,0,0]) then { _heliPos = [_missionPos, 25, random 360] call DYN_fnc_posOffset; };

    _escapeVeh = createVehicle [_heliClass, _heliPos, [], 0, "NONE"];
    _escapeVeh setDir (_heliPos getDir _missionPos);
    _escapeVeh setFuel 1;
    _escapeVeh engineOn false;

    DYN_ground_enemyVehs pushBack _escapeVeh;

    // Pilot sits in helicopter, engine off
    private _pilotGrp = createGroup east;
    DYN_ground_enemyGroups pushBack _pilotGrp;
    _pilotUnit = _pilotGrp createUnit [_pilotClass, _heliPos, [], 0, "NONE"];
    _pilotUnit moveInDriver _escapeVeh;
    _pilotUnit allowFleeing 0;
    _pilotUnit setSkill 0.50;
    DYN_ground_enemies pushBack _pilotUnit;

    // Door gunner — suppresses players during escape
    private _gunnerUnit = _pilotGrp createUnit [selectRandom _guardPool, _heliPos, [], 0, "NONE"];
    if (!isNull _gunnerUnit) then {
        _gunnerUnit moveInTurret [_escapeVeh, [0]];
        _gunnerUnit allowFleeing 0;
        _gunnerUnit setSkill 0.50;
        _gunnerUnit setSkill ["aimingAccuracy", 0.40];
        _gunnerUnit setSkill ["spotDistance", 0.60];
        _gunnerUnit setSkill ["courage", 0.60];
        DYN_ground_enemies pushBack _gunnerUnit;
    };

    // 4 escort infantry near heli
    for "_i" from 1 to 4 do {
        private _ePos = [_heliPos, 5 + random 10, random 360] call DYN_fnc_posOffset;
        private _eu = _guardGrp createUnit [selectRandom _guardPool, _ePos, [], 0, "NONE"];
        if (!isNull _eu) then {
            _eu allowFleeing 0;
            DYN_ground_enemies pushBack _eu;
        };
    };

    diag_log format ["[GROUND-DEALER] Helicopter spawned at %1", _heliPos];

} else {
    // === GROUND VEHICLE VARIANT ===
    // Arms dealer escape vehicle — parked close to the dealer
    private _vehRoads = _missionPos nearRoads 50;
    private _vehPos = if (count _vehRoads > 0) then {
        getPos (selectRandom _vehRoads)
    } else {
        [_missionPos, 10 + random 15, random 360] call DYN_fnc_posOffset
    };

    _escapeVeh = createVehicle [_dealerVehClass, _vehPos, [], 0, "NONE"];
    _escapeVeh setDir (_vehPos getDir _missionPos);
    DYN_ground_enemyVehs pushBack _escapeVeh;

    // Driver for Arms dealer vehicle
    private _driverGrp = createGroup east;
    DYN_ground_enemyGroups pushBack _driverGrp;
    private _driver = _driverGrp createUnit [selectRandom _guardPool, _vehPos, [], 0, "NONE"];
    _driver moveInDriver _escapeVeh;
    _driver allowFleeing 0;
    DYN_ground_enemies pushBack _driver;

    // 2-3 armed escort vehicles — parked nearby
    private _escortCount = 2 + floor (random 2);
    for "_i" from 1 to _escortCount do {
        private _ePos = [_missionPos, 15 + random 25, _i * (360 / _escortCount) + random 30] call DYN_fnc_posOffset;

        private _eVeh = createVehicle [selectRandom _escortVehPool, _ePos, [], 0, "NONE"];
        _eVeh setDir (_ePos getDir _missionPos);
        createVehicleCrew _eVeh;

        DYN_ground_enemyVehs pushBack _eVeh;
        _escortVehs pushBack _eVeh;

        private _eGrp = group (driver _eVeh);
        DYN_ground_enemyGroups pushBack _eGrp;
        { DYN_ground_enemies pushBack _x; _x allowFleeing 0; } forEach crew _eVeh;
    };

    diag_log format ["[GROUND-DEALER] Ground vehicles spawned: 1 escape + %1 escort(s)", _escortCount];
};

// =====================================================
// 7. TASK + MARKER
// =====================================================
private _taskId = format ["ground_dealer_%1", round (diag_tickTime * 1000)];

private _mkr = format ["ground_dealer_mkr_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _missionPos];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [_zoneRadius, _zoneRadius];
_mkr setMarkerColor "ColorRed";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.5;
_mkr setMarkerText "Arms Dealer Location";
DYN_ground_markers pushBack _mkr;

private _escapeType = if (_escapeIsHeli) then {"helicopter extraction"} else {"armed convoy"};

[
    west,
    _taskId,
    [
        format [
            "Intelligence reports that a known arms dealer has been located operating outside the main AO. This individual is responsible for supplying enemy forces with weapons, explosives, and equipment across the region.<br/><br/>The target is conducting a deal at the marked location and is protected by a heavily armed security detail. He has a %1 on standby for emergency extraction should things go south.<br/><br/>Your mission is to capture the arms dealer alive using ACE restraints and deliver him to the prison facility at base for interrogation. He holds critical intel on enemy supply networks.<br/><br/>WARNING: Do not kill the target. If the arms dealer is killed or manages to escape, the mission will be considered a failure.<br/><br/>Time limit: 2 hours.",
            _escapeType
        ],
        "Capture Arms Dealer",
        ""
    ],
    _missionPos,
    "CREATED",
    3,
    true,
    "meet"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_ground_tasks pushBack _taskId;

// Register ACE capture system on arms dealer
if (!isNil "DYN_fnc_registerAceCapture") then {
    [_dealer, _taskId, "Arms Dealer", "DYN_dealerCaptured"] call DYN_fnc_registerAceCapture;
};

diag_log "[GROUND-DEALER] Task created. Mission active.";

// =====================================================
// 8. ALERT DETECTION + ESCAPE BEHAVIOR
// Alert triggers when guards enter COMBAT (spot players or take fire)
// =====================================================
[
    _dealer, _escapeVeh, _escapePos, _escapeIsHeli,
    _guardGrp, _escortVehs, _pilotUnit,
    _missionPos
] spawn {
    params [
        "_dealer", "_escapeVeh", "_escapePos", "_isHeli",
        "_guardGrp", "_escorts", "_pilot",
        "_mPos"
    ];

    // Wait for guards to enter combat (they spotted players or took fire)
    waitUntil {
        sleep 2;
        isNull _dealer
        || {!alive _dealer}
        || {_dealer getVariable ["DYN_dealerCaptured", false]}
        || {_dealer getVariable ["DYN_isPrisoner", false]}
        || {
            // Check if any guard group is in combat
            private _alert = false;
            if (!isNull _guardGrp && {({alive _x} count units _guardGrp) > 0}) then {
                if (behaviour (leader _guardGrp) == "COMBAT") then { _alert = true; };
            };
            // Also check escort vehicle crews
            if (!_alert) then {
                {
                    if (!isNull _x && alive _x) then {
                        private _eGrp = group (driver _x);
                        if (!isNull _eGrp && {({alive _x} count units _eGrp) > 0}) then {
                            if (behaviour (leader _eGrp) == "COMBAT") then { _alert = true; };
                        };
                    };
                } forEach _escorts;
            };
            _alert
        }
    };

    // If already captured/dead/null, exit — no escape needed
    if (isNull _dealer || {!alive _dealer}) exitWith {};
    if (_dealer getVariable ["DYN_dealerCaptured", false]) exitWith {};
    if (_dealer getVariable ["DYN_isPrisoner", false]) exitWith {};

    // === ALERT TRIGGERED ===
    _dealer setVariable ["DYN_dealerAlert", true, true];

    diag_log "[GROUND-DEALER] ALERT! Players detected. Arms dealer attempting escape.";

    ["TaskFailed", ["Target Alert!", "The arms dealer has been alerted and is attempting to escape!"]]
        remoteExecCall ["BIS_fnc_showNotification", 0];

    // Guards go combat mode
    _guardGrp setBehaviour "COMBAT";
    _guardGrp setCombatMode "RED";
    _guardGrp setSpeedMode "FULL";

    // Smoke cover near arms dealer
    private _smokeTypes = ["SmokeShell", "SmokeShellGreen", "SmokeShellRed"];
    for "_i" from 1 to 3 do {
        private _sPos = [getPosATL _dealer, 5 + random 10, random 360] call DYN_fnc_posOffset;
        private _smoke = (selectRandom _smokeTypes) createVehicle _sPos;
        DYN_ground_objects pushBack _smoke;
    };

    // Enable arms dealer movement
    _dealer setCaptive false;
    _dealer enableAI "MOVE";
    _dealer enableAI "PATH";

    sleep 2;

    if (_isHeli) then {
        // === HELICOPTER ESCAPE ===
        if (!isNull _escapeVeh && alive _escapeVeh && !isNull _pilot && alive _pilot) then {
            // Start engine
            _escapeVeh engineOn true;

            // Arms dealer boards helicopter
            _dealer assignAsCargo _escapeVeh;
            [_dealer] orderGetIn true;

            // Wait for boarding or timeout
            private _boardTime = diag_tickTime + 30;
            waitUntil {
                sleep 1;
                (vehicle _dealer == _escapeVeh)
                || {!alive _dealer}
                || {_dealer getVariable ["DYN_dealerCaptured", false]}
                || {_dealer getVariable ["DYN_isPrisoner", false]}
                || {diag_tickTime > _boardTime}
            };

            // Force board if still alive and nearby
            if (alive _dealer && vehicle _dealer != _escapeVeh
                && !(_dealer getVariable ["DYN_dealerCaptured", false])
                && !(_dealer getVariable ["DYN_isPrisoner", false])) then {
                _dealer moveInCargo _escapeVeh;
            };

            if (alive _dealer && vehicle _dealer == _escapeVeh) then {
                // Fly to escape point
                private _grp = group _pilot;
                for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

                private _wp = _grp addWaypoint [[_escapePos select 0, _escapePos select 1, 200], 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "CARELESS";
                _wp setWaypointCompletionRadius 500;

                _escapeVeh flyInHeight 200;

                // Monitor: if pilot dies, eject dealer if heli is low enough
                [_escapeVeh, _dealer] spawn {
                    params ["_veh", "_dealer"];
                    while {alive _veh} do {
                        sleep 2;
                        private _d = driver _veh;
                        if (isNull _d || {!alive _d}) exitWith {
                            _veh engineOn false;

                            // If heli is near ground, eject the dealer alive
                            if (alive _dealer && vehicle _dealer == _veh) then {
                                private _alt = (getPosATL _veh) select 2;
                                if (_alt < 15) then {
                                    unassignVehicle _dealer;
                                    moveOut _dealer;
                                    // Leave him as a normal unit — ACE zip-tie handles capture
                                    diag_log "[GROUND-DEALER] Pilot killed (low alt) — dealer ejected.";
                                } else {
                                    diag_log "[GROUND-DEALER] Pilot killed at altitude — helicopter crashing.";
                                };
                            };
                        };
                    };
                };

                diag_log "[GROUND-DEALER] Helicopter escape in progress.";
            };
        };

    } else {
        // === GROUND VEHICLE ESCAPE ===
        if (!isNull _escapeVeh && alive _escapeVeh) then {
            // Arms dealer boards escape vehicle
            _dealer assignAsCargo _escapeVeh;
            [_dealer] orderGetIn true;

            private _boardTime = diag_tickTime + 20;
            waitUntil {
                sleep 1;
                (vehicle _dealer == _escapeVeh)
                || {!alive _dealer}
                || {_dealer getVariable ["DYN_dealerCaptured", false]}
                || {_dealer getVariable ["DYN_isPrisoner", false]}
                || {diag_tickTime > _boardTime}
            };

            if (alive _dealer && vehicle _dealer != _escapeVeh
                && !(_dealer getVariable ["DYN_dealerCaptured", false])
                && !(_dealer getVariable ["DYN_isPrisoner", false])) then {
                _dealer moveInCargo _escapeVeh;
            };

            if (alive _dealer && vehicle _dealer == _escapeVeh) then {
                // Lock dealer in cargo — prevent seat-switching to driver
                _dealer assignAsCargo _escapeVeh;
                _escapeVeh lockDriver true;

                // Drive to escape point
                private _grp = group (driver _escapeVeh);
                for "_i" from (count waypoints _grp - 1) to 0 step -1 do { deleteWaypoint [_grp, _i]; };

                private _wp = _grp addWaypoint [_escapePos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "CARELESS";
                _wp setWaypointCompletionRadius 200;

                // Monitor: if driver dies, stop vehicle and eject the dealer
                [_escapeVeh, _dealer] spawn {
                    params ["_veh", "_dealer"];
                    while {alive _veh} do {
                        sleep 2;
                        private _d = driver _veh;
                        if (isNull _d || {!alive _d}) exitWith {
                            _veh engineOn false;
                            _veh setFuel 0;
                            _veh lockDriver false;

                            // Eject dealer so players can capture him
                            if (alive _dealer && vehicle _dealer == _veh) then {
                                unassignVehicle _dealer;
                                moveOut _dealer;
                                // Leave him as a normal unit — ACE zip-tie handles capture
                            };

                            diag_log "[GROUND-DEALER] Escape driver killed — vehicle stopped, dealer ejected.";
                        };
                    };
                };

                // Escort vehicles — follow the escape vehicle dynamically
                {
                    if (!isNull _x && alive _x) then {
                        [_x, _escapeVeh, _escapePos] spawn {
                            params ["_ev", "_targetVeh", "_fallbackPos"];

                            private _eGrp = group (driver _ev);
                            _eGrp setCombatMode "RED";
                            _eGrp setBehaviour "AWARE";

                            // Follow the escape vehicle, updating waypoints as it moves
                            while {alive _ev && alive _targetVeh && alive (driver _ev)} do {
                                private _tPos = getPos _targetVeh;

                                for "_i" from (count waypoints _eGrp - 1) to 0 step -1 do { deleteWaypoint [_eGrp, _i]; };

                                private _wp = _eGrp addWaypoint [_tPos, 0];
                                _wp setWaypointType "MOVE";
                                _wp setWaypointSpeed "FULL";
                                _wp setWaypointBehaviour "AWARE";
                                _wp setWaypointCombatMode "RED";
                                _wp setWaypointCompletionRadius 30;

                                sleep 10;
                            };

                            // Target vehicle stopped/destroyed — drive to escape pos or stop
                            if (alive _ev && alive (driver _ev)) then {
                                for "_i" from (count waypoints _eGrp - 1) to 0 step -1 do { deleteWaypoint [_eGrp, _i]; };
                                private _wp = _eGrp addWaypoint [_fallbackPos, 0];
                                _wp setWaypointType "MOVE";
                                _wp setWaypointSpeed "FULL";
                                _wp setWaypointCombatMode "RED";
                            };

                            // Driver death stop for escort
                            while {alive _ev} do {
                                sleep 2;
                                private _d = driver _ev;
                                if (isNull _d || {!alive _d}) exitWith {
                                    _ev engineOn false;
                                    _ev setFuel 0;
                                    diag_log "[GROUND-DEALER] Escort driver killed — vehicle stopped.";
                                };
                            };
                        };
                    };
                } forEach _escorts;

                diag_log "[GROUND-DEALER] Ground vehicle escape in progress.";
            };
        };
    };
};

// =====================================================
// 9. COMPLETION MONITOR
// =====================================================
private _localEnemies  = +DYN_ground_enemies;
private _localGroups   = +DYN_ground_enemyGroups;
private _localVehs     = +DYN_ground_enemyVehs;
private _localObjects  = +DYN_ground_objects;
private _localMarkers  = +DYN_ground_markers;

[
    _taskId, _timeout, _repReward, _cleanupDelay,
    _dealer, _escapeVeh, _escapePos, _escapeIsHeli,
    _localEnemies, _localGroups, _localVehs, _localObjects, _localMarkers
] spawn {
    params [
        "_tid", "_tOut", "_rep", "_despawnDelay",
        "_dealer", "_escVeh", "_escPos", "_isHeli",
        "_localEnemies", "_localGroups", "_localVehs", "_localObjects", "_localMarkers"
    ];

    private _startTime = diag_tickTime;
    private _escapeDistThreshold = if (_isHeli) then { 2500 } else { 500 };

    waitUntil {
        sleep 5;

        // Success: Dealer captured and delivered to prison
        _dealer getVariable ["DYN_prisonDelivered", false]
        // Fail: Dealer killed
        || {!alive _dealer}
        // Fail: Dealer reached escape destination
        || {alive _dealer && (_dealer distance2D _escPos) < _escapeDistThreshold}
        // Fail: Timeout
        || {(diag_tickTime - _startTime) > _tOut}
    };

    private _delivered = _dealer getVariable ["DYN_prisonDelivered", false];
    private _escaped   = alive _dealer && (_dealer distance2D _escPos) < _escapeDistThreshold;
    private _dead      = !alive _dealer;
    private _timedOut  = (diag_tickTime - _startTime) > _tOut;

    if (_delivered) then {
        [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, true];
        // Rep is awarded by DYN_fnc_awardPrisonerRep in the prison system — no double dip
        ["TaskSucceeded", ["Arms Dealer Captured", "Arms dealer secured and in custody. Outstanding work."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-DEALER] SUCCESS. Rep awarded by prison system.";
    } else {
        if (_dead) then {
            [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, true];
            ["TaskFailed", ["Arms Dealer Killed", "The target is dead. Mission failed."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log "[GROUND-DEALER] FAILED — Arms dealer was killed.";
        } else {
            if (_escaped) then {
                [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, true];
                ["TaskFailed", ["Arms Dealer Escaped", "The target has escaped the area."]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log "[GROUND-DEALER] FAILED — Arms dealer escaped.";
            } else {
                [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, true];
                ["TaskFailed", ["Mission Expired", "Time ran out. The arms dealer has gone dark."]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log "[GROUND-DEALER] FAILED — timed out.";
            };
        };
    };

    // Cleanup markers
    { deleteMarker _x } forEach _localMarkers;
    DYN_ground_markers = DYN_ground_markers - _localMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_ground_active = false;

    diag_log format ["[GROUND-DEALER] Cleanup in %1 seconds", _despawnDelay];
    sleep _despawnDelay;

    // Delete vehicles (crew first)
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            deleteVehicle _x;
        };
    } forEach _localVehs;

    // Delete remaining enemies (skip prison-delivered units)
    {
        if (!isNull _x) then {
            if (_x getVariable ["DYN_prisonDelivered", false]) then { continue };
            deleteVehicle _x;
        };
    } forEach _localEnemies;

    // Delete objects (smoke, etc.)
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localObjects;

    // Delete groups
    { if (!isNull _x) then { deleteGroup _x } } forEach _localGroups;

    DYN_ground_enemies     = DYN_ground_enemies     - _localEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups  - _localGroups;
    DYN_ground_enemyVehs   = DYN_ground_enemyVehs   - _localVehs;
    DYN_ground_objects     = DYN_ground_objects      - _localObjects;

    diag_log "[GROUND-DEALER] Full cleanup complete.";
};

diag_log "[GROUND-DEALER] Capture Arms Dealer mission initialized successfully.";
