/*
    scripts\groundMissions\fn_civilianTruckRepair.sqf
    GROUND MISSION: Civilian Vehicle Recovery

    Intel from local contacts has flagged a stranded civilian vehicle on the
    outskirts of a settlement. The vehicle is non-operational: a blown wheel
    and sustained engine damage have left the driver unable to continue.

    Two variants spawn at random:
      PEACEFUL — No enemy contact. Pure engineering and humanitarian support.
      AMBUSH   — Enemy insurgents are concealed inside nearby buildings,
                 waiting to exploit the situation. They break cover the
                 moment friendly forces enter the area.

    ENGINEER TASK:
      Repair the truck using ACE repair tools. Full restoration is not
      possible in the field — the objective is to return the vehicle to
      operational (driveable) condition. Partial repairs are sufficient.

    MEDIC TASK (optional, bonus):
      If the driver has sustained injuries, treat the casualty for a
      reputation bonus.

    REWARDS:
      Truck repaired to operational status:  +10-20 REP
      Civilian driver treated:               +5  REP (bonus)
      Civilian driver killed:                -10 REP (penalty)

    FAIL CONDITIONS:
      2-hour mission timer expires.

    CUP RUSSIAN FORCES (ambush variant)
*/
if (!isServer) exitWith {};

diag_log "[GROUND-REPAIR] Setting up Civilian Truck Repair mission...";

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
// 2. FIND MISSION POSITION (town / settlement)
// =====================================================
private _missionPos = [];
private _mapSz = worldSize;

for "_i" from 1 to 400 do {
    private _x = 300 + random (_mapSz - 600);
    private _y = 300 + random (_mapSz - 600);
    private _p = [_x, _y, 0];

    if (surfaceIsWater _p) then { continue };
    if (_p distance2D _basePos < 2000) then { continue };
    if !(_aoCenter isEqualTo [0,0,0]) then {
        if (_p distance2D _aoCenter < 1500) then { continue };
    };

    // Must be in a populated area with road access
    if (count (_p nearRoads 80) == 0) then { continue };
    if (count (nearestObjects [_p, ["House", "Building"], 120]) < 3) then { continue };

    // Gentle terrain only — truck broke down, not drove off a cliff
    private _heights = [];
    {
        private _chkPos = [_p, 30, _x] call DYN_fnc_posOffset;
        _heights pushBack (getTerrainHeightASL _chkPos);
    } forEach [0, 90, 180, 270];
    if ((selectMax _heights) - (selectMin _heights) > 5) then { continue };

    _missionPos = _p;
    break;
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

// --- Damage: remove one wheel + partial engine damage ---
// The truck is too far gone for a full field repair — partial is the goal.
private _allHp   = getAllHitPointsDamage _truck;
private _hpNames = _allHp select 0;
private _wheelHp = "";
{
    if (_x find "Wheel" > -1 || _x find "wheel" > -1) exitWith { _wheelHp = _x; };
} forEach _hpNames;

if (_wheelHp != "") then {
    _truck setHitPointDamage [_wheelHp, 1.0];  // Wheel is completely gone
    diag_log format ["[GROUND-REPAIR] Wheel removed: %1", _wheelHp];
} else {
    _truck setDamage 0.35;
    diag_log "[GROUND-REPAIR] No wheel hitpoint found — applied generic structural damage.";
};

// Engine damage — partial, can be improved but not fully fixed without a workshop
_truck setHit ["HitEngine", 0.65];

// Store wheel hitpoint name on vehicle for monitor to reference
_truck setVariable ["DYN_wheelHp", _wheelHp, false];

diag_log format ["[GROUND-REPAIR] Truck damage after setup: %1", damage _truck];

// =====================================================
// 4. SPAWN CIVILIAN DRIVER (distressed, standing near truck)
// =====================================================
private _civPos = [_truckPos, 3 + random 4, random 360] call DYN_fnc_posOffset;
private _civGrp = createGroup civilian;
private _civilian = _civGrp createUnit ["C_man_1", _civPos, [], 0, "NONE"];
_civilian disableAI "MOVE";
_civilian disableAI "PATH";
_civilian disableAI "AUTOCOMBAT";
_civilian disableAI "TARGET";
_civilian disableAI "WEAPON";
_civilian allowFleeing 0;
_civilian setUnitPos "STAND";
_civilian setDir (_civPos getDir _truckPos);
DYN_ground_objects pushBack _civilian;

if (_civIsInjured) then {
    // Apply ACE unconscious state if available, otherwise raw damage
    if (!isNil "ace_medical_fnc_setUnconscious") then {
        [_civilian, true] remoteExec ["ace_medical_fnc_setUnconscious", 0];
    } else {
        _civilian setDamage 0.55;
    };
    _civilian setVariable ["DYN_civNeedsMedic", true, true];
    diag_log "[GROUND-REPAIR] Civilian driver is injured — medic required.";
} else {
    _civilian setVariable ["DYN_civNeedsMedic", false, true];
};

diag_log "[GROUND-REPAIR] Civilian driver spawned.";

// =====================================================
// 5. SPAWN AMBUSH ENEMIES (hidden in buildings, if ambush variant)
// =====================================================
private _ambushGrp = objNull;

if (_isAmbush) then {
    private _grp = createGroup east;
    DYN_ground_enemyGroups pushBack _grp;
    _grp setBehaviour "SAFE";
    _grp setCombatMode "RED";

    private _nearHouses = nearestObjects [_missionPos, ["House", "Building"], 150];
    private _enemyCount = 4 + floor (random 5);  // 4-8 insurgents

    for "_i" from 1 to _enemyCount do {
        private _spawnPos = _missionPos;

        if (count _nearHouses > 0) then {
            private _bldg = selectRandom _nearHouses;
            private _bldgPositions = [_bldg, 0] call BIS_fnc_buildingPositions;
            _spawnPos = if (count _bldgPositions > 0) then {
                selectRandom _bldgPositions
            } else {
                [getPos _bldg, 4 + random 8, random 360] call DYN_fnc_posOffset
            };
        } else {
            _spawnPos = [_missionPos, 25 + random 80, random 360] call DYN_fnc_posOffset;
        };

        private _u = _grp createUnit [selectRandom _enemyPool, _spawnPos, [], 0, "NONE"];
        if (!isNull _u) then {
            _u disableAI "MOVE";
            _u disableAI "AUTOCOMBAT";
            _u allowFleeing 0;
            _u setSkill 0.45;
            DYN_ground_enemies pushBack _u;
        };
    };

    _ambushGrp = _grp;
    diag_log format ["[GROUND-REPAIR] Ambush squad ready: %1 units concealed in %2 structures.",
        _enemyCount, count _nearHouses];
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
_mkrName setMarkerText "Civilian Assistance";
DYN_ground_markers pushBack _mkrName;

private _medNote = if (_civIsInjured) then {
    "<br/><br/><t color='#ffaa44'>MEDIC PRIORITY:</t> The driver has sustained injuries. A trained medic should assess and treat the casualty before he deteriorates further. Treating him earns an additional +5 REP."
} else { "" };

private _intelNote = if (_isAmbush) then {
    "<br/><br/><t color='#ff5555'>INTEL WARNING:</t> SIGINT indicates possible insurgent presence in the vicinity. Maintain 360-degree security while repairs are being conducted. Do not get tunnel vision on the vehicle."
} else { "" };

[
    west,
    _taskId,
    [
        format [
            "CHARLIE SIX, this is ECHO-2 ACTUAL.<br/><br/>Local contacts have flagged a stranded civilian vehicle on the outskirts of the settlement at grid %1. The driver is unable to continue — the vehicle has sustained a blown wheel and significant engine damage from a previous incident on the route.<br/><br/>We are tasking an engineering element to the location. Get eyes on the vehicle, assess the damage, and perform field repairs using your ACE repair tools. Be advised: the extent of the damage means full restoration is not achievable in the field. Your mission is to return the vehicle to operational condition — get it moving, that is all we ask.<br/><br/><t color='#88ff88'>PRIMARY OBJECTIVE:</t> Repair the civilian truck to driveable condition. (+%2 REP)%3%4<br/><br/>This is a hearts-and-minds operation. Protect the civilian and avoid collateral damage. Time limit: 2 hours. Charlie Six out.",
            mapGridPosition _missionPos,
            _repRewardRepair,
            _medNote,
            _intelNote
        ],
        "CIVASSIST: Vehicle Recovery",
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
// 7. MONITORING — AMBUSH TRIGGER + REPAIR/MEDIC CHECKS
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

    ["TaskCreated", ["Civilian Assistance", "Stranded vehicle reported. Engineer and possible medic required."]]
        remoteExecCall ["BIS_fnc_showNotification", 0];

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
            ["TaskFailed", ["Civilian KIA", format ["%1 REP: The civilian driver was killed.", _repPenalty]]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log format ["[GROUND-REPAIR] Civilian killed. %1 rep penalty.", _repPenalty];
        };

        // --- Ambush trigger: enemies break cover when players close in ---
        if (_isAmbush && !_ambushFired && !isNull _ambushGrp) then {
            private _playersNear = { alive _x && _x distance2D _mPos < 120 } count allPlayers;
            if (_playersNear > 0) then {
                _ambushFired = true;

                { if (alive _x) then { _x enableAI "MOVE"; _x enableAI "AUTOCOMBAT"; }; } forEach units _ambushGrp;
                _ambushGrp setBehaviour "COMBAT";
                _ambushGrp setCombatMode "RED";
                _ambushGrp setSpeedMode "FULL";

                // SAD waypoint toward nearest player
                private _nearestPl = allPlayers select { alive _x } select 0;
                if (!isNil "_nearestPl") then {
                    private _wp = _ambushGrp addWaypoint [getPos _nearestPl, 0];
                    _wp setWaypointType "SAD";
                };

                ["TaskFailed", ["AMBUSH!", "Enemy forces have broken from cover — contact in the settlement!"]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log "[GROUND-REPAIR] AMBUSH triggered.";
            };
        };

        // --- Civilian treated: bonus rep, one time ---
        if (_civIsInjured && !_civHealRewarded && !isNull _civilian && alive _civilian) then {
            private _civHealed = false;

            // Primary check: ACE blood volume restored to normal
            private _bloodVol = _civilian getVariable ["ace_medical_bloodVolume", -1];
            if (_bloodVol >= 0 && _bloodVol > 5.5) then { _civHealed = true; };

            // Fallback: raw damage cleared
            if (!_civHealed && damage _civilian < 0.2) then { _civHealed = true; };

            if (_civHealed) then {
                _civHealRewarded = true;
                [_repMedic, "Civilian Driver Treated"] call DYN_fnc_changeReputation;
                ["TaskSucceeded", ["Medic — Good Work", format ["+%1 REP: Driver treated. He'll make it.", _repMedic]]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log format ["[GROUND-REPAIR] Civilian treated. +%1 rep.", _repMedic];
            };
        };

        // --- Truck repair success: wheel hitpoint restored (partial repair = mission done) ---
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
                ["TaskSucceeded", ["Vehicle Recovered", format ["+%1 REP: Truck is operational. Good work, Charlie.", _repRepair]]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log format ["[GROUND-REPAIR] SUCCESS. Truck repaired. +%1 rep.", _repRepair];

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

    diag_log format ["[GROUND-REPAIR] Despawning entities in %1 seconds.", _despawnDelay];
    sleep _despawnDelay;

    { if (!isNull _x) then { deleteVehicle _x } } forEach _lObjects;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _lEnemies;
    { if (!isNull _x) then { deleteGroup _x } } forEach _lGroups;

    DYN_ground_objects     = DYN_ground_objects     - _lObjects;
    DYN_ground_enemies     = DYN_ground_enemies     - _lEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _lGroups;

    diag_log "[GROUND-REPAIR] Full cleanup complete.";
};

diag_log "[GROUND-REPAIR] Civilian Truck Repair mission initialized.";
