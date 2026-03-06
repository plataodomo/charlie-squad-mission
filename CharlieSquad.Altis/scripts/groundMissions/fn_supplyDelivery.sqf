/*
    scripts\groundMissions\fn_supplyDelivery.sqf
    GROUND MISSION: Supply Delivery

    Friendly forces and civilian aid in a nearby city are running low on
    essential supplies. A logistics package has been staged at the base
    Delivery area and must be escorted there safely.

    PLAYER TASK:
      1. Pick up a transport vehicle from the shop.
      2. Load the three supply crates (near the "Delivery" marker at base)
         into the vehicle using ACE cargo.
      3. Drive to the marked drop-off zone in the target city.
         Enemy intercept elements patrol the route — protect the cargo.
      4. Unload the crates inside the green drop-off zone to complete the mission.

    SUCCESS:
      All three supply items are physically present inside the drop-off zone
      (unloaded from ACE cargo).

    FAIL:
      2-hour mission timer expires.

    REWARDS:
      Supplies delivered: +22-32 REP

    NOTES:
      - Supply items are set indestructible so enemies cannot simply shoot them.
      - ACE cargo variables are set on each item so any vehicle from the shop
        can carry all three crates (1 cargo space each, 3 total).
      - Intercept groups stay passive until players drive within 150 m.
*/
if (!isServer) exitWith {};

diag_log "[GROUND-SUPPLY] Setting up Supply Delivery mission...";

if (isNil "DYN_ground_enemies")     then { DYN_ground_enemies = [] };
if (isNil "DYN_ground_enemyVehs")   then { DYN_ground_enemyVehs = [] };
if (isNil "DYN_ground_enemyGroups") then { DYN_ground_enemyGroups = [] };
if (isNil "DYN_ground_objects")     then { DYN_ground_objects = [] };
if (isNil "DYN_ground_tasks")       then { DYN_ground_tasks = [] };
if (isNil "DYN_ground_markers")     then { DYN_ground_markers = [] };

private _basePos        = getMarkerPos "respawn_west";
private _deliveryMkrPos = getMarkerPos "Delivery";
private _aoCenter       = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

// Fallback if Delivery marker is missing
if (_deliveryMkrPos isEqualTo [0,0,0]) then {
    _deliveryMkrPos = _basePos;
    diag_log "[GROUND-SUPPLY] WARNING: 'Delivery' marker not found — falling back to respawn_west.";
};

// =====================================================
// 1. SETTINGS
// =====================================================
private _timeout      = 7200;
private _repReward    = 22 + floor (random 11);  // 22-32 rep
private _dropRadius   = 80;
private _cleanupDelay = 120;

private _enemyPool = [
    "CUP_O_RU_Soldier_Ratnik_Autumn",
    "CUP_O_RU_Soldier_AR_Ratnik_Autumn",
    "CUP_O_RU_Soldier_GL_Ratnik_Autumn",
    "CUP_O_RU_Soldier_LAT_Ratnik_Autumn",
    "CUP_O_RU_Soldier_Marksman_Ratnik_Autumn"
];

// The three supply items players must load and deliver
private _supplyClasses = [
    "Land_WaterBottle_01_stack_F",
    "Land_FoodSacks_01_small_brown_idap_F",
    "Land_FoodSacks_01_large_brown_idap_F"
];

diag_log format ["[GROUND-SUPPLY] Reward: %1 REP", _repReward];

// =====================================================
// 2. FIND DESTINATION CITY
// =====================================================
private _destPos  = [];
private _destName = "the target city";
private _mapSz    = worldSize;

private _allLocs      = nearestLocations [[_mapSz / 2, _mapSz / 2, 0],
    ["NameCity", "NameCityCapital", "NameVillage"], _mapSz];
private _shuffledLocs = _allLocs call BIS_fnc_arrayShuffle;

{
    private _lPos = locationPosition _x;
    if (surfaceIsWater _lPos) then { continue };
    if (_lPos distance2D _basePos < 2500) then { continue };
    if !(_aoCenter isEqualTo [0,0,0]) then {
        if (_lPos distance2D _aoCenter < 1500) then { continue };
    };
    if (count (_lPos nearRoads 150) == 0) then { continue };
    if (count (nearestObjects [_lPos, ["House","Building"], 150]) < 4) then { continue };

    _destPos  = _lPos;
    _destName = text _x;
    break;
} forEach _shuffledLocs;

// Fallback: road-based search
if (_destPos isEqualTo []) then {
    diag_log "[GROUND-SUPPLY] No named location found — falling back to road search.";
    for "_i" from 1 to 400 do {
        private _rx = 300 + random (_mapSz - 600);
        private _ry = 300 + random (_mapSz - 600);
        private _p  = [_rx, _ry, 0];
        if (surfaceIsWater _p) then { continue };
        if (_p distance2D _basePos < 2500) then { continue };
        if !(_aoCenter isEqualTo [0,0,0]) then {
            if (_p distance2D _aoCenter < 1500) then { continue };
        };
        if (count (_p nearRoads 80) == 0) then { continue };
        if (count (nearestObjects [_p, ["House","Building"], 120]) < 4) then { continue };
        _destPos  = _p;
        _destName = "the drop-off point";
        break;
    };
};

if (_destPos isEqualTo []) exitWith {
    diag_log "[GROUND-SUPPLY] Could not find a suitable destination. Aborting.";
    DYN_ground_active = false;
};

diag_log format ["[GROUND-SUPPLY] Destination: '%1' at %2 (%3 m from base)",
    _destName, _destPos, round (_destPos distance2D _basePos)];

// =====================================================
// 3. SPAWN SUPPLY ITEMS at Delivery marker
// =====================================================
private _supplyItems = [];
{
    // Spread items in a triangle around the Delivery marker
    private _angle  = _forEachIndex * 120;
    private _offset = [_deliveryMkrPos, 1.5 + random 1.0, _angle] call DYN_fnc_posOffset;
    private _item   = createVehicle [_x, _offset, [], 0, "CAN_COLLIDE"];
    _item setDir (random 360);

    // Items cannot be destroyed by enemy fire
    _item allowDamage false;

    // Mark as loadable for ACE cargo (1 space each — total 3, fits any transport)
    _item setVariable ["ace_cargo_canLoad", true, true];
    _item setVariable ["ace_cargo_size",    1,    true];

    DYN_ground_objects pushBack _item;
    _supplyItems pushBack _item;

    diag_log format ["[GROUND-SUPPLY] Item spawned: %1 at %2", _x, _offset];
} forEach _supplyClasses;

// =====================================================
// 4. SPAWN ENEMY INTERCEPT GROUPS along the route
// =====================================================
// Sample positions at even intervals along the straight-line path from
// base to destination, then snap each one to the nearest road.
private _interceptCount = 2 + floor (random 2);  // 2 or 3 groups

private _routeSamples = [];
for "_i" from 1 to 4 do {
    private _t    = _i / 5.0;
    private _sPos = [
        (_basePos#0) + _t * ((_destPos#0) - (_basePos#0)),
        (_basePos#1) + _t * ((_destPos#1) - (_basePos#1)),
        0
    ];
    private _nearRds = _sPos nearRoads 350;
    private _usePos  = if (count _nearRds > 0) then {
        getPos (selectRandom _nearRds)
    } else {
        _sPos
    };
    if (!surfaceIsWater _usePos) then { _routeSamples pushBack _usePos; };
};
_routeSamples = _routeSamples call BIS_fnc_arrayShuffle;

private _interceptData = [];  // [[group, triggerPos], ...]
for "_i" from 0 to (_interceptCount - 1) do {
    if (_i >= count _routeSamples) then { break; };
    private _iPos = _routeSamples select _i;

    private _grp = createGroup east;
    DYN_ground_enemyGroups pushBack _grp;
    _grp setBehaviour  "SAFE";
    _grp setCombatMode "RED";

    private _unitCount = 4 + floor (random 3);  // 4-6 per group
    for "_u" from 1 to _unitCount do {
        private _uPos = [_iPos, 5 + random 20, random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _uPos) then { _uPos = _iPos; };
        private _unit = _grp createUnit [selectRandom _enemyPool, _uPos, [], 0, "NONE"];
        if (!isNull _unit) then {
            _unit disableAI "MOVE";
            _unit disableAI "PATH";
            _unit disableAI "AUTOCOMBAT";
            _unit allowFleeing 0;
            _unit setSkill 0.45;
            DYN_ground_enemies pushBack _unit;
        };
    };

    _interceptData pushBack [_grp, _iPos];
    diag_log format ["[GROUND-SUPPLY] Intercept group %1 ready at %2 (%3 units)", _i + 1, _iPos, _unitCount];
};

// =====================================================
// 5. TASK + MARKERS
// =====================================================
private _taskId  = format ["ground_supply_%1", round (diag_tickTime * 1000)];
private _mkrDest = format ["supply_dest_%1",   round (diag_tickTime * 1000)];
private _mkrBase = format ["supply_base_%1",   round (diag_tickTime * 1000)];

// Green drop-off zone at destination
createMarker [_mkrDest, _destPos];
_mkrDest setMarkerShape  "ELLIPSE";
_mkrDest setMarkerSize   [_dropRadius, _dropRadius];
_mkrDest setMarkerColor  "ColorGreen";
_mkrDest setMarkerBrush  "SolidFull";
_mkrDest setMarkerAlpha  0.25;
_mkrDest setMarkerText   format ["Drop-off: %1", _destName];
DYN_ground_markers pushBack _mkrDest;

// Orange supply pickup indicator at base
createMarker [_mkrBase, _deliveryMkrPos];
_mkrBase setMarkerShape  "ELLIPSE";
_mkrBase setMarkerSize   [25, 25];
_mkrBase setMarkerColor  "ColorOrange";
_mkrBase setMarkerBrush  "SolidFull";
_mkrBase setMarkerAlpha  0.25;
_mkrBase setMarkerText   "Supply Pickup";
DYN_ground_markers pushBack _mkrBase;

[
    west,
    _taskId,
    [
        format [
            "Friendly forces and civilian aid in %1 are running low on essential supplies. A logistics convoy has been prepared and must be delivered safely to the city.<br/><br/>Escort the supply vehicle to %1 and ensure the cargo arrives intact. Enemy presence has been reported along the route, and insurgent elements may attempt to intercept the delivery.<br/><br/>Protect the vehicle and driver at all costs. If the supplies are destroyed, the mission will fail.",
            _destName
        ],
        format ["Supply Delivery — %1", _destName],
        ""
    ],
    _destPos,
    "ASSIGNED",
    2,
    true,
    "move"
] remoteExec ["BIS_fnc_taskCreate", 0, _taskId];

DYN_ground_tasks pushBack _taskId;

diag_log format ["[GROUND-SUPPLY] Task '%1' created. Destination: %2", _taskId, _destName];

// =====================================================
// 6. MONITORING
// =====================================================
private _localObjects = +DYN_ground_objects;
private _localEnemies = +DYN_ground_enemies;
private _localGroups  = +DYN_ground_enemyGroups;
private _localMarkers = +DYN_ground_markers;

[
    _supplyItems, _interceptData, _destPos, _dropRadius,
    _taskId, _timeout, _cleanupDelay, _repReward,
    _destName, _localObjects, _localEnemies, _localGroups, _localMarkers
] spawn {
    params [
        "_items", "_interceptData", "_dPos", "_dRadius",
        "_tid", "_tOut", "_despawnDelay", "_rep",
        "_dName", "_lObjects", "_lEnemies", "_lGroups", "_lMarkers"
    ];

    private _startTime     = diag_tickTime;
    private _done          = false;
    private _activatedGrps = [];

    // Returns true if the item has been unloaded physically inside the drop-off zone.
    // An item still loaded in ACE cargo keeps its original world position (base),
    // so the distance check naturally fails until it is actually unloaded on-site.
    private _fn_itemDelivered = {
        params ["_item", "_dPos", "_dR"];
        if (isNull _item) exitWith { false };
        if (_item distance2D _dPos > _dR) exitWith { false };
        !(_item getVariable ["ace_cargo_isLoaded", false])
    };

    while { !_done } do {
        sleep 10;

        // --- Timeout ---
        if (diag_tickTime - _startTime > _tOut) then {
            [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
            ["TaskFailed", ["Mission Expired", "The supplies were not delivered in time."]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log "[GROUND-SUPPLY] TIMEOUT. Mission failed.";
            _done = true;
            continue;
        };

        // --- Intercept trigger: activate when any player drives within 150 m ---
        {
            _x params ["_grp", "_gPos"];
            if (!isNull _grp && !(_grp in _activatedGrps)) then {
                private _playersNear = { alive _x && _x distance2D _gPos < 150 } count allPlayers;
                if (_playersNear > 0) then {
                    _activatedGrps pushBack _grp;

                    { if (alive _x) then {
                        _x enableAI "MOVE";
                        _x enableAI "PATH";
                        _x enableAI "AUTOCOMBAT";
                    }; } forEach units _grp;

                    _grp setBehaviour  "COMBAT";
                    _grp setCombatMode "RED";
                    _grp setSpeedMode  "FULL";

                    // SAD waypoint toward nearest alive player
                    private _alivePlayers = allPlayers select { alive _x };
                    if (count _alivePlayers > 0) then {
                        private _nearest = _alivePlayers select 0;
                        { if (_x distance2D _gPos < _nearest distance2D _gPos) then { _nearest = _x; }; } forEach _alivePlayers;
                        private _wp = _grp addWaypoint [getPos _nearest, 0];
                        _wp setWaypointType "SAD";
                    };

                    diag_log format ["[GROUND-SUPPLY] Intercept group activated at %1.", _gPos];
                };
            };
        } forEach _interceptData;

        // --- Delivery check: all items unloaded inside drop-off zone ---
        private _deliveredCount = { [_x, _dPos, _dRadius] call _fn_itemDelivered } count _items;
        if (_deliveredCount == count _items) then {
            [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
            [_rep, format ["Supplies Delivered to %1", _dName]] call DYN_fnc_changeReputation;
            ["TaskSucceeded", ["Supplies Delivered", format ["+%1 REP. Cargo arrived in %2.", _rep, _dName]]]
                remoteExecCall ["BIS_fnc_showNotification", 0];
            diag_log format ["[GROUND-SUPPLY] SUCCESS. All supplies at %1. +%2 rep.", _dName, _rep];
            _done = true;
            continue;
        };
    };

    // --- Cleanup ---
    { deleteMarker _x } forEach _lMarkers;
    DYN_ground_markers = DYN_ground_markers - _lMarkers;

    sleep 15;
    [_tid] call BIS_fnc_deleteTask;

    DYN_ground_active = false;

    diag_log format ["[GROUND-SUPPLY] Despawning in %1 seconds.", _despawnDelay];
    sleep _despawnDelay;

    { if (!isNull _x) then { deleteVehicle _x } } forEach _lObjects;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _lEnemies;
    { if (!isNull _x) then { deleteGroup  _x } } forEach _lGroups;

    DYN_ground_objects     = DYN_ground_objects     - _lObjects;
    DYN_ground_enemies     = DYN_ground_enemies     - _lEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _lGroups;

    diag_log "[GROUND-SUPPLY] Full cleanup complete.";
};

diag_log "[GROUND-SUPPLY] Supply Delivery mission initialized.";
