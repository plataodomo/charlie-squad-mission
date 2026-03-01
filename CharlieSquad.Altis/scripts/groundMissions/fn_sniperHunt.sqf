/*
    scripts\groundMissions\fn_sniperHunt.sqf
    GROUND MISSION: Sniper Hunt (Enhanced)

    FIXES APPLIED:
    - All getPos on position arrays replaced with DYN_fnc_posOffset
    - Surgical cleanup of global arrays
    - Consistent cleanup pattern
*/
if (!isServer) exitWith {};

diag_log "[GROUND-SNIPER] Setting up Sniper Hunt mission...";

// =====================================================
// 1. FIND FORESTED POSITION
// =====================================================
private _forestPos = [2000, 1500, 20, 50] call DYN_fnc_findForestPos;

if (_forestPos isEqualTo []) exitWith {
    diag_log "[GROUND-SNIPER] Could not find forest position. Aborting.";
    DYN_ground_active = false;
};

diag_log format ["[GROUND-SNIPER] Forest position found: %1", _forestPos];

// =====================================================
// 2. SETTINGS
// =====================================================
private _timeout      = 7200; // 2 hours
private _repReward    = 15 + floor random 6;
private _cleanupDelay = 120;
private _searchRadius = 300;

// =====================================================
// 3. PRIMARY SNIPER POSITION (IMPROVED)
// =====================================================
private _sniperPos = +_forestPos;
private _validPos = false;

for "_try" from 1 to 30 do {
    private _testPos = [_forestPos, 50 + random (_searchRadius - 100), random 360] call DYN_fnc_posOffset;

    if (!surfaceIsWater _testPos) then {
        private _nearTrees = count (nearestTerrainObjects [_testPos, ["TREE", "SMALL TREE"], 20, false]);
        if (_nearTrees >= 3) then {
            private _elev = getTerrainHeightASL _testPos;
            private _avgElev = 0;
            {
                private _chkPos = [_testPos, 80, _x] call DYN_fnc_posOffset;
                _avgElev = _avgElev + getTerrainHeightASL _chkPos;
            } forEach [0, 45, 90, 135, 180, 225, 270, 315];
            _avgElev = _avgElev / 8;

            if (_elev >= (_avgElev - 3)) then {
                _sniperPos = _testPos;
                _validPos = true;
            };
        };
    };

    if (_validPos) exitWith {};
};

// Fallback — less strict
if (!_validPos) then {
    for "_try" from 1 to 20 do {
        private _testPos = [_forestPos, 50 + random 150, random 360] call DYN_fnc_posOffset;
        if (!surfaceIsWater _testPos) then {
            _sniperPos = _testPos;
            _validPos = true;
        };
        if (_validPos) exitWith {};
    };
};

if (!_validPos) then {
    _sniperPos = +_forestPos;
    diag_log "[GROUND-SNIPER] WARNING: Using center position";
};

diag_log format ["[GROUND-SNIPER] Primary position: %1", _sniperPos];

// =====================================================
// 4. BACKUP POSITIONS
// =====================================================
private _backupPositions = [];

for "_i" from 0 to 2 do {
    private _found = false;
    for "_try" from 1 to 15 do {
        private _bPos = [_sniperPos, 50 + random 80, random 360] call DYN_fnc_posOffset;

        if (!surfaceIsWater _bPos) then {
            private _trees = count (nearestTerrainObjects [_bPos, ["TREE", "SMALL TREE"], 15, false]);
            if (_trees >= 2) then {
                private _tooClose = false;
                {
                    if (_bPos distance2D _x < 30) then { _tooClose = true };
                } forEach _backupPositions;

                if (!_tooClose) then {
                    _backupPositions pushBack _bPos;
                    _found = true;
                };
            };
        };

        if (_found) exitWith {};
    };
};

diag_log format ["[GROUND-SNIPER] Backup positions found: %1", count _backupPositions];

// =====================================================
// 5. OVERWATCH DIRECTION
// =====================================================
private _bestDir = 0;
private _bestOpenness = 0;

for "_d" from 0 to 350 step 30 do {
    private _openness = 0;
    for "_r" from 10 to 100 step 10 do {
        private _chk = [_sniperPos, _r, _d] call DYN_fnc_posOffset;
        if (count (nearestTerrainObjects [_chk, ["TREE", "SMALL TREE"], 10, false]) == 0) then {
            _openness = _openness + 1;
        };
    };
    if (_openness > _bestOpenness) then {
        _bestOpenness = _openness;
        _bestDir = _d;
    };
};

diag_log format ["[GROUND-SNIPER] Overwatch dir: %1 (score: %2)", _bestDir, _bestOpenness];

// =====================================================
// 6. KILL SCENE
// =====================================================
private _missionObjects = [];

private _nearRoads = _forestPos nearRoads 400;
private _scenePos = if (count _nearRoads > 0) then {
    getPos (selectRandom _nearRoads)
} else {
    [_forestPos, _searchRadius * 0.8, (_bestDir + 180) mod 360] call DYN_fnc_posOffset
};

private _wreckClass = selectRandom [
    "Land_Wreck_Offroad_F",
    "Land_Wreck_Offroad2_F",
    "Land_Wreck_HMMWV_F"
];
private _wreck = createVehicle [_wreckClass, _scenePos, [], 3, "NONE"];
if (!isNull _wreck) then {
    _wreck setDamage 1;
    _missionObjects pushBack _wreck;
};

private _deadGrp = createGroup west;

for "_i" from 1 to 3 do {
    private _bPos = [_scenePos, 2 + random 8, random 360] call DYN_fnc_posOffset;
    if (!surfaceIsWater _bPos) then {
        private _corpse = _deadGrp createUnit [
            selectRandom ["B_Soldier_F", "B_Soldier_lite_F", "B_medic_F"],
            _bPos, [], 0, "NONE"
        ];
        if (!isNull _corpse) then {
            _corpse setPosATL _bPos;
            _corpse setDir random 360;
            removeAllWeapons _corpse;
            _corpse setDamage 1;
            _missionObjects pushBack _corpse;
        };
    };
};

private _extraGroups = [_deadGrp];

diag_log format ["[GROUND-SNIPER] Kill scene placed at %1 (unmarked)", _scenePos];

// =====================================================
// 7. DECOY POSITION
// =====================================================
private _decoyPlaced = false;
private _decoyPos = [0, 0, 0];

for "_try" from 1 to 10 do {
    _decoyPos = [_forestPos, 100 + random 100, (_bestDir + 120 + random 120) mod 360] call DYN_fnc_posOffset;
    if (!surfaceIsWater _decoyPos) then {
        private _dt = count (nearestTerrainObjects [_decoyPos, ["TREE", "SMALL TREE"], 15, false]);
        if (_dt >= 2 && { _decoyPos distance2D _sniperPos > 60 }) then {
            _decoyPlaced = true;
        };
    };
    if (_decoyPlaced) exitWith {};
};

if (_decoyPlaced) then {
    private _bag1 = createVehicle ["Land_BagFence_Short_F", _decoyPos, [], 0, "NONE"];
    if (!isNull _bag1) then {
        _bag1 setDir _bestDir;
        _missionObjects pushBack _bag1;
    };

    private _bag2Pos = [_decoyPos, 1.5, _bestDir + 90] call DYN_fnc_posOffset;
    private _bag2 = createVehicle ["Land_BagFence_Short_F", _bag2Pos, [], 0, "NONE"];
    if (!isNull _bag2) then {
        _bag2 setDir (_bestDir + 90);
        _missionObjects pushBack _bag2;
    };

    private _casings = createVehicle ["GroundWeaponHolder", _decoyPos, [], 0, "NONE"];
    if (!isNull _casings) then {
        _casings addMagazineCargoGlobal ["5Rnd_127x108_Mag", 3];
        _missionObjects pushBack _casings;
    };

    diag_log format ["[GROUND-SNIPER] Decoy hide at %1", _decoyPos];
};

// =====================================================
// 8. SPAWN SNIPER TEAM
// =====================================================
private _sniperGrp = createGroup east;
DYN_ground_enemyGroups pushBack _sniperGrp;

private _skillList = [
    "aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance",
    "spotTime", "courage", "commanding", "general", "reloadSpeed"
];

private _sniper = _sniperGrp createUnit ["CUP_O_TK_Sniper", _sniperPos, [], 0, "NONE"];

if (isNull _sniper) exitWith {
    diag_log "[GROUND-SNIPER] ERROR: Failed to create sniper. Aborting.";
    { deleteVehicle _x } forEach _missionObjects;
    { deleteGroup _x } forEach _extraGroups;
    deleteGroup _sniperGrp;
    DYN_ground_active = false;
};

_sniper setPosATL _sniperPos;
_sniper setDir _bestDir;
_sniper setUnitPos "DOWN";
_sniper allowFleeing 0;
_sniper setSkill 0.55;
{ _sniper setSkill [_x, 0.55] } forEach _skillList;

private _nearTreeObjs = nearestTerrainObjects [_sniperPos, ["TREE"], 8, false];
if (count _nearTreeObjs > 0) then {
    private _treePos = getPos (_nearTreeObjs select 0);
    private _hidePos = [_treePos, 1.5, _bestDir] call DYN_fnc_posOffset;
    if (!surfaceIsWater _hidePos) then {
        _sniper setPosATL _hidePos;
        _sniperPos = _hidePos;
    };
};

DYN_ground_enemies pushBack _sniper;

private _spotterDir = _bestDir + (selectRandom [-30, -20, 20, 30]);
private _spotterPos = [_sniperPos, 2 + random 3, _spotterDir] call DYN_fnc_posOffset;
if (surfaceIsWater _spotterPos) then {
    _spotterPos = [_sniperPos, 2, _bestDir] call DYN_fnc_posOffset;
};

private _spotter = _sniperGrp createUnit ["CUP_O_TK_Spotter", _spotterPos, [], 0, "NONE"];

if (isNull _spotter) exitWith {
    diag_log "[GROUND-SNIPER] ERROR: Failed to create spotter. Aborting.";
    deleteVehicle _sniper;
    { deleteVehicle _x } forEach _missionObjects;
    { deleteGroup _x } forEach _extraGroups;
    deleteGroup _sniperGrp;
    DYN_ground_active = false;
};

_spotter setPosATL _spotterPos;
_spotter setDir _bestDir;
_spotter setUnitPos "DOWN";
_spotter allowFleeing 0;
_spotter setSkill 0.55;
{ _spotter setSkill [_x, 0.55] } forEach _skillList;

DYN_ground_enemies pushBack _spotter;

// Force prone after engine settles
[_sniper, _spotter, _bestDir] spawn {
    params ["_s", "_sp", "_dir"];
    sleep 3;
    {
        if (alive _x) then {
            _x setUnitPos "DOWN";
            private _watchPos = [getPos _x, 500, _dir] call DYN_fnc_posOffset;
            _x doWatch _watchPos;
        };
    } forEach [_s, _sp];
};

diag_log format ["[GROUND-SNIPER] Team spawned. Sniper: %1  Spotter: %2", _sniperPos, _spotterPos];

// =====================================================
// 9. GROUP BEHAVIOUR
// =====================================================
_sniperGrp setBehaviourStrong "STEALTH";
_sniperGrp setCombatMode "RED";
_sniperGrp setSpeedMode "LIMITED";

{
    _x disableAI "PATH";
    _x disableAI "AUTOCOMBAT";
} forEach units _sniperGrp;

// =====================================================
// 10. ENGAGEMENT & RELOCATION SYSTEM
// =====================================================
[_sniperGrp, _sniper, _spotter, _sniperPos, _backupPositions, _searchRadius, _forestPos] spawn {
    params ["_grp", "_sniper", "_spotter", "_origPos", "_backups", "_sRadius", "_center"];

    private _firstContact = false;

    while { !_firstContact && { alive _sniper || alive _spotter } } do {
        sleep 3;

        if ((behaviour leader _grp) == "COMBAT") exitWith {
            _firstContact = true;
        };

        private _nearPlayers = allPlayers select {
            alive _x && _x distance2D _center < _sRadius
        };

        if (count _nearPlayers > 0) then {
            private _closest = objNull;
            private _closestDist = 99999;
            {
                private _d = _x distance2D (getPos _sniper);
                if (_d < _closestDist) then {
                    _closest = _x;
                    _closestDist = _d;
                };
            } forEach _nearPlayers;

            if (!isNull _closest && _closestDist < 500) then {
                private _knowledge = linearConversion [500, 100, _closestDist, 1.0, 4.0, true];
                _grp reveal [_closest, _knowledge];

                {
                    if (alive _x) then { _x enableAI "AUTOCOMBAT" };
                } forEach units _grp;

                _firstContact = true;
            };
        };
    };

    if (({ alive _x } count units _grp) == 0) exitWith {};

    diag_log "[GROUND-SNIPER] First contact — engaging from primary position.";

    sleep (20 + random 20);

    private _posIndex = 0;

    while { ({ alive _x } count units _grp) > 0 && _posIndex < count _backups } do {
        private _nextPos = _backups select _posIndex;
        _posIndex = _posIndex + 1;

        diag_log format ["[GROUND-SNIPER] Displacing to backup position %1", _posIndex];

        {
            if (alive _x) then {
                _x enableAI "PATH";
                _x setSpeedMode "FULL";
                _x doMove _nextPos;
            };
        } forEach units _grp;

        private _moveStart = diag_tickTime;
        waitUntil {
            sleep 3;
            private _arrived = (alive leader _grp) && { (leader _grp) distance2D _nextPos < 15 };
            private _dead = ({ alive _x } count units _grp) == 0;
            private _moveTimeout = (diag_tickTime - _moveStart) > 60;
            _arrived || _dead || _moveTimeout
        };

        if (({ alive _x } count units _grp) == 0) exitWith {};

        {
            if (alive _x) then {
                _x setUnitPos "DOWN";
                _x setSpeedMode "LIMITED";
                _x disableAI "PATH";
            };
        } forEach units _grp;

        diag_log format ["[GROUND-SNIPER] Holding at backup position %1", _posIndex];

        sleep (15 + random 20);
    };

    if (({ alive _x } count units _grp) > 0) then {
        {
            if (alive _x) then {
                _x enableAI "PATH";
                _x enableAI "AUTOCOMBAT";
            };
        } forEach units _grp;
        diag_log "[GROUND-SNIPER] No more fallback positions — last stand.";
    };
};

// =====================================================
// 11. MARKER & TASK
// =====================================================
private _taskId = format ["ground_sniper_%1", round (diag_tickTime * 1000)];

private _mkr = format ["ground_mkr_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _forestPos];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [_searchRadius, _searchRadius];
_mkr setMarkerColor "ColorRed";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
_mkr setMarkerText "Sniper Activity";
DYN_ground_markers pushBack _mkr;

[
    west,
    _taskId,
    [
        "An elite enemy sniper team has been confirmed operating within a heavily forested sector. Reports suggest a patrol convoy was recently ambushed somewhere in the vicinity — look for signs of the attack, it may help narrow down their position.<br/><br/>Intelligence indicates a two-man element: a highly trained sniper and an experienced spotter. Both are well-equipped, disciplined, and expertly camouflaged.<br/><br/>Be advised — this team is known to displace after engaging. Previous reconnaissance identified what appeared to be a firing position, but it may be a decoy.<br/><br/>Your task is to locate and eliminate the sniper team. Proceed with extreme caution — they will likely acquire you before you see them.",
        "Sniper Hunt",
        ""
    ],
    _forestPos,
    "CREATED",
    3,
    true,
    "kill"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_ground_tasks pushBack _taskId;

diag_log format ["[GROUND-SNIPER] Mission active. Primary: %1, Search center: %2", _sniperPos, _forestPos];

// =====================================================
// 12. COMPLETION MONITOR
// =====================================================
private _localEnemies  = +DYN_ground_enemies;
private _localGroups   = +DYN_ground_enemyGroups;
private _localMarkers  = +DYN_ground_markers;

[
    _taskId, _timeout, _repReward,
    _cleanupDelay, _sniper, _spotter,
    _missionObjects, _extraGroups,
    _localEnemies, _localGroups, _localMarkers
] spawn {
    params [
        "_tid", "_tOut", "_rep",
        "_despawnDelay", "_sniper", "_spotter",
        "_extraObjects", "_extraGrps",
        "_localEnemies", "_localGroups", "_localMarkers"
    ];

    private _startTime = diag_tickTime;

    waitUntil {
        sleep 5;
        (!alive _sniper && !alive _spotter)
        || { (diag_tickTime - _startTime) > _tOut }
    };

    private _bothDead = !alive _sniper && !alive _spotter;

    if (_bothDead) then {
        [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, true];
        [_rep, "Sniper Team Eliminated"] call DYN_fnc_changeReputation;
        diag_log format ["[GROUND-SNIPER] SUCCESS. +%1 rep.", _rep];
    } else {
        [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["TaskFailed", ["Sniper hunt mission expired. The enemy team escaped."]]
            remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-SNIPER] TIMED OUT.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_ground_markers = DYN_ground_markers - _localMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_ground_active = false;

    diag_log format ["[GROUND-SNIPER] Cleanup in %1 seconds", _despawnDelay];
    sleep _despawnDelay;

    { if (!isNull _x) then { deleteVehicle _x } } forEach [_sniper, _spotter];
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _extraObjects;
    { if (!isNull _x) then { deleteGroup _x } } forEach (_localGroups + _extraGrps);

    DYN_ground_enemies     = DYN_ground_enemies     - _localEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups  - _localGroups;

    diag_log "[GROUND-SNIPER] Full cleanup complete";
};

diag_log "[GROUND-SNIPER] Sniper Hunt mission initialized successfully";
