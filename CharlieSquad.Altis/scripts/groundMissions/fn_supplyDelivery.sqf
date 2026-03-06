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
private _supplyMkrPos   = getMarkerPos "supply_delivery";
private _aoCenter       = missionNamespace getVariable ["DYN_AO_center", [0,0,0]];

// Fallback if supply_delivery marker is missing
if (_supplyMkrPos isEqualTo [0,0,0]) then {
    _supplyMkrPos = _basePos;
    diag_log "[GROUND-SUPPLY] WARNING: 'supply_delivery' marker not found — falling back to respawn_west.";
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
// 3. SPAWN SUPPLY ITEMS at supply_delivery marker
// =====================================================
private _supplyItems = [];
{
    // Spread items in a triangle around the supply_delivery marker
    private _angle  = _forEachIndex * 120;
    private _offset = [_supplyMkrPos, 1.5 + random 1.0, _angle] call DYN_fnc_posOffset;
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
// 4. FIND AMBUSH TOWNS along the route (NO pre-spawn)
// =====================================================
// Enemies only exist when players approach — zero map footprint until then.
// We find named locations that sit within a 900 m corridor of the straight
// line between base and destination.  When a player drives within 400 m of
// one of these towns the ambush group is spawned inside the local buildings.

// --- Parametric projection helpers (setup only, not passed to spawn) ---
private _fn_projT = {
    // Returns 0-1: where _p projects onto the _a→_b segment
    params ["_p","_a","_b"];
    private _dx = (_b#0) - (_a#0); private _dy = (_b#1) - (_a#1);
    private _len2 = _dx*_dx + _dy*_dy;
    if (_len2 < 1) exitWith { 0.0 };
    (((_p#0)-(_a#0))*_dx + ((_p#1)-(_a#1))*_dy) / _len2
};
private _fn_distToLine = {
    // Perpendicular distance from _p to the finite segment _a→_b
    params ["_p","_a","_b"];
    private _t = ([_p,_a,_b] call _fn_projT) max 0.0 min 1.0;
    private _cx = (_a#0) + _t*((_b#0)-(_a#0));
    private _cy = (_a#1) + _t*((_b#1)-(_a#1));
    _p distance2D [_cx,_cy,0]
};

// Gather all named locations that sit inside the route corridor
private _ambushPoints = [];
{
    private _lPos = locationPosition _x;
    if (surfaceIsWater _lPos) then { continue };
    // Must be between 15 % and 85 % along the route (skip near base / dest)
    private _t = [_lPos, _basePos, _destPos] call _fn_projT;
    if (_t < 0.15 || _t > 0.85) then { continue };
    // Must be within 900 m of the straight-line route
    if (([_lPos, _basePos, _destPos] call _fn_distToLine) > 900) then { continue };
    // Must have buildings so enemies can occupy them
    if (count (nearestObjects [_lPos, ["House","Building"], 120]) < 3) then { continue };
    _ambushPoints pushBack _lPos;
} forEach (_allLocs call BIS_fnc_arrayShuffle);

// Sort earliest-to-latest along the route and cap at 3 towns
_ambushPoints = [_ambushPoints, [], { [_x, _basePos, _destPos] call _fn_projT }, "ASCEND"] call BIS_fnc_sortBy;
if (count _ambushPoints > 3) then { _ambushPoints resize 3; };

// Fallback: if no towns were in corridor, sample road points along the line
if (count _ambushPoints == 0) then {
    private _n = 2 + floor (random 2);
    for "_i" from 1 to _n do {
        private _t    = _i / (_n + 1.0);
        private _sPos = [
            (_basePos#0) + _t * ((_destPos#0) - (_basePos#0)),
            (_basePos#1) + _t * ((_destPos#1) - (_basePos#1)), 0
        ];
        private _nearRds = _sPos nearRoads 400;
        _ambushPoints pushBack (if (count _nearRds > 0) then { getPos (selectRandom _nearRds) } else { _sPos });
    };
    diag_log "[GROUND-SUPPLY] No route towns in corridor — using road-point fallback.";
};

diag_log format ["[GROUND-SUPPLY] %1 ambush point(s) identified along route.", count _ambushPoints];

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

// Small icon marker at supply_delivery — task-style, not a zone
createMarker [_mkrBase, _supplyMkrPos];
_mkrBase setMarkerShape "ICON";
_mkrBase setMarkerType  "hd_dot";
_mkrBase setMarkerColor "ColorOrange";
_mkrBase setMarkerAlpha 0.9;
_mkrBase setMarkerText  "Pick up supplies here";
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
private _localMarkers = +DYN_ground_markers;
// No pre-spawned enemies — groups/units are created dynamically inside the spawn block

[
    _supplyItems, _ambushPoints, _enemyPool, _destPos, _dropRadius,
    _taskId, _timeout, _cleanupDelay, _repReward,
    _destName, _localObjects, _localMarkers
] spawn {
    params [
        "_items", "_ambushPoints", "_ePool", "_dPos", "_dRadius",
        "_tid", "_tOut", "_despawnDelay", "_rep",
        "_dName", "_lObjects", "_lMarkers"
    ];

    private _startTime       = diag_tickTime;
    private _done            = false;
    private _triggeredPoints = [];  // ambush positions already activated
    private _dynGroups       = [];  // groups spawned dynamically, cleaned up at end
    private _dynEnemies      = [];  // units spawned dynamically

    // True when an item has been physically unloaded inside the drop-off zone.
    // ACE cargo freezes a loaded item's world position at its base spawn point,
    // so the distance check fails naturally until the crate is actually set down.
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

        // --- Dynamic ambush spawn: create group when player reaches town ---
        // Nothing exists on the map until this fires — proper ambush feel.
        {
            if (_x in _triggeredPoints) then { continue };
            private _aPos = _x;
            if ({ alive _x && _x distance2D _aPos < 400 } count allPlayers == 0) then { continue };

            // Mark triggered before spawning so a double-tick can't double-spawn
            _triggeredPoints pushBack _aPos;

            private _grp = createGroup east;
            _dynGroups pushBack _grp;
            _grp setBehaviour  "AWARE";
            _grp setCombatMode "RED";

            // Prefer interior building positions so they look like occupiers
            private _allHouses   = nearestObjects [_aPos, ["House","Building"], 150];
            private _validHouses = _allHouses select { count ([_x] call BIS_fnc_buildingPositions) > 0 };
            private _unitCount   = 4 + floor (random 3);  // 4-6 per town

            for "_u" from 1 to _unitCount do {
                private _spawnPos = [];

                if (count _validHouses > 0) then {
                    for "_t" from 1 to 8 do {
                        private _bldg    = selectRandom _validHouses;
                        private _bldgPos = [_bldg] call BIS_fnc_buildingPositions;
                        if (count _bldgPos > 0) exitWith { _spawnPos = selectRandom _bldgPos; };
                    };
                };

                if (_spawnPos isEqualTo []) then {
                    _spawnPos = [_aPos, 5 + random 30, random 360] call DYN_fnc_posOffset;
                };

                private _unit = _grp createUnit [selectRandom _ePool, _spawnPos, [], 0, "NONE"];
                if (!isNull _unit) then {
                    _unit allowFleeing 0;
                    _unit setSkill (0.40 + random 0.15);
                    _dynEnemies pushBack _unit;
                };
            };

            // SAD waypoint on nearest player
            private _alive = allPlayers select { alive _x };
            if (count _alive > 0) then {
                private _nearest = _alive select 0;
                { if (_x distance2D _aPos < _nearest distance2D _aPos) then { _nearest = _x; }; } forEach _alive;
                private _wp = _grp addWaypoint [getPos _nearest, 0];
                _wp setWaypointType "SAD";
            };

            diag_log format ["[GROUND-SUPPLY] Ambush spawned at %1 (%2 units).", _aPos, _unitCount];
        } forEach _ambushPoints;

        // --- Delivery check: all items unloaded inside drop-off zone ---
        if ({ [_x, _dPos, _dRadius] call _fn_itemDelivered } count _items == count _items) then {
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
    { if (!isNull _x) then { deleteVehicle _x } } forEach _dynEnemies;
    { if (!isNull _x) then { deleteGroup  _x } } forEach _dynGroups;

    DYN_ground_objects = DYN_ground_objects - _lObjects;

    diag_log "[GROUND-SUPPLY] Full cleanup complete.";
};

diag_log "[GROUND-SUPPLY] Supply Delivery mission initialized.";
