/*
    scripts\groundMissions\fn_hostageRescue.sqf
    GROUND MISSION: Hostage Rescue

    Enemy forces are holding 1-3 civilians captive inside multi-story buildings
    in a nearby town. Hostages are zip-tied and scattered across different floors.
    Players must locate each hostage, cut their zip ties, and escort them to the
    medical zone at base.

    Composition:
        - 1-3 hostages, one per large building, on upper floors where possible
        - 3-5 indoor guards per hostage building
        - 1-2 exterior patrol groups (4-6 each)
        - Total: ~12-25 enemy combatants

    Success:    All living freed hostages reach the medical_zone marker.
                At least 1 hostage must survive and be escorted to base.
    Fail:       All hostages killed before rescue, or 40-min timeout with 0 saved.
    Partial:    Timeout with 1+ already rescued counts as success.

    Reward:     10 + (4 × rescued) + random 3 rep
                  1 saved  : ~14–17 rep
                  2 saved  : ~18–21 rep
                  3 saved  : ~22–25 rep
    Penalty:    -3 rep (one-time) the first time any hostage is killed

    Notes:
        - Hostages use ACE zip-tie state if ace_captives is loaded; kneeling anim fallback
        - "Cut Zip Ties" addAction (6 m range) sets DYN_freeRequested via global broadcast
        - Server monitor processes release: enables AI, gives MOVE waypoint toward base
        - Rescued civilians despawn 5 minutes after reaching medical_zone
        - Unrescued / dead civilians cleaned up on mission end
        - MP safe
*/
if (!isServer) exitWith {};

diag_log "[GROUND-HOSTAGE] Setting up Hostage Rescue mission...";

if (isNil "DYN_ground_enemies")     then { DYN_ground_enemies     = [] };
if (isNil "DYN_ground_enemyVehs")   then { DYN_ground_enemyVehs   = [] };
if (isNil "DYN_ground_enemyGroups") then { DYN_ground_enemyGroups = [] };
if (isNil "DYN_ground_tasks")       then { DYN_ground_tasks       = [] };

private _basePos  = getMarkerPos "respawn_west";
private _aoCenter = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

private _guardPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn",
    "CUP_O_RU_Soldier_MG_Ratnik_Autumn"
];

// =====================================================
// 1. LOCATION — town with large buildings
// =====================================================
private _locations = nearestLocations [_basePos, ["NameVillage", "NameCity", "NameCityCapital"], 40000];
_locations = _locations select {
    private _d = _x distance _basePos;
    _d > 1800 &&
    { _d < 8000 } &&
    { !surfaceIsWater (getPos _x) } &&
    { _aoCenter isEqualTo [0,0,0] || { _x distance _aoCenter > 600 } }
};

if (_locations isEqualTo []) exitWith {
    diag_log "[GROUND-HOSTAGE] No valid location found — aborting.";
    DYN_ground_active = false;
};

private _loc     = selectRandom _locations;
private _locPos  = getPos _loc;
private _locName = text _loc;

diag_log format ["[GROUND-HOSTAGE] Location: %1 at %2", _locName, _locPos];

// =====================================================
// 2. BUILDING SELECTION — multi-story houses
// =====================================================
private _allBuildings = nearestObjects [_locPos, ["House"], 170];

// Prefer large buildings (>=8 interior positions); fall back to medium (>=4)
private _largeBuildings = _allBuildings select {
    count ([_x] call BIS_fnc_buildingPositions) >= 8 &&
    { !surfaceIsWater (getPos _x) }
};

if (count _largeBuildings < 2) then {
    _largeBuildings = _allBuildings select {
        count ([_x] call BIS_fnc_buildingPositions) >= 4 &&
        { !surfaceIsWater (getPos _x) }
    };
};

if (_largeBuildings isEqualTo []) exitWith {
    diag_log "[GROUND-HOSTAGE] No suitable buildings found — aborting.";
    DYN_ground_active = false;
};

// =====================================================
// 3. HOSTAGE SPAWN — 1-3 civilians on different floors
// =====================================================
private _hostageCount   = 1 + round (random 2);
_hostageCount           = _hostageCount min (count _largeBuildings);

private _hostages       = [];
private _civGroups      = [];
private _usedBldgs      = [];
private _availBldgs     = +_largeBuildings;

private _hasACECaptives = isClass (configFile >> "CfgPatches" >> "ace_captives");

for "_i" from 1 to _hostageCount do {
    if (_availBldgs isEqualTo []) exitWith {};

    private _bldgIdx  = floor (random (count _availBldgs));
    private _bldg     = _availBldgs deleteAt _bldgIdx;

    private _allPos   = [_bldg] call BIS_fnc_buildingPositions;
    // Prefer upper floors (height > 2.5 m above local ground)
    private _upperPos = _allPos select { (_x select 2) > 2.5 };
    private _spawnPos = if (_upperPos isEqualTo []) then { selectRandom _allPos } else { selectRandom _upperPos };

    _usedBldgs pushBack [_bldg, _spawnPos]; // [building, hostagePos] — guards use both

    // Civilian in their own group for independent waypoint control
    private _civGrp = createGroup civilian;
    private _civ    = _civGrp createUnit ["C_man_1", _spawnPos, [], 0, "NONE"];
    _civ setDir (random 360);

    // Restrained state
    _civ disableAI "MOVE";
    _civ disableAI "TARGET";
    _civ disableAI "AUTOTARGET";
    _civ disableAI "FSM";
    _civ disableAI "ANIM";
    _civ setCaptive true;
    _civ allowFleeing 0;
    _civ setUnitPos "MIDDLE";
    _civ switchMove "Acts_AidlPsitMstpSsurSnonWrflDnon_loop2"; // kneeling, hands behind back

    // ACE zip-tie if loaded (sets proper restrained animation and state)
    if (_hasACECaptives) then {
        [_civ, true] call ace_captives_fnc_setHandcuffed;
    };

    // State tracking (broadcast = true for MP sync)
    _civ setVariable ["DYN_isHostage",      true,  true];
    _civ setVariable ["DYN_hostageFreed",   false, true];
    _civ setVariable ["DYN_hostageRescued", false, true];
    _civ setVariable ["DYN_freeRequested",  false, true];
    _civ setVariable ["DYN_hostageIdx",     _i,    false];

    // "Cut Zip Ties" — ACE interact menu preferred, addAction fallback
    if (isClass (configFile >> "CfgPatches" >> "ace_interact_menu")) then {
        private _cutAction = [
            "DYN_cutZipTies",
            "Cut Zip Ties",
            "\a3\ui_f\data\GUI\Cfg\holdAction\holdAction_release_ca.paa",
            {
                params ["_target", "_player", "_params"];
                if (!(_target getVariable ["DYN_hostageFreed", false])) then {
                    _target setVariable ["DYN_freeRequested", true, true];
                };
            },
            {
                params ["_target", "_player", "_params"];
                (_target getVariable ["DYN_isHostage", false]) &&
                !(_target getVariable ["DYN_hostageFreed", false])
            }
        ] call ace_interact_menu_fnc_createAction;
        [_civ, 0, ["ACE_MainActions"], _cutAction] call ace_interact_menu_fnc_addActionToObject;
    } else {
        _civ addAction [
            "<t color='#00FF88'>Cut Zip Ties</t>",
            {
                params ["_target", "_caller"];
                if (!(_target getVariable ["DYN_hostageFreed", false])) then {
                    _target setVariable ["DYN_freeRequested", true, true];
                };
            },
            nil, 6, true, true, "",
            "(_target getVariable ['DYN_isHostage', false]) && {!(_target getVariable ['DYN_hostageFreed', false])}"
        ];
    };

    _hostages  pushBack _civ;
    _civGroups pushBack _civGrp;

    diag_log format ["[GROUND-HOSTAGE] Hostage %1/%2 placed in %3 at %4",
        _i, _hostageCount, typeOf _bldg, _spawnPos];
};

if (_hostages isEqualTo []) exitWith {
    diag_log "[GROUND-HOSTAGE] No hostages spawned — aborting.";
    DYN_ground_active = false;
};

// =====================================================
// 4. GUARDS
// =====================================================
// Interior: guards per hostage building
// 2 guards placed at the hostage's exact room position + 2-3 spread across other floors
{
    _x params ["_bldg", "_hostagePos"];
    private _allPos = [_bldg] call BIS_fnc_buildingPositions;
    if (_allPos isEqualTo []) then { continue };

    private _indoorGrp = createGroup east;
    DYN_ground_enemyGroups pushBack _indoorGrp;

    // 2 guards in the same room as the hostage
    for "_g" from 1 to 2 do {
        private _u = _indoorGrp createUnit [selectRandom _guardPool, _hostagePos, [], 0, "NONE"];
        _u setDir (random 360);
        _u allowFleeing 0;
        [_u] call DYN_fnc_boostOpforAwareness;
        DYN_ground_enemies pushBack _u;
    };

    // 2-3 additional guards spread across other positions in the building
    private _extraCount = 2 + round (random 1);
    for "_g" from 1 to _extraCount do {
        private _gPos = selectRandom _allPos;
        private _u    = _indoorGrp createUnit [selectRandom _guardPool, _gPos, [], 0, "NONE"];
        _u setDir (random 360);
        _u allowFleeing 0;
        [_u] call DYN_fnc_boostOpforAwareness;
        DYN_ground_enemies pushBack _u;
    };

    // SENTRY — hold position, engage on sight
    private _wp = _indoorGrp addWaypoint [_hostagePos, 10];
    _wp setWaypointType "SENTRY";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCombatMode "RED";

} forEach _usedBldgs;

// Exterior: 2-3 patrol groups of 5-7, contained within the zone
private _patrolGroupCount = 2 + round (random 1); // 2-3
for "_p" from 1 to _patrolGroupCount do {
    private _patrolGrp = createGroup east;
    DYN_ground_enemyGroups pushBack _patrolGrp;

    private _pBase = [_locPos, 15 + random 40, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _pBase) then { _pBase = _locPos };

    private _patrolSize = 5 + round (random 2); // 5-7
    for "_u" from 1 to _patrolSize do {
        private _unit = _patrolGrp createUnit [selectRandom _guardPool, _pBase, [], 0, "NONE"];
        _unit allowFleeing 0;
        [_unit] call DYN_fnc_boostOpforAwareness;
        DYN_ground_enemies pushBack _unit;
    };

    // Patrol loop — waypoints kept within ~130 m of location centre (inside 200 m zone)
    for "_w" from 1 to 4 do {
        private _wPos = [_locPos, 20 + random 110, random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _wPos) then { _wPos = _locPos };
        private _wp = _patrolGrp addWaypoint [_wPos, 15];
        _wp setWaypointType "MOVE";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "YELLOW";
        _wp setWaypointSpeed "LIMITED";
    };
    private _cycleWp = _patrolGrp addWaypoint [_pBase, 15];
    _cycleWp setWaypointType "CYCLE";
};

diag_log format ["[GROUND-HOSTAGE] Guards spawned: %1 units, %2 groups",
    count DYN_ground_enemies, count DYN_ground_enemyGroups];

// =====================================================
// 5. TASK & MARKERS
// =====================================================
private _taskId = format ["hr_%1", round time];

[
    west,
    _taskId,
    [
        format [
            "Enemy forces are holding <b>%1 civilian(s)</b> captive inside buildings in <b>%2</b>. Hostages are zip-tied and may be on any floor — search thoroughly.<br/><br/>Locate every hostage, cut their zip ties, and escort them back to the <b>medical zone</b> at base.",
            _hostageCount, _locName
        ],
        "Hostage Rescue",
        ""
    ],
    _locPos,
    "CREATED",
    3,
    true,
    "search"
] remoteExec ["BIS_fnc_taskCreate", 0, _taskId];

DYN_ground_tasks pushBack _taskId;

// Zone ellipse
private _zoneMkr = createMarker [format ["hr_zone_%1", round time], _locPos];
_zoneMkr setMarkerShape "ELLIPSE";
_zoneMkr setMarkerSize [200, 200];
_zoneMkr setMarkerBrush "SolidBorder";
_zoneMkr setMarkerColor "colorOPFOR";
_zoneMkr setMarkerAlpha 0.25;
DYN_ground_markers pushBack _zoneMkr;

diag_log format ["[GROUND-HOSTAGE] Mission active. %1 hostage(s) in %2. Task: %3",
    _hostageCount, _locName, _taskId];

// =====================================================
// 6. MONITOR
// =====================================================
private _localEnemies = +DYN_ground_enemies;
private _localGroups  = +DYN_ground_enemyGroups;
private _localMarkers = +DYN_ground_markers;

[
    _taskId, _hostages, _civGroups,
    _hasACECaptives, _basePos,
    _localEnemies, _localGroups, _localMarkers
] spawn {
    params [
        "_tid", "_hostages", "_civGroups",
        "_hasACE", "_basePos",
        "_lEnemies", "_lGroups", "_lMarkers"
    ];

    private _startTime    = diag_tickTime;
    private _timeout      = 2400; // 40 minutes
    private _cleanupDelay = 120;
    private _done         = false;
    private _outcome      = "TIMEOUT";
    private _rescued      = 0;
    private _penalized    = false;

    while { !_done } do {
        sleep 4;

        // --- Process free requests (server-side release) ---
        {
            private _civ = _x;
            if (
                alive _civ &&
                (_civ getVariable ["DYN_freeRequested",  false]) &&
                !(_civ getVariable ["DYN_hostageFreed",  false])
            ) then {
                _civ setVariable ["DYN_hostageFreed",  true,  true];
                _civ setVariable ["DYN_freeRequested", false, true];

                // Release ACE restraint
                if (_hasACE) then {
                    [_civ, false] call ace_captives_fnc_setHandcuffed;
                };

                // Restore AI and route to base
                _civ enableAI "ANIM";
                _civ enableAI "MOVE";
                _civ enableAI "FSM";
                _civ setCaptive false;
                _civ setUnitPos "AUTO";

                private _civGrp = group _civ;
                for "_wpDel" from (count waypoints _civGrp - 1) to 0 step -1 do {
                    deleteWaypoint [_civGrp, _wpDel];
                };
                private _wp = _civGrp addWaypoint [_basePos, 30];
                _wp setWaypointType "MOVE";
                _wp setWaypointBehaviour "SAFE";
                _wp setWaypointSpeed "LIMITED";

                private _idx   = _civ getVariable ["DYN_hostageIdx", 1];
                private _total = count _hostages;
                ["TaskUpdated", [format ["Hostage %1/%2 freed! Escort to the medical zone.", _idx, _total]]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];

                diag_log format ["[GROUND-HOSTAGE] Hostage %1/%2 freed, walking to base.", _idx, _total];
            };
        } forEach _hostages;

        // --- Detect arrivals at medical_zone ---
        {
            private _civ = _x;
            if (
                alive _civ &&
                (_civ getVariable ["DYN_hostageFreed",    false]) &&
                !(_civ getVariable ["DYN_hostageRescued", false]) &&
                _civ inArea "medical_zone"
            ) then {
                _civ setVariable ["DYN_hostageRescued", true, true];
                _civ disableAI "MOVE"; // stop wandering at base
                private _idx = _civ getVariable ["DYN_hostageIdx", 1];
                diag_log format ["[GROUND-HOSTAGE] Hostage %1 reached medical zone.", _idx];
            };
        } forEach _hostages;

        // --- One-time rep penalty if any hostage is killed ---
        if (!_penalized) then {
            private _anyDead = (_hostages findIf {
                !alive _x && !(_x getVariable ["DYN_hostageRescued", false])
            }) != -1;
            if (_anyDead) then {
                _penalized = true;
                [-3, "Hostage KIA"] call DYN_fnc_changeReputation;
                ["TaskUpdated", ["A hostage has been killed. -3 REP."]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];
                diag_log "[GROUND-HOSTAGE] Hostage killed. -5 rep applied.";
            };
        };

        // --- Evaluate end conditions ---
        private _nDead    = { !alive _x } count _hostages;
        private _nRescued = { _x getVariable ["DYN_hostageRescued", false] } count _hostages;
        private _nTotal   = count _hostages;

        // All hostages accounted for (rescued or dead) and at least 1 made it
        if (_nRescued + _nDead >= _nTotal && _nRescued >= 1) exitWith {
            _rescued = _nRescued;
            _outcome = "SUCCESS";
            _done    = true;
        };

        // All hostages dead, none rescued
        if (_nDead >= _nTotal && _nRescued == 0) exitWith {
            _outcome = "FAILED";
            _done    = true;
        };

        // Timeout
        if (diag_tickTime - _startTime > _timeout) exitWith {
            _rescued = _nRescued;
            _outcome = if (_nRescued > 0) then { "SUCCESS" } else { "TIMEOUT" };
            _done    = true;
        };
    };

    // =====================================================
    // OUTCOME
    // =====================================================
    diag_log format ["[GROUND-HOSTAGE] Outcome: %1 — %2/%3 rescued",
        _outcome, _rescued, count _hostages];

    switch (_outcome) do {
        case "SUCCESS": {
            private _rep = 10 + (4 * _rescued) + round (random 3);

            [_rep, "Hostages Rescued"] call DYN_fnc_changeReputation;
            [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
            ["GroundComplete", [format ["%1/%2 hostage(s) rescued. +%3 REP.",
                _rescued, count _hostages, _rep]]]
                    remoteExecCall ["BIS_fnc_showNotification", 0];

            diag_log format ["[GROUND-HOSTAGE] SUCCESS. +%1 rep.", _rep];

            // Rescued civilians despawn after 5 minutes
            {
                if (_x getVariable ["DYN_hostageRescued", false]) then {
                    private _civ = _x;
                    [_civ] spawn {
                        params ["_c"];
                        sleep 300;
                        if (!isNull _c) then {
                            deleteVehicle _c;
                            diag_log "[GROUND-HOSTAGE] Rescued civilian despawned (5 min).";
                        };
                    };
                };
            } forEach _hostages;
        };

        default {
            [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
            private _msg = if (_outcome == "FAILED") then {
                "All hostages were killed. Mission failed."
            } else {
                "The rescue window has closed. Mission expired."
            };
            ["GroundFailed", [_msg]] remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log format ["[GROUND-HOSTAGE] FAILED. Reason: %1.", _outcome];
        };
    };

    // =====================================================
    // CLEANUP
    // =====================================================
    { deleteMarker _x } forEach _lMarkers;
    DYN_ground_markers = DYN_ground_markers - _lMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_ground_active = false;

    diag_log format ["[GROUND-HOSTAGE] Enemy cleanup in %1 seconds.", _cleanupDelay];
    sleep _cleanupDelay;

    // Remaining unrescued / dead hostages
    {
        if (!isNull _x && !(_x getVariable ["DYN_hostageRescued", false])) then {
            deleteVehicle _x;
        };
    } forEach _hostages;
    { if (!isNull _x) then { deleteGroup _x } } forEach _civGroups;

    // Enemies
    { if (!isNull _x) then { deleteVehicle _x } } forEach _lEnemies;
    { if (!isNull _x) then { deleteGroup  _x } } forEach _lGroups;

    DYN_ground_enemies     = DYN_ground_enemies     - _lEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _lGroups;

    diag_log "[GROUND-HOSTAGE] Full cleanup complete.";
};
