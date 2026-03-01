/*
    scripts/naval/fn_blackBoxRecovery.sqf
    
    BLACK BOX RECOVERY MISSION
    
    FIXES APPLIED:
    - All getPos on position arrays replaced with DYN_fnc_posOffset
    - No top-right notifications (only hints)
    - Uses "AinvPknlMstpSnonWnonDnon_medic_1" animation (kneeling medic/search)
    - Dynamic bounding box for recorder placement inside wreck
    - DYN_fnc_showProgressBar (same as GPS jammer)
    - Reputation call includes reason string
    - Rebalanced reward: 12-17 pts
    - 5 minute cleanup delay
    - Wreck position validates against underwater rocks/boulders
*/

if (!isServer) exitWith {};

diag_log "[NAVAL] Starting Black Box Recovery Mission";

// =====================================================
// DEFINE ACE INTERACTION FUNCTION FIRST
// =====================================================
DYN_fnc_addBlackBoxInteraction = {
    params ["_recorder", "_wreck"];
    
    if (!hasInterface) exitWith {};
    if (isNull _recorder) exitWith {};
    
    if (isNil "ace_interact_menu_fnc_createAction") exitWith {
        diag_log "[NAVAL] ACE interact menu not available";
    };
    
    private _action = [
        "PickUpBlackBox",
        "Retrieve Flight Recorder",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        {
            // STATEMENT
            params ["_target", "_player", "_params"];
            
            if (_target getVariable ["DYN_isCarrying", false]) exitWith {
                hint "Someone is already carrying this.";
            };
            
            if (_target getVariable ["DYN_bbExtracting", false]) exitWith {
                hint "Someone is already extracting this.";
            };
            
            _target setVariable ["DYN_bbExtracting", true, true];
            
            missionNamespace setVariable ["DYN_bbTarget", _target];
            missionNamespace setVariable ["DYN_bbCaller", _player];
            missionNamespace setVariable ["DYN_bbActive", true];
            
            // Lower weapon
            _player action ["SwitchWeapon", _player, _player, 99];
            
            // Diving search animation loop
            [_player] spawn {
                params ["_unit"];
                sleep 0.3;
                while {missionNamespace getVariable ["DYN_bbActive", false]} do {
                    if (!alive _unit) exitWith {};
                    _unit playMoveNow "AinvPknlMstpSnonWnonDnon_medic_1";
                    sleep 6;
                };
            };
            
            [
                8,
                "RETRIEVING FLIGHT RECORDER",
                // ON SUCCESS
                {
                    missionNamespace setVariable ["DYN_bbActive", false];
                    private _t = missionNamespace getVariable ["DYN_bbTarget", objNull];
                    private _c = missionNamespace getVariable ["DYN_bbCaller", objNull];
                    
                    if (!isNull _c) then {
                        _c playMoveNow "";
                        _c switchMove "";
                    };
                    
                    if (isNull _t) exitWith {};
                    
                    detach _t;
                    _t attachTo [_c, [0, 0.2, 0.15], "Pelvis"];
                    _t setVariable ["DYN_isCarrying", true, true];
                    _t setVariable ["DYN_carrier", _c, true];
                    _t setVariable ["DYN_bbExtracting", false, true];
                    
                    
                    [_t, _c] spawn {
                        params ["_target", "_player"];
                        
                        while {alive _player && !isNull _target && (_target in attachedObjects _player)} do {
                            sleep 0.5;
                        };
                        
                        if (!isNull _target && !(alive _player)) then {
                            detach _target;
                            private _dropPos = getPosWorld _player;
                            private _groundZ = getTerrainHeightASL _dropPos;
                            _target setPosASL [_dropPos select 0, _dropPos select 1, _groundZ + 0.3];
                            _target setVariable ["DYN_isCarrying", false, true];
                            _target setVariable ["DYN_carrier", objNull, true];
                        };
                    };
                },
                // ON CANCEL
                {
                    missionNamespace setVariable ["DYN_bbActive", false];
                    private _t = missionNamespace getVariable ["DYN_bbTarget", objNull];
                    private _c = missionNamespace getVariable ["DYN_bbCaller", objNull];
                    
                    if (!isNull _c) then {
                        _c playMoveNow "";
                        _c switchMove "";
                    };
                    if (!isNull _t) then {
                        _t setVariable ["DYN_bbExtracting", false, true];
                    };
                    hint "Retrieval cancelled.";
                    [] spawn { sleep 2; hintSilent ""; };
                },
                // ONGOING CONDITION
                {
                    private _t = missionNamespace getVariable ["DYN_bbTarget", objNull];
                    private _c = missionNamespace getVariable ["DYN_bbCaller", objNull];
                    
                    !isNull _t
                    && {!isNull _c}
                    && {alive _c}
                    && {(_c distance _t) < 5}
                }
            ] call DYN_fnc_showProgressBar;
        },
        {
            // CONDITION
            params ["_target", "_player", "_params"];
            
            !(_target getVariable ["DYN_isCarrying", false])
            && {!(_target getVariable ["DYN_bbExtracting", false])}
            && {alive _target}
            && {alive _player}
            && {(_player distance _target) < 3}
            && {underwater _player}
        },
        {},
        [],
        [0, 0, 0],
        3,
        [false, false, false, false, false]
    ] call ace_interact_menu_fnc_createAction;
    
    [_recorder, 0, ["ACE_MainActions"], _action] call ace_interact_menu_fnc_addActionToObject;
    
    diag_log format ["[NAVAL] ACE interaction added to recorder %1", _recorder];
};
publicVariable "DYN_fnc_addBlackBoxInteraction";

// =====================================================
// FIND DEEP WATER POSITION
// =====================================================
private _basePos = getMarkerPos "respawn_west";
if (_basePos isEqualTo [0,0,0]) exitWith {
    diag_log "[NAVAL] ERROR: respawn_west marker not found";
    DYN_naval_active = false;
};

private _wreckPos = [];
private _minDepth = 80;
private _minDist = 1500;
private _maxDist = 4000;

diag_log "[NAVAL] Searching for deep water position...";

for "_attempt" from 1 to 200 do {
    private _dir = random 360;
    private _dist = _minDist + random (_maxDist - _minDist);
    private _testPos = [_basePos, _dist, _dir] call DYN_fnc_posOffset;
    
    if (!surfaceIsWater _testPos) then { continue };
    
    private _terrainZ = getTerrainHeightASL _testPos;
    private _depth = abs _terrainZ;
    
    if (_depth < _minDepth) then { continue };
    
    private _allDeep = true;
    {
        private _checkPos = [_testPos, 50, _x] call DYN_fnc_posOffset;
        if (!surfaceIsWater _checkPos) exitWith { _allDeep = false };
        if ((abs (getTerrainHeightASL _checkPos)) < (_minDepth - 20)) exitWith { _allDeep = false };
    } forEach [0, 90, 180, 270];
    
    if (!_allDeep) then { continue };
    
    _wreckPos = _testPos;
    diag_log format ["[NAVAL] Found deep water at %1 (depth: %2m, distance: %3m)", _wreckPos, round _depth, round _dist];
    break;
};

if (_wreckPos isEqualTo []) exitWith {
    diag_log "[NAVAL] ERROR: Could not find suitable deep water position";
    DYN_naval_active = false;
};

// Search area marker
private _searchMarker = format ["blackbox_search_%1", round (diag_tickTime * 1000)];
createMarker [_searchMarker, _wreckPos];
_searchMarker setMarkerShape "ELLIPSE";
_searchMarker setMarkerSize [400, 400];
_searchMarker setMarkerColor "ColorBlue";
_searchMarker setMarkerBrush "FDiagonal";
_searchMarker setMarkerAlpha 0.4;
_searchMarker setMarkerText "Search Area";

DYN_naval_markers pushBack _searchMarker;

// =====================================================
// FIND CLEAR WRECK POSITION (no underwater rocks/boulders)
// =====================================================
private _actualWreckPos = [];

for "_try" from 1 to 50 do {
    private _offsetDist = 50 + random 150;
    private _offsetDir = random 360;
    private _testPos = [_wreckPos, _offsetDist, _offsetDir] call DYN_fnc_posOffset;

    // Must still be deep water
    if (!surfaceIsWater _testPos) then { continue };
    private _depth = abs (getTerrainHeightASL _testPos);
    if (_depth < 40) then { continue };

    // Check for underwater rocks, boulders, and other large terrain objects
    // nearestTerrainObjects catches map-placed rocks; nearestObjects catches placed objects
    private _nearRocks = nearestTerrainObjects [_testPos, ["ROCK", "ROCKS", "HIDE"], 20, false];
    private _nearObjects = nearestObjects [_testPos, ["Land_UnderwaterRock_01_F", "Land_UnderwaterRock_02_F", "Land_UnderwaterRock_03_F", "Land_Stone_8m_F", "Land_Stone_4m_F", "Land_Cliff_comp", "Land_Cliff_wall", "Land_Rock"], 25];

    if (count _nearRocks > 0 || count _nearObjects > 0) then {
        diag_log format ["[NAVAL] Wreck pos rejected (rocks nearby): %1 rocks + %2 objects at %3",
            count _nearRocks, count _nearObjects, _testPos];
        continue;
    };

    // Slope check — flat sea floor is better (less chance of clipping)
    private _heights = [];
    {
        private _chkPos = [_testPos, 10, _x] call DYN_fnc_posOffset;
        _heights pushBack (getTerrainHeightASL _chkPos);
    } forEach [0, 60, 120, 180, 240, 300];
    private _slopeRange = (selectMax _heights) - (selectMin _heights);
    if (_slopeRange > 5) then {
        diag_log format ["[NAVAL] Wreck pos rejected (slope %1m) at %2", round _slopeRange, _testPos];
        continue;
    };

    _actualWreckPos = _testPos;
    diag_log format ["[NAVAL] Clear wreck position found on attempt %1: %2 (depth: %3m, slope: %4m)",
        _try, _testPos, round _depth, round _slopeRange];
    break;
};

// Fallback: if no perfectly clear spot found, use center with warning
if (_actualWreckPos isEqualTo []) then {
    _actualWreckPos = _wreckPos;
    diag_log "[NAVAL] WARNING: Could not find rock-free position, using search center as fallback";
};

// =====================================================
// SEA FLOOR HEIGHT
// =====================================================
private _seaFloorZ = getTerrainHeightASL _actualWreckPos;

diag_log format ["[NAVAL] Sea floor Z: %1 (depth: %2m) at %3", _seaFloorZ, abs _seaFloorZ, _actualWreckPos];

// =====================================================
// SPAWN WRECK ON SEA FLOOR
// =====================================================
private _wreck = createVehicle ["CUP_MH47E_wreck2", [0,0,0], [], 0, "CAN_COLLIDE"];

private _wreckDir = random 360;

_wreck setPosASL [_actualWreckPos select 0, _actualWreckPos select 1, _seaFloorZ];
_wreck setDir _wreckDir;

// Disable simulation so physics doesn't float it
_wreck enableSimulationGlobal false;

DYN_naval_objects pushBack _wreck;

// Log bounding box for recorder placement
private _bb = boundingBoxReal _wreck;
private _bbMin = _bb select 0;
private _bbMax = _bb select 1;
diag_log format ["[NAVAL] Wreck BB - Min: %1, Max: %2, Height: %3m", 
    _bbMin, _bbMax, (_bbMax select 2) - (_bbMin select 2)];
diag_log format ["[NAVAL] Wreck placed at ASL: %1", getPosASL _wreck];

// =====================================================
// SPAWN FLIGHT RECORDER INSIDE WRECK
// =====================================================
sleep 1;

private _recorder = createVehicle ["rhs_flightrecorder_assembled", [0,0,0], [], 0, "CAN_COLLIDE"];

private _floorZ = (_bbMin select 2) + 1.5;
private _attachOffset = [0, 1.0, _floorZ];

diag_log format ["[NAVAL] Recorder attach offset: %1 (floor Z from BB: %2)", _attachOffset, _bbMin select 2];

_recorder attachTo [_wreck, _attachOffset];

_recorder setVariable ["DYN_blackBoxMission", true, true];
_recorder setVariable ["DYN_wreck", _wreck, true];
_recorder setVariable ["DYN_isCarrying", false, true];
_recorder setVariable ["DYN_bbExtracting", false, true];
_recorder setVariable ["DYN_carrier", objNull, true];

DYN_naval_objects pushBack _recorder;

diag_log format ["[NAVAL] Recorder at ASL: %1 (wreck: %2)", getPosASL _recorder, getPosASL _wreck];

// =====================================================
// ADD ACE INTERACTION ON ALL CLIENTS
// =====================================================
sleep 0.5;
[_recorder, _wreck] remoteExec ["DYN_fnc_addBlackBoxInteraction", 0, _recorder];

// =====================================================
// TASK
// =====================================================
private _taskId = format ["naval_blackbox_%1", round (diag_tickTime * 1000)];

[
    west,
    _taskId,
    [
        "Following the loss of a friendly aircraft over coastal waters, satellite scans have confirmed the wreck lies submerged offshore.<br/>The flight recorder contains sensitive operational data. Enemy combat divers have been detected in the area.<br/><br/>Locate the wreck, retrieve the black box, and prevent hostile acquisition at all costs.",
        "Recover Flight Recorder",
        ""
    ],
    _wreckPos,
    "ASSIGNED",
    2,
    true,
    "download"
] remoteExec ["BIS_fnc_taskCreate", 0, true];

DYN_naval_tasks pushBack _taskId;

// =====================================================
// ENEMY COMBAT DIVERS
// =====================================================
private _diverCount = 8 + floor (random 3);
private _diverPool = [
    "O_diver_TL_F",
    "O_diver_F",
    "O_diver_exp_F"
];

private _groupCount = 2 + floor (random 2);
private _diversPerGroup = ceil (_diverCount / _groupCount);

diag_log format ["[NAVAL] Spawning %1 divers in %2 groups", _diverCount, _groupCount];

private _spawnedDivers = 0;

for "_g" from 1 to _groupCount do {
    if (_spawnedDivers >= _diverCount) exitWith {};
    
    private _diverGrp = createGroup east;
    DYN_naval_enemyGroups pushBack _diverGrp;
    _diverGrp setBehaviourStrong "AWARE";
    _diverGrp setCombatMode "RED";
    
    private _grpAngle = (_g - 1) * (360 / _groupCount);
    private _groupSpawnBase = [_actualWreckPos, 30 + random 20, _grpAngle] call DYN_fnc_posOffset;
    
    for "_d" from 1 to _diversPerGroup do {
        if (_spawnedDivers >= _diverCount) exitWith {};
        
        private _diverSpawnPos = [_groupSpawnBase, 5 + random 10, random 360] call DYN_fnc_posOffset;
        private _diverFloorZ = getTerrainHeightASL _diverSpawnPos;
        private _diverZ = _diverFloorZ + 2.0 + random 3.0;
        
        private _diver = _diverGrp createUnit [selectRandom _diverPool, [0,0,0], [], 0, "NONE"];
        _diver setPosASL [_diverSpawnPos select 0, _diverSpawnPos select 1, _diverZ];
        
        _diver setSkill ["aimingAccuracy", 0.40];
        _diver setSkill ["aimingSpeed", 0.40];
        _diver allowFleeing 0;
        
        DYN_naval_enemies pushBack _diver;
        _spawnedDivers = _spawnedDivers + 1;
    };
    
    for "_w" from 1 to 4 do {
        private _wpDist = 25 + random 35;
        private _wpDir = _grpAngle + (_w * 90);
        private _wpPos = [_actualWreckPos, _wpDist, _wpDir] call DYN_fnc_posOffset;
        
        private _wp = _diverGrp addWaypoint [_wpPos, 10];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCompletionRadius 15;
    };
    
    (_diverGrp addWaypoint [_actualWreckPos, 0]) setWaypointType "CYCLE";
};

diag_log format ["[NAVAL] %1 divers spawned", _spawnedDivers];

// =====================================================
// DELIVERY ZONE MONITOR
// =====================================================
private _deliveryPos = getMarkerPos "blackbox_delivery";

if (_deliveryPos isEqualTo [0,0,0]) then {
    diag_log "[NAVAL] WARNING: 'blackbox_delivery' marker not found, using respawn_west";
    _deliveryPos = _basePos;
};

// Snapshot mission data for cleanup
private _localEnemies = +DYN_naval_enemies;
private _localGroups  = +DYN_naval_enemyGroups;
private _localMarkers = +DYN_naval_markers;
private _localObjects = +DYN_naval_objects;
private _bbTimeout    = 7200; // 2 hours

[_recorder, _taskId, _deliveryPos, _searchMarker, _wreck, _bbTimeout,
 _localEnemies, _localGroups, _localMarkers, _localObjects] spawn {
    params [
        "_recorder", "_taskId", "_deliveryPos", "_searchMarker", "_wreck", "_bbTimeout",
        "_localEnemies", "_localGroups", "_localMarkers", "_localObjects"
    ];

    private _startTime = diag_tickTime;

    waitUntil {
        sleep 2;

        if (isNull _recorder) exitWith { true };
        if ((diag_tickTime - _startTime) > _bbTimeout) exitWith { true };

        private _attachedTo = attachedTo _recorder;
        if (isNull _attachedTo) exitWith { false };
        if (_attachedTo isEqualTo _wreck) exitWith { false };
        if (!(_attachedTo isKindOf "Man")) exitWith { false };

        (_attachedTo distance2D _deliveryPos) < 20
    };

    // Timed out
    if (!isNull _recorder && (diag_tickTime - _startTime) > _bbTimeout) exitWith {
        diag_log "[NAVAL] Black box mission timed out";
        [_taskId, "FAILED", true] remoteExec ["BIS_fnc_taskSetState", 0, true];
        ["NavalFailed", ["Black box mission expired."]] remoteExecCall ["BIS_fnc_showNotification", 0];

        { deleteMarker _x } forEach _localMarkers;
        DYN_naval_markers = DYN_naval_markers - _localMarkers;

        sleep 20;
        [_taskId] call BIS_fnc_deleteTask;
        DYN_naval_active = false;

        sleep 300;
        { if (!isNull _x) then { deleteVehicle _x } } forEach (_localEnemies + _localObjects);
        { if (!isNull _x) then { deleteGroup _x } } forEach _localGroups;
        diag_log "[NAVAL] Black box timeout cleanup complete";
    };
    
    // Recorder destroyed
    if (isNull _recorder) exitWith {
        diag_log "[NAVAL] Black box mission failed - recorder destroyed";
        [_taskId, "FAILED", true] remoteExec ["BIS_fnc_taskSetState", 0, true];
        hint "Mission Failed: The flight recorder was lost.";
        
        { deleteMarker _x } forEach _localMarkers;
        DYN_naval_markers = DYN_naval_markers - _localMarkers;
        
        sleep 20;
        [_taskId] call BIS_fnc_deleteTask;
        DYN_naval_active = false;
        
        sleep 300;
        
        { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
        { if (!isNull _x) then { deleteGroup _x } }   forEach _localGroups;
        {
            if (!isNull _x) then {
                if (!isNull (attachedTo _x)) then { detach _x };
                deleteVehicle _x;
            };
        } forEach _localObjects;
        
        DYN_naval_enemies     = DYN_naval_enemies     - _localEnemies;
        DYN_naval_enemyGroups = DYN_naval_enemyGroups  - _localGroups;
        DYN_naval_objects     = DYN_naval_objects      - _localObjects;
        
        diag_log "[NAVAL] Black box cleanup complete";
    };
    
    private _carrier = attachedTo _recorder;
    if (isNull _carrier || !(_carrier isKindOf "Man")) exitWith {
        diag_log "[NAVAL] Black box - unexpected state at delivery";
        
        { deleteMarker _x } forEach _localMarkers;
        DYN_naval_markers = DYN_naval_markers - _localMarkers;
        
        sleep 20;
        [_taskId] call BIS_fnc_deleteTask;
        DYN_naval_active = false;
        
        sleep 300;
        
        { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
        { if (!isNull _x) then { deleteGroup _x } }   forEach _localGroups;
        {
            if (!isNull _x) then {
                if (!isNull (attachedTo _x)) then { detach _x };
                deleteVehicle _x;
            };
        } forEach _localObjects;
        
        DYN_naval_enemies     = DYN_naval_enemies     - _localEnemies;
        DYN_naval_enemyGroups = DYN_naval_enemyGroups  - _localGroups;
        DYN_naval_objects     = DYN_naval_objects      - _localObjects;
        
        diag_log "[NAVAL] Black box cleanup complete";
    };
    
    // SUCCESS
    detach _recorder;
    deleteVehicle _recorder;
    
    if (!isNull _wreck) then { _wreck enableSimulationGlobal true; };
    
    [_taskId, "SUCCEEDED", true] remoteExec ["BIS_fnc_taskSetState", 0, true];
    
    [12 + floor random 6, "Flight Recorder Recovery"] call DYN_fnc_changeReputation;
    
    { deleteMarker _x } forEach _localMarkers;
    DYN_naval_markers = DYN_naval_markers - _localMarkers;
    
    diag_log "[NAVAL] Black box mission completed successfully";
    
    sleep 20;
    [_taskId] call BIS_fnc_deleteTask;
    DYN_naval_active = false;
    
    sleep 300;
    
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
    { if (!isNull _x) then { deleteGroup _x } }   forEach _localGroups;
    {
        if (!isNull _x) then {
            if (!isNull (attachedTo _x)) then { detach _x };
            deleteVehicle _x;
        };
    } forEach _localObjects;
    
    DYN_naval_enemies     = DYN_naval_enemies     - _localEnemies;
    DYN_naval_enemyGroups = DYN_naval_enemyGroups  - _localGroups;
    DYN_naval_objects     = DYN_naval_objects      - _localObjects;
    
    diag_log "[NAVAL] Black box full cleanup complete";
};

diag_log "[NAVAL] Black Box Recovery Mission initialized successfully";
