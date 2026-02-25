/*
    scripts\naval\fn_clearCompositionArea.sqf
    Clears vegetation and rocks at a position
    Call AFTER finding position, BEFORE spawning composition
    
    Params:
        _pos    - center position
        _radius - clearing radius (default 45)
    
    Returns: array of hidden terrain objects for cleanup
*/
if (!isServer) exitWith {[]};

params [
    ["_pos", [0,0,0], [[]]],
    ["_radius", 45, [0]]
];

private _removed = [];

// Remove terrain objects (trees, bushes, rocks)
private _terrainObjects = nearestTerrainObjects [_pos, ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS"], _radius, false];

{
    _x hideObjectGlobal true;
    _removed pushBack _x;
} forEach _terrainObjects;

diag_log format ["[NAVAL-CLEAR] Hidden %1 terrain objects within %2m of %3", count _terrainObjects, _radius, _pos];

_removed