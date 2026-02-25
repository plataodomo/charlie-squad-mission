/*
    scripts\fn_spawnObjectives.sqf
    Server only
*/
if (!isServer) exitWith {};

// hard lock immediately
if (missionNamespace getVariable ["DYN_AO_lock", false]) exitWith {};
missionNamespace setVariable ["DYN_AO_lock", true, true];
missionNamespace setVariable ["DYN_AO_cleanupDone", false, false];

private _center = getMarkerPos "respawn_west";
if (_center isEqualTo [0,0,0]) exitWith { missionNamespace setVariable ["DYN_AO_lock", false, true]; };

private _minFromBase = 2000;
private _searchRadius = 30000;

private _types = ["NameCity", "NameCityCapital", "NameVillage"];
private _citiesAll = nearestLocations [_center, _types, _searchRadius];
if (_citiesAll isEqualTo []) exitWith { missionNamespace setVariable ["DYN_AO_lock", false, true]; };

private _used = missionNamespace getVariable ["DYN_usedCities", []];

private _candidates = _citiesAll select {
    private _p = locationPosition _x;
    (_p distance2D _center) > _minFromBase && { !(text _x in _used) }
};

if (_candidates isEqualTo []) then {
    missionNamespace setVariable ["DYN_usedCities", []];
    _used = [];

    _candidates = _citiesAll select {
        private _p = locationPosition _x;
        (_p distance2D _center) > _minFromBase
    };
};

if (_candidates isEqualTo []) exitWith { missionNamespace setVariable ["DYN_AO_lock", false, true]; };

private _city = selectRandom _candidates;
private _pos  = locationPosition _city;
private _name = text _city;

_used pushBackUnique _name;
missionNamespace setVariable ["DYN_usedCities", _used];

[_pos, _name] execVM "scripts\fn_createObjective.sqf";