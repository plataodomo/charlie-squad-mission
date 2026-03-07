/*
    scripts\groundMissions\fn_civilianTruckRepair.sqf
    GROUND MISSION: Repair Civilian Vehicle

    A civilian vehicle has broken down in a settlement outside the AO.
    The driver is stranded — the vehicle has sustained a destroyed wheel
    and significant engine damage, likely from road debris or a prior
    incident on the route.

    An engineering element is required on-site to perform field repairs and
    return the vehicle to operational condition. Full restoration is not
    achievable in the field — partial repair only, sufficient to get the
    vehicle moving.

    Two variants spawn at random:
      PEACEFUL — No enemy contact. Engineering and humanitarian support only.
      AMBUSH   — Enemy insurgents are concealed inside nearby buildings.
                 They break cover when friendly forces enter the area.

    ENGINEER TASK:
      Repair the truck using ACE repair tools. Success triggers when the
      wheel is repaired — this represents the minimum to make the vehicle
      driveable again. The engine will remain partially damaged.

    MEDIC TASK (optional, bonus):
      If the driver is injured, treat the casualty for a reputation bonus.

    REWARDS:
      Truck repaired to operational status:  +10-20 REP
      Civilian driver treated:               +5  REP (bonus)
      Civilian driver killed:                -10 REP (penalty)

    FAIL CONDITIONS:
      2-hour mission timer expires.

    CUP RUSSIAN FORCES (ambush variant)
*/
if (!isServer) exitWith {};

diag_log "[GROUND-REPAIR] Setting up Repair Civilian Vehicle mission...";

if (isNil "DYN_ground_enemies")     then { DYN_ground_enemies = [] };
if (isNil "DYN_ground_enemyVehs")   then { DYN_ground_enemyVehs = [] };
if (isNil "DYN_ground_enemyGroups") then { DYN_ground_enemyGroups = [] };
if (isNil "DYN_ground_objects")     then { DYN_ground_objects = [] };
if (isNil "DYN_ground_tasks")       then { DYN_ground_tasks = [] };
if (isNil "DYN_ground_markers")     then { DYN_ground_markers = [] };

private _basePos  = getMarkerPos "respawn_west";
private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

// =====================================================
// 1. SETTINGS
// =====================================================
private _timeout         = 7200;
private _repRewardRepair = 10 + floor (random 11);  // 10-20 rep
private _repRewardMedic  = 5;                        // +5 bonus
private _repPenaltyCiv   = -10;                      // civilian killed
private _zoneRadius      = 150;
private _cleanupDelay    = 120;
private _isAmbush        = (random 1) > 0.5;
private _civIsInjured    = (random 1) > 0.5;

private _enemyPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

private _truckPool = [
    "C_Van_01_transport_F",
    "C_Truck_02_transport_F"
];

diag_log format ["[GROUND-REPAIR] Variant: %1 | Civ injured: %2",
    if (_isAmbush) then {"AMBUSH"} else {"PEACEFUL"}, _civIsInjured];

// =====================================================
// 2. FIND MISSION POSITION (named village / city)
// =====================================================
private _missionPos = [];
private _mapSz = worldSize;

// Prefer named map locations — they are guaranteed to have settlements
private _allLocs = nearestLocations [[_mapSz / 2, _mapSz / 2, 0],
    ["NameCity", "NameCityCapital", "NameVillage"], _mapSz];
private _shuffledLocs = _allLocs call BIS_fnc_arrayShuffle;

{
    private _lPos = locationPosition _x;
    if (surfaceIsWater _lPos) then { continue };
    if (_lPos distance2D _basePos < 2000) then { continue };
    if !(_aoCenter isEqualTo [0,0,0]) then {
        if (_lPos distance2D _aoCenter < 1500) then { continue };
    };
    if (count (_lPos nearRoads 120) == 0) then { continue };
    if (count (nearestObjects [_lPos, ["House", "Building"], 150]) < 6) then { continue };

    _missionPos = _lPos;
    break;
} forEach _shuffledLocs;

// Fallback: random point search if no named location qualified
if (_missionPos isEqualTo []) then {
    diag_log "[GROUND-REPAIR] No named location found — falling back to random search.";
    for "_i" from 1 to 400 do {
        private _rx = 300 + random (_mapSz - 600);
        private _ry = 300 + random (_mapSz - 600);
        private _p  = [_rx, _ry, 0];
        if (surfaceIsWater _p) then { continue };
        if (_p distance2D _basePos < 2000) then { continue };
        if !(_aoCenter isEqualTo [0,0,0]) then {
            if (_p distance2D _aoCenter < 1500) then { continue };
        };
        if (count (_p nearRoads 80) == 0) then { continue };
        if (count (nearestObjects [_p, ["House", "Building"], 150]) < 6) then { continue };
        _missionPos = _p;
        break;
    };
};

if (_missionPos isEqualTo []) exitWith {
    diag_log "[GROUND-REPAIR] Could not find suitable town position. Aborting.";
    DYN_ground_active = false;
};

diag_log format ["[GROUND-REPAIR] Mission position: %1", _missionPos];

// =====================================================
// 3. SPAWN CIVILIAN TRUCK (DAMAGED)
// =====================================================
private _roadList = _missionPos nearRoads 80;
private _truckPos = if (count _roadList > 0) then {
    [getPos (selectRandom _roadList), 3 + random 4, 90] call DYN_fnc_posOffset
} else {
    [_missionPos, 6 + random 4, random 360] call DYN_fnc_posOffset
};

private _truckClass = selectRandom _truckPool;
private _truck = createVehicle [_truckClass, _truckPos, [], 0, "NONE"];
_truck setDir (random 360);
_truck setFuel 0.3;
_truck engineOn false;
DYN_ground_objects pushBack _truck;

diag_log format ["[GROUND-REPAIR] Truck spawned: %1 at %2", _truckClass, _truckPos];

// Apply damage: one random wheel destroyed + partial engine damage
private _allHp   = getAllHitPointsDamage _truck;
private _hpNames = _allHp select 0;

// Collect ALL wheel hitpoints and pick one at random — previously exitWith always
// selected the first wheel in config order (same wheel every mission).
private _wheelHps = _hpNames select { _x find "Wheel" > -1 || _x find "wheel" > -1 };
private _wheelHp  = if (count _wheelHps > 0) then { selectRandom _wheelHps } else { "" };

if (_wheelHp != "") then {
    _truck setHitPointDamage [_wheelHp, 1.0];
    diag_log format ["[GROUND-REPAIR] Wheel destroyed: %1", _wheelHp];
} else {
    _truck setDamage 0.35;
    diag_log "[GROUND-REPAIR] No wheel hitpoint found — applied generic damage.";
};

_truck setHitPointDamage ["HitEngine", 0.65];

_truck setVariable ["DYN_wheelHp", _wheelHp, false];

diag_log format ["[GROUND-REPAIR] Truck damage after setup: %1", damage _truck];

// =====================================================
// 4. SPAWN CIVILIAN DRIVER
// =====================================================
private _civPos = [_truckPos, 3 + random 4, random 360] call DYN_fnc_posOffset;
private _civGrp = createGroup civilian;
private _civilian = _civGrp createUnit ["C_man_1", _civPos, [], 0, "NONE"];
_civilian disableAI "MOVE";
_civilian disableAI "PATH";
_civilian disableAI "AUTOCOMBAT";
_civilian disableAI "TARGET";
_civilian allowFleeing 0;
_civilian setUnitPos "UP";
_civilian setDir (_civPos getDir _truckPos);
DYN_ground_objects pushBack _civilian;

if (_civIsInjured) then {
    _civilian setVariable ["DYN_isCivilian",  true, true];
    _civilian setVariable ["DYN_isWounded",   true, true];
    _civilian setVariable ["DYN_repAwarded",  false, true];
    _civilian setCaptive true;
    _civilian setUnitPos "DOWN";
    [_civilian, "Acts_LyingWounded_01"] remoteExec ["switchMove", 0];

    [_civilian] spawn {
        params ["_civ"];
        sleep 1;
        if (isNull _civ || !alive _civ) exitWith {};

        _civ setVariable ["ACE_isUnconscious",      true,  true];
        _civ setVariable ["ace_medical_ai_healSelf", false, true];
        _civ setUnconscious true;

        if (!isNil "ace_medical_fnc_addDamageToUnit") then {
            [_civ, 0.5, "body",    "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            [_civ, 0.4, "leftleg", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            diag_log "[GROUND-REPAIR] ACE wounds applied to civilian driver.";
        } else {
            _civ setDamage 0.6;
            diag_log "[GROUND-REPAIR] Vanilla fallback damage applied (no ACE).";
        };

        // Enforce lying animation until treated
        for "_i" from 1 to 5 do {
            sleep 1;
            if (isNull _civ || !alive _civ) exitWith {};
            _civ setUnitPos "DOWN";
            [_civ, "Acts_LyingWounded_01"] remoteExec ["switchMove", 0];
        };

        while { !isNull _civ && alive _civ && (_civ getVariable ["ACE_isUnconscious", false]) } do {
            sleep 30;
            if (isNull _civ || !alive _civ) exitWith {};
            _civ setUnitPos "DOWN";
            [_civ, "Acts_LyingWounded_01"] remoteExec ["switchMove", 0];
        };
    };

    diag_log "[GROUND-REPAIR] Civilian driver injured — medic required.";
} else {
    _civilian setVariable ["DYN_isCivilian", true, true];
    diag_log "[GROUND-REPAIR] Civilian driver uninjured.";
};

// =====================================================
// 5. SPAWN AMBUSH ENEMIES (hidden in buildings, if ambush variant)
// =====================================================
private _ambushGrp = objNull;

if (_isAmbush) then {
    private _grp = createGroup east;
    DYN_ground_enemyGroups pushBack _grp;
    _grp setBehaviour "SAFE";
    _grp setCombatMode "RED";

    // Pre-filter: only keep buildings that actually have interior slot positions
    private _allHouses   = nearestObjects [_missionPos, ["House", "Building"], 150];
    private _validHouses = _allHouses select { count ([_x] call BIS_fnc_buildingPositions) > 0 };

    private _enemyCount = 8 + floor (random 5);  // 8-12 enemies

    for "_i" from 1 to _enemyCount do {
        private _spawnPos = [];

        // Try up to 10 times to get a valid interior slot
        if (count _validHouses > 0) then {
            for "_t" from 1 to 10 do {
                private _bldg     = selectRandom _validHouses;
                private _bldgPos  = [_bldg] call BIS_fnc_buildingPositions;
                if (count _bldgPos > 0) exitWith { _spawnPos = selectRandom _bldgPos; };
            };
        };

        // Fallback: exterior of any house, or general area
        if (_spawnPos isEqualTo []) then {
            if (count _allHouses > 0) then {
                _spawnPos = [getPos (selectRandom _allHouses), 3 + random 6, random 360] call DYN_fnc_posOffset;
            } else {
                _spawnPos = [_missionPos, 20 + random 60, random 360] call DYN_fnc_posOffset;
            };
        };

        private _u = _grp createUnit [selectRandom _enemyPool, _spawnPos, [], 0, "NONE"];
        if (!isNull _u) then {
            _u disableAI "MOVE";
            _u disableAI "PATH";
            _u disableAI "AUTOCOMBAT";
            _u allowFleeing 0;
            _u setSkill 0.45;
            DYN_ground_enemies pushBack _u;
        };
    };

    _ambushGrp = _grp;
    diag_log format ["[GROUND-REPAIR] Ambush squad ready: %1 units. Valid buildings: %2", _enemyCount, count _validHouses];
};

// =====================================================
// 6. TASK + MARKER
// =====================================================
private _taskId  = format ["ground_repair_%1", round (diag_tickTime * 1000)];
private _mkrName = format ["ground_repair_mkr_%1", round (diag_tickTime * 1000)];

createMarker [_mkrName, _missionPos];
_mkrName setMarkerShape "ELLIPSE";
_mkrName setMarkerSize [_zoneRadius, _zoneRadius];
_mkrName setMarkerColor "ColorOrange";
_mkrName setMarkerBrush "SolidFull";
_mkrName setMarkerAlpha 0.2;
_mkrName setMarkerText "Civilian Vehicle";
DYN_ground_markers pushBack _mkrName;

// Nearest town name for the description
private _nearLocs = nearestLocations [_missionPos, ["NameCity","NameCityCapital","NameVillage"], 600];
private _cityName = if (count _nearLocs > 0) then { text (_nearLocs select 0) } else { "a nearby settlement" };

private _medNote = if (_civIsInjured) then {
    "<br/><br/>The driver has sustained injuries and requires immediate medical attention. A trained medic should assess and treat the casualty on-site."
} else { "" };

[
    west,
    _taskId,
    [
        format [
            "A civilian vehicle has been reported broken down near %1. The driver is unable to continue — the vehicle has sustained a destroyed wheel and significant engine damage, likely from road debris encountered on the route.<br/><br/>An engineering element is required on-site to perform field repairs and return the vehicle to operational condition.%2",
            _cityName,
            _medNote
        ],
        "Repair Civilian Vehicle",
        ""
    ],
    _missionPos,
    "CREATED",
    3,
    true,
    "repair"
] remoteExec ["BIS_fnc_taskCreate", 0, _taskId];

DYN_ground_tasks pushBack _taskId;

diag_log format ["[GROUND-REPAIR] Task created: %1. Mission active.", _taskId];

// =====================================================
// 7. MONITORING — AMBUSH TRIGGER + REPAIR / MEDIC CHECKS
// =====================================================
private _localObjects = +DYN_ground_objects;
private _localEnemies = +DYN_ground_enemies;
private _localGroups  = +DYN_ground_enemyGroups;
private _localMarkers = +DYN_ground_markers;

[
    _truck, _civilian, _ambushGrp, _isAmbush, _civIsInjured,
    _taskId, _timeout, _cleanupDelay,
    _repRewardRepair, _repRewardMedic, _repPenaltyCiv,
    _mkrName, _missionPos,
    _localObjects, _localEnemies, _localGroups, _localMarkers
] spawn {
    params [
        "_truck", "_civilian", "_ambushGrp", "_isAmbush", "_civIsInjured",
        "_tid", "_tOut", "_despawnDelay",
        "_repRepair", "_repMedic", "_repPenalty",
        "_mkr", "_mPos",
        "_lObjects", "_lEnemies", "_lGroups", "_lMarkers"
    ];

    private _startTime        = diag_tickTime;
    private _ambushFired      = false;
    private _civHealRewarded  = false;
    private _truckSucceeded   = false;
    private _civKillPenalized = false;
    private _done             = false;
    // Last tick a player was within 10 m of the civilian.
    // Rep is only awarded if this was recent (< 30 s ago), so Zeus healing
    // from afar or a self-heal with nobody on-site cannot trigger the reward.
    private _lastPlayerNearTime = -1;

    while { !_done } do {
        sleep 5;

        // --- Timeout ---
        if (diag_tickTime - _startTime > _tOut) then {
            [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
            ["TaskFailed", ["Mission Expired", "The vehicle could not be recovered in time."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log "[GROUND-REPAIR] TIMEOUT. Mission failed.";
            _done = true;
            continue;
        };

        // --- Civilian killed: one-time rep penalty ---
        if (!_civKillPenalized && !isNull _civilian && !alive _civilian) then {
            _civKillPenalized = true;
            [_repPenalty, "Civilian Killed"] call DYN_fnc_changeReputation;
            ["TaskFailed", ["Civilian KIA", format ["%1 REP. The driver was killed.", _repPenalty]]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log format ["[GROUND-REPAIR] Civilian killed. %1 rep.", _repPenalty];
        };

        // --- Ambush trigger: enemies break cover when players approach the truck ---
        if (_isAmbush && !_ambushFired && !isNull _ambushGrp) then {
            private _truckPos2D = getPos _truck;
            private _playersNear = { alive _x && _x distance2D _truckPos2D < 80 } count allPlayers;
            if (_playersNear > 0) then {
                _ambushFired = true;

                {
                    if (alive _x) then {
                        _x enableAI "MOVE";
                        _x enableAI "PATH";
                        _x enableAI "AUTOCOMBAT";
                    };
                } forEach units _ambushGrp;

                _ambushGrp setBehaviour "COMBAT";
                _ambushGrp setCombatMode "RED";
                _ambushGrp setSpeedMode "FULL";

                // SAD waypoint on the nearest alive player
                private _alivePlayers = allPlayers select { alive _x };
                if (count _alivePlayers > 0) then {
                    private _nearestPlayer = _alivePlayers select 0;
                    {
                        if (_x distance2D _truckPos2D < _nearestPlayer distance2D _truckPos2D) then {
                            _nearestPlayer = _x;
                        };
                    } forEach _alivePlayers;
                    private _wp = _ambushGrp addWaypoint [getPos _nearestPlayer, 0];
                    _wp setWaypointType "SAD";
                };

                diag_log "[GROUND-REPAIR] AMBUSH triggered.";
            };
        };

        // --- Civilian healed: bonus rep, one time ---
        // Always track whether any player is within treatment range (10 m), even
        // before the heal check window opens.  This timestamp is used below to
        // confirm a player was actively on-site when healing occurred, blocking
        // Zeus remote-heals and AI self-heals that happen with nobody nearby.
        if (_civIsInjured && !_civHealRewarded && alive _civilian) then {
            if ({ alive _x && _x distance2D (getPos _civilian) < 10 } count allPlayers > 0) then {
                _lastPlayerNearTime = diag_tickTime;
            };
        };

        // Heal check opens after 30 s (ACE wounds need time to be applied server-side).
        // Civilian is considered "treated" when:
        //   ACE loaded  → no longer unconscious (conscious = stabilised / revived)
        //   Vanilla only → vanilla damage below 0.2
        // PLUS a player must have been within 10 m in the last 30 seconds.
        // This correctly handles: full blood + revived (conscious), partial heal, and
        // blocks Zeus heal / self-heal with no player on-site.
        if (_civIsInjured && !_civHealRewarded && alive _civilian
            && diag_tickTime - _startTime > 30) then {

            private _civHealed = if (!isNil "ace_medical_fnc_addDamageToUnit") then {
                // ACE: civ is conscious (ACE_isUnconscious default true = still injured)
                !(_civilian getVariable ["ACE_isUnconscious", true])
            } else {
                // Vanilla fallback only — ACE wounds don't raise vanilla damage value
                damage _civilian < 0.2
            };

            if (_civHealed
                && _lastPlayerNearTime > 0
                && (diag_tickTime - _lastPlayerNearTime) < 30) then {
                _civHealRewarded = true;
                [_repMedic, "Civilian Driver Treated"] call DYN_fnc_changeReputation;
                ["TaskSucceeded", ["Casualty Treated", format ["+%1 REP. Driver is stable.", _repMedic]]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log format ["[GROUND-REPAIR] Civilian treated. +%1 rep.", _repMedic];
            };
        };

        // --- Truck repair success: wheel hitpoint restored ---
        if (!_truckSucceeded && !isNull _truck) then {
            private _wheelHp = _truck getVariable ["DYN_wheelHp", ""];
            private _wheelFixed = if (_wheelHp != "") then {
                (_truck getHitPointDamage _wheelHp) < 0.3
            } else {
                damage _truck < 0.35
            };

            if (_wheelFixed) then {
                _truckSucceeded = true;
                [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
                [_repRepair, "Civilian Truck Repaired"] call DYN_fnc_changeReputation;
                diag_log format ["[GROUND-REPAIR] SUCCESS. Truck repaired. +%1 rep.", _repRepair];

                // Civilian stands up, walks to the truck, and drives away
                [_truck, _civilian] spawn {
                    params ["_veh", "_civ"];
                    sleep 2;
                    if (isNull _civ || isNull _veh) exitWith {};

                    _civ setUnitPos "AUTO";
                    _civ enableAI "MOVE";
                    _civ enableAI "PATH";
                    _veh setFuel 0.9;
                    _veh setHit ["HitEngine", 0.05];

                    // Walk to vehicle — same pattern as arms dealer boarding
                    _civ assignAsDriver _veh;
                    [_civ] orderGetIn true;

                    private _boardTime = diag_tickTime + 30;
                    waitUntil {
                        sleep 1;
                        (vehicle _civ == _veh)
                        || isNull _civ || !alive _civ
                        || diag_tickTime > _boardTime
                    };

                    // Force seat if they didn't make it in time
                    if (alive _civ && vehicle _civ != _veh) then {
                        _civ moveInDriver _veh;
                    };

                    if (alive _civ && vehicle _civ == _veh) then {
                        _veh engineOn true;
                        private _drivePos = [getPos _veh, 150 + random 100, random 360] call DYN_fnc_posOffset;
                        _civ doMove _drivePos;
                        diag_log "[GROUND-REPAIR] Civilian driver heading out.";
                    };

                    sleep 90;
                    if (!isNull _civ) then { deleteVehicle _civ };
                    if (!isNull _veh) then { deleteVehicle _veh };
                };

                sleep 30;
                _done = true;
            };
        };
    };

    // --- Task and marker cleanup ---
    { deleteMarker _x } forEach _lMarkers;
    DYN_ground_markers = DYN_ground_markers - _lMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_ground_active = false;

    diag_log format ["[GROUND-REPAIR] Despawning in %1 seconds.", _despawnDelay];
    sleep _despawnDelay;

    { if (!isNull _x) then { deleteVehicle _x } } forEach _lObjects;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _lEnemies;
    { if (!isNull _x) then { deleteGroup _x } } forEach _lGroups;

    DYN_ground_objects     = DYN_ground_objects     - _lObjects;
    DYN_ground_enemies     = DYN_ground_enemies     - _lEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _lGroups;

    diag_log "[GROUND-REPAIR] Full cleanup complete.";
};

diag_log "[GROUND-REPAIR] Repair Civilian Vehicle mission initialized.";
