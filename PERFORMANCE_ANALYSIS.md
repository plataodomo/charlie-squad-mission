# Charlie Squad - FPS Performance Analysis

## Critical Issues (High Impact)

### 1. Radio Tower Mines: 55 Concurrent `waitUntil` Threads
**File:** `scripts/fn_radioTower.sqf` (lines 154-168)
**Impact:** SEVERE - 55 independent scripts running simultaneously

Each of the 55 mines spawns its own `spawn` thread that runs a `waitUntil` loop every 0.25 seconds, calling `nearEntities` and checking `isPlayer` on every result:
```sqf
[_mine] spawn {
    waitUntil {
        sleep 0.25;
        isNull _mine
        || { (_mine nearEntities ["Man", _radius]) findIf { isPlayer _x && alive _x && side (group _x) == west } > -1 }
    };
};
```
That's **55 threads** each doing spatial queries 4 times per second = **220 `nearEntities` calls/second**.

**Fix:** Replace with a single monitoring loop that iterates the mine array once every 0.5-1s, or use a trigger/area-based approach.

---

### 2. Combat Aggression Enhancer: Iterates ALL Groups Every 8 Seconds
**File:** `scripts/fn_infantryPatrol.sqf` (lines 237-280)
**Impact:** HIGH - O(groups × units × targets) every 8 seconds

Every 8 seconds this loop iterates **every group** in `DYN_AO_enemyGroups`, and for each group in combat it:
- Calls `targets` on the leader (expensive engine query)
- Sorts targets by distance (`BIS_fnc_sortBy`)
- Calls `reveal` on EVERY unit in the group
- Calls `doSuppressiveFire` on EVERY unit
- Checks `secondaryWeapon` and calls `doTarget`/`doFire` on every unit

With 40-60+ active groups containing 3-7 units each, this is iterating **hundreds of units** and issuing hundreds of AI commands every 8 seconds. During heavy combat, nearly every group will be in COMBAT mode.

**Fix:** Limit to a max of 5-8 groups per cycle, skip groups that were processed recently, increase interval to 15-20s.

---

### 3. Massive AI Unit Count Per AO (~400-650 units)
**Impact:** HIGH - cumulative AI simulation load

Adding up all spawned units per AO:
| Source | Units (approx) |
|--------|---------------|
| fn_createObjective garrison | 72-108 |
| fn_infantryPatrol building defenders | 56-112 |
| fn_infantryPatrol infantry patrols | 108-161 |
| fn_infantryPatrol vehicle crews | 30-48 |
| fn_infantryPatrol hilltop teams | 16-32 |
| fn_infantryPatrol snipers/lone wolves | 6-20 |
| fn_enemyHQ (defenders + officer) | 35-55 |
| fn_fuelDepot (guards + snipers) | 25-40 |
| fn_dataLink (guards + patrols) | 15-25 |
| fn_gpsJammer (guards + patrols) | 7-12 |
| fn_mortarPit (crew + guards) | 6-10 |
| fn_aaPits (gunners) | 4-8 |
| fn_airPatrols (crews) | 6-15 |
| fn_createObjective vehicles crews | 18-42 |
| fn_createObjective AA infantry | 4 |
| fn_createObjective naval crews | 5-20 |
| fn_createObjective civilians | 7-9 |
| Side objectives guards | 6-15 |

**Total: ~430-730 AI units in a single AO**

This is a core driver of FPS issues. Even with Arma's AI LOD system, this many units cause significant server-side simulation load. Each unit runs its own AI state machine (pathfinding, target detection, behavior FSM).

**Fix:** Scale unit counts based on player count. Consider reducing building defender count (you garrison buildings in BOTH fn_createObjective AND fn_infantryPatrol, creating double-garrisons). Cut infantry patrol count from 18-22 down to 10-14.

---

### 4. AA Pit Targeting Loops: Iterates ALL `vehicles` Every 1.5s
**File:** `scripts/fn_aaPits.sqf` (lines 477-521)
**Impact:** HIGH - `vehicles` is a global list

Each AA pit (4-8 of them) runs a targeting loop every 1.5 seconds that iterates the **entire global `vehicles` array**:
```sqf
{
    private _v = _x;
    if (alive _v && {(_v isKindOf "Helicopter") || (_v isKindOf "Plane")} && ...) then { ... };
} forEach vehicles;
```
With all the spawned vehicles (enemy patrols, civilian cars, boats, AA vehicles themselves), `vehicles` can contain 30-60+ entries. That's 4-8 threads each scanning 30-60 vehicles every 1.5 seconds.

**Fix:** Use a single centralized air-target tracker that runs once and shares results, or increase the interval to 3-5 seconds.

---

### 5. Mortar Fire Support: Iterates ALL `DYN_AO_enemies` Every 4-6 Seconds
**File:** `scripts/fn_mortarPit.sqf` (lines 369-436)
**Impact:** HIGH

Every 4-6 seconds the mortar system filters the **entire** `DYN_AO_enemies` array (400-700+ entries) to find spotters:
```sqf
private _spotters = DYN_AO_enemies select {
    !isNull _x && {alive _x} && {_x isKindOf "Man"} && {side (group _x) == east}
    && {behaviour _x in ["AWARE","COMBAT"]} && ...
};
```
Then for each player, it iterates ALL spotters to check `knowsAbout`. With 500+ enemies and 4+ players, that's ~2000+ checks per cycle.

**Fix:** Cache a smaller spotter list, or only sample 20-30 random enemies as spotters instead of checking all of them.

---

### 6. All AO Sub-Scripts Launched Simultaneously
**File:** `scripts/fn_createObjective.sqf` (lines 73-82)
**Impact:** HIGH - massive spawn-time FPS spike

All 10+ objective scripts are `execVM`'d at nearly the same time:
```sqf
[_pos, _aoRadius] execVM "scripts\fn_fuelDepot.sqf";
[_pos, _spawnRadius] execVM "scripts\fn_radioTower.sqf";
[_pos, _aoRadius] execVM "scripts\fn_mortarPit.sqf";
[_pos, _aoRadius] execVM "scripts\fn_enemyHQ.sqf";
[_pos, _aoRadius] execVM "scripts\fn_spawnSideObjectives.sqf";
// ... etc
```
Each script independently runs heavy position-search loops (`BIS_fnc_findSafePos`, `nearestObjects`, `nearestTerrainObjects`), creates dozens of units, and places objects. All of this hitting the scheduler simultaneously causes a major FPS drop at AO creation.

**Fix:** Stagger the `execVM` calls with `sleep` between them (2-3s each). You already have `DYN_fnc_createGroupStaggered` defined but it's not actually used by any of these scripts.

---

### 7. Double Building Garrison
**Files:** `fn_createObjective.sqf` (lines 87-104) AND `fn_infantryPatrol.sqf` (lines 283-341)
**Impact:** MEDIUM-HIGH

`fn_createObjective.sqf` garrisons up to 18 buildings with 3-5 soldiers each (~72-90 units).
`fn_infantryPatrol.sqf` ALSO garrisons up to 28 more buildings with 2-4 soldiers each (~56-112 units).

These are independent systems that don't check for overlap, so some buildings may be double-garrisoned. Combined this creates **128-202 static garrison AI** that all need individual AI simulation.

**Fix:** Remove the garrison from `fn_createObjective.sqf` since `fn_infantryPatrol.sqf` does it more thoroughly, or have them share a "garrisoned buildings" list.

---

## Medium Issues

### 8. 18-22+ Concurrent Patrol `spawn` Threads
**File:** `scripts/fn_infantryPatrol.sqf` (lines 468-501)
**Impact:** MEDIUM - many persistent threads

Each infantry patrol group gets its own `spawn DYN_fnc_patrolCycle` thread. With 18-22 infantry patrols plus 10-16 vehicle patrols, that's **28-38 concurrent threads** each running `waitUntil` loops with `sleep 5`, doing road queries, safe-pos calculations, and waypoint management.

**Fix:** Consider a centralized patrol manager that processes all patrol groups in batches from a single thread.

---

### 9. Completion Check Iterates All Enemies Every 5 Seconds
**File:** `scripts/fn_createObjective.sqf` (lines 304-318)
**Impact:** MEDIUM

```sqf
private _neutralized = { isNull _x || {!alive _x} || {_x getVariable ["DYN_prisonDelivered", false]} } count DYN_AO_enemies;
```
With 400-700+ entries in `DYN_AO_enemies`, this iterates the entire array every 5 seconds checking liveness and variable lookups.

**Fix:** Maintain a running counter updated via Killed event handlers instead of re-scanning the entire array.

---

### 10. `EntityCreated` Event Handler During Mass Spawning
**File:** `init.sqf` (lines 229-234)
**Impact:** MEDIUM - fires hundreds of times at AO creation

```sqf
addMissionEventHandler ["EntityCreated", {
    if (!isNull _ent && {_ent isKindOf "Man"}) then {
        [_ent] call DYN_fnc_boostOpforAwareness;
    };
}];
```
During AO creation when 400+ units are spawned rapidly, this handler fires for **every single one**, each time doing side checks, group checks, and 6 `setSkill` calls. This compounds the already heavy spawn-time load.

**Fix:** Add a rate limiter, or batch-apply skills after spawning is complete rather than on each entity creation.

---

### 11. Dead Body Cleanup Spawns Individual Threads Per Kill
**File:** `init.sqf` (lines 397-448)
**Impact:** MEDIUM - thread accumulation over long sessions

Each kill event spawns a new thread that sleeps for 2-8 minutes then deletes the corpse. Over a long session with 200+ kills, you'll have 200+ sleeping threads in the scheduler.

**Fix:** Use a single cleanup loop that checks a list of corpses with timestamps, running every 30-60 seconds.

---

### 12. Prison System Iterates `allUnits` Every 2 Seconds
**File:** `scripts/fn_prisonSystem.sqf`
**Impact:** MEDIUM

The prison drop-off check iterates `allUnits` every 2 seconds to find prisoners in the drop-off area. With 400+ units on the server, that's a lot of filtering.

**Fix:** Only iterate `allPlayers` + a tracked prisoner list instead of all units.

---

### 13. Fuel Depot Target Settling: 20 Iterations Per Target
**File:** `scripts/fn_fuelDepot.sqf` (lines 322-331)
**Impact:** MEDIUM - concentrated burst at spawn time

Each fuel target (7+ pods + 3 trucks = ~10 objects) runs a settling loop with 20 iterations at 0.25s intervals, each calling `getAllHitPointsDamage` and `setHitPointDamage` on every hitpoint. With 10+ hitpoints per vehicle × 10 vehicles × 20 iterations = **2000+ hitpoint operations** during settling.

**Fix:** Reduce iterations to 8-10, increase interval to 0.5s, or only clear hitpoints if damage is detected.

---

### 14. Air Patrol Engagement Loops
**File:** `scripts/fn_airPatrols.sqf`
**Impact:** MEDIUM

Each helicopter (2-5) runs two concurrent spawn threads:
- One checking `allPlayers` + `vehicles` every 2-4 seconds
- One checking position/combat state every 8-12 seconds

This adds 4-10 persistent threads doing player scans.

---

## Low Issues

### 15. AA Pit Post-Settle Stabilization at 10Hz
**File:** `scripts/fn_aaPits.sqf` (lines 360-380)
**Impact:** LOW (temporary, 3 seconds per pit)

Each AA pit runs a stabilization loop at `sleep 0.1` (10Hz) for 3 seconds. With 4-8 pits this is 4-8 threads at 10Hz briefly at spawn time.

### 16. Position Search Loops Run Hundreds of Iterations
**Files:** Multiple (fn_enemyHQ, fn_aaPits, fn_gpsJammer, fn_fuelDepot)
**Impact:** LOW (one-time at spawn)

Position finding can run 60-500 iterations of `BIS_fnc_findSafePos` + `nearestObjects` checks. These are expensive but one-time costs at AO creation.

### 17. Staggered Spawning System is Defined But Not Used
**File:** `init.sqf` (lines 252-336)
**Impact:** N/A - missed optimization opportunity

`DYN_fnc_createGroupStaggered` and `DYN_fnc_spawnGroupsBatch` are defined but never called by any script. All actual unit creation uses direct `createUnit` calls.

---

## Summary of Recommendations (Priority Order)

1. **Replace 55 individual mine threads** with a single monitoring loop
2. **Reduce total AI count** by removing double garrison and scaling patrol counts
3. **Throttle the Combat Aggression Enhancer** - process max 5 groups per cycle
4. **Stagger AO sub-script execution** - add 2-3s delays between each `execVM`
5. **Centralize AA targeting** - single thread shares air targets with all AA
6. **Optimize mortar spotter search** - sample a subset instead of all enemies
7. **Use kill-count event handlers** instead of scanning `DYN_AO_enemies` every 5s
8. **Batch dead body cleanup** into a single periodic loop
9. **Actually use** the staggered spawning system you already built
10. **Centralize patrol management** to reduce concurrent thread count
