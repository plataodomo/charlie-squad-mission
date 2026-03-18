/*
    scripts\groundMissions\fn_fobHunting.sqf
    GROUND MISSION: FOB Hunting

    Players are tasked with infiltrating a heavily defended enemy FOB and
    destroying all four supply asset types:
        - B_Slingload_01_Repair_F   (+8 rep)
        - B_Slingload_01_Ammo_F     (+8 rep)
        - B_Slingload_01_Fuel_F     (+8 rep)
        - Box_EAF_AmmoVeh_F x2      (+5 rep each = +10 rep)
    Total possible: 34 reputation

    The FOB is located at a fixed position on the map. A garrison of OPFOR
    infantry defends the compound. All assets must be destroyed within the
    time limit for full mission success.
*/
if (!isServer) exitWith {};

diag_log "[GROUND-FOB] Setting up FOB Hunting mission...";

// =====================================================
// 1. SETTINGS
// =====================================================
private _fobCenter    = [7395, 6412, 0];   // Centre of the FOB compound
private _searchRadius = 200;               // Radius for target object search
private _timeout      = 7200;             // 2 hours
private _cleanupDelay = 120;              // Seconds before entity despawn after mission end

// Reputation per destroyed asset (total 34 if all destroyed)
private _repPerSlingload = 8;   // x3 = 24
private _repPerAmmoBox   = 5;   // x2 = 10

// =====================================================
// 2. SPAWN THE FOB BUILDING
// =====================================================
diag_log "[GROUND-FOB] Creating FOB building objects...";
// ---- inlined FOB building composition ----
private _layerWhiteList = [];
private _layerBlacklist = [];
private _allWhitelisted = _layerWhiteList isEqualTo [];
private _layerRoot = (_allWhitelisted || {true in _layerWhiteList}) && {!(true in _layerBlackList)};
private _layer136 = (_allWhitelisted || {"fob_10" in _layerWhiteList}) && {!("fob_10" in _layerBlackList)};
private _layer135 = (_allWhitelisted || {"fob_9" in _layerWhiteList}) && {!("fob_9" in _layerBlackList)};
private _layer134 = (_allWhitelisted || {"fob_8" in _layerWhiteList}) && {!("fob_8" in _layerBlackList)};
private _layer133 = (_allWhitelisted || {"fob_7" in _layerWhiteList}) && {!("fob_7" in _layerBlackList)};
private _layer3 = (_allWhitelisted || {"walled fob v2" in _layerWhiteList}) && {!("walled fob v2" in _layerBlackList)};
private _layer6 = (_allWhitelisted || {"fob_5" in _layerWhiteList}) && {!("fob_5" in _layerBlackList)};
private _layer5 = (_allWhitelisted || {"fob_4" in _layerWhiteList}) && {!("fob_4" in _layerBlackList)};
private _layer802 = (_allWhitelisted || {"walled fob v2" in _layerWhiteList}) && {!("walled fob v2" in _layerBlackList)};
////////////////////////////////////////////////////////////////////////////////////////////
// Markers
private _markers = [];
private _markerIDs = [];
////////////////////////////////////////////////////////////////////////////////////////////
// Groups
private _groups = [];
private _groupIDs = [];
////////////////////////////////////////////////////////////////////////////////////////////
// Objects
private _objects = [];
private _objectIDs = [];
private _item8 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item8 = createVehicle ["Land_Mil_WallBig_4m_F",[7367.05,6392.27,0],[],0,"CAN_COLLIDE"];
	_this = _item8;
	_objects pushback _this;
	_objectIDs pushback 8;
	_this setPosWorld [7367.05,6392.27,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item9 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item9 = createVehicle ["Land_Mil_WallBig_4m_F",[7368.8,6388.66,0],[],0,"CAN_COLLIDE"];
	_this = _item9;
	_objects pushback _this;
	_objectIDs pushback 9;
	_this setPosWorld [7368.8,6388.66,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item10 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item10 = createVehicle ["Land_Mil_WallBig_4m_F",[7370.51,6385.04,0],[],0,"CAN_COLLIDE"];
	_this = _item10;
	_objects pushback _this;
	_objectIDs pushback 10;
	_this setPosWorld [7370.51,6385.04,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item11 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item11 = createVehicle ["Land_Mil_WallBig_4m_F",[7372.23,6381.42,0],[],0,"CAN_COLLIDE"];
	_this = _item11;
	_objects pushback _this;
	_objectIDs pushback 11;
	_this setPosWorld [7372.23,6381.42,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item12 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item12 = createVehicle ["Land_Mil_WallBig_4m_F",[7373.98,6377.81,0],[],0,"CAN_COLLIDE"];
	_this = _item12;
	_objects pushback _this;
	_objectIDs pushback 12;
	_this setPosWorld [7373.98,6377.81,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item13 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item13 = createVehicle ["Land_Mil_WallBig_4m_F",[7375.74,6374.2,0],[],0,"CAN_COLLIDE"];
	_this = _item13;
	_objects pushback _this;
	_objectIDs pushback 13;
	_this setPosWorld [7375.74,6374.2,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item14 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item14 = createVehicle ["Land_Mil_WallBig_4m_F",[7377.45,6370.58,0],[],0,"CAN_COLLIDE"];
	_this = _item14;
	_objects pushback _this;
	_objectIDs pushback 14;
	_this setPosWorld [7377.45,6370.58,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item15 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item15 = createVehicle ["Land_Mil_WallBig_4m_F",[7379.2,6366.98,0],[],0,"CAN_COLLIDE"];
	_this = _item15;
	_objects pushback _this;
	_objectIDs pushback 15;
	_this setPosWorld [7379.2,6366.98,6.69987];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item16 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item16 = createVehicle ["Land_Mil_WallBig_4m_F",[7381.71,6366.25,0],[],0,"CAN_COLLIDE"];
	_this = _item16;
	_objects pushback _this;
	_objectIDs pushback 16;
	_this setPosWorld [7381.71,6366.25,6.69987];
	_this setVectorDirAndUp [[-0.413285,0.910602,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item17 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item17 = createVehicle ["Land_Mil_WallBig_4m_F",[7385.34,6367.94,0],[],0,"CAN_COLLIDE"];
	_this = _item17;
	_objects pushback _this;
	_objectIDs pushback 17;
	_this setPosWorld [7385.34,6367.94,6.69987];
	_this setVectorDirAndUp [[-0.413285,0.910602,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item18 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item18 = createVehicle ["Land_Mil_WallBig_4m_F",[7388.99,6369.59,0],[],0,"CAN_COLLIDE"];
	_this = _item18;
	_objects pushback _this;
	_objectIDs pushback 18;
	_this setPosWorld [7388.99,6369.59,6.69987];
	_this setVectorDirAndUp [[-0.413285,0.910602,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item19 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item19 = createVehicle ["Land_Mil_WallBig_4m_F",[7392.64,6371.25,0],[],0,"CAN_COLLIDE"];
	_this = _item19;
	_objects pushback _this;
	_objectIDs pushback 19;
	_this setPosWorld [7392.64,6371.25,6.69987];
	_this setVectorDirAndUp [[-0.413285,0.910602,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item20 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item20 = createVehicle ["Land_Mil_WallBig_4m_F",[7396.28,6372.93,0],[],0,"CAN_COLLIDE"];
	_this = _item20;
	_objects pushback _this;
	_objectIDs pushback 20;
	_this setPosWorld [7396.28,6372.93,6.69987];
	_this setVectorDirAndUp [[-0.413285,0.910602,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item21 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item21 = createVehicle ["Land_Mil_WallBig_4m_F",[7399.92,6374.62,0],[],0,"CAN_COLLIDE"];
	_this = _item21;
	_objects pushback _this;
	_objectIDs pushback 21;
	_this setPosWorld [7399.92,6374.62,6.69987];
	_this setVectorDirAndUp [[-0.413285,0.910602,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item22 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item22 = createVehicle ["Land_Mil_WallBig_4m_F",[7404.41,6373.29,0],[],0,"CAN_COLLIDE"];
	_this = _item22;
	_objects pushback _this;
	_objectIDs pushback 22;
	_this setPosWorld [7404.41,6373.29,6.69987];
	_this setVectorDirAndUp [[0.925095,0.379736,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item23 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item23 = createVehicle ["Land_BarGate_F",[7355.12,6394.56,0],[],0,"CAN_COLLIDE"];
	_this = _item23;
	_objects pushback _this;
	_objectIDs pushback 23;
	_this setPosWorld [7355.12,6394.56,9.05028];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	['init',_this,[2,0,0]] call bis_fnc_3DENAttributeDoorStates;;
	;
};
private _item24 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item24 = createVehicle ["Land_HBarrierTower_F",[7355.78,6386.06,0],[],0,"CAN_COLLIDE"];
	_this = _item24;
	_objects pushback _this;
	_objectIDs pushback 24;
	_this setPosWorld [7355.78,6386.06,7.18501];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item25 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item25 = createVehicle ["Land_HBarrierTower_F",[7348.22,6401.83,0],[],0,"CAN_COLLIDE"];
	_this = _item25;
	_objects pushback _this;
	_objectIDs pushback 25;
	_this setPosWorld [7348.22,6401.83,7.18501];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item129 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item129 = createVehicle ["Land_Cargo_Patrol_V3_F",[7352.59,6429.74,0],[],0,"CAN_COLLIDE"];
	_this = _item129;
	_objects pushback _this;
	_objectIDs pushback 129;
	_this setPosWorld [7352.59,6429.74,9.905];
	_this setVectorDirAndUp [[0.420555,-0.907267,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item130 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item130 = createVehicle ["Land_Cargo_Patrol_V3_F",[7417.21,6422.87,0],[],0,"CAN_COLLIDE"];
	_this = _item130;
	_objects pushback _this;
	_objectIDs pushback 130;
	_this setPosWorld [7417.21,6422.87,9.905];
	_this setVectorDirAndUp [[-0.945745,0.324911,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item131 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item131 = createVehicle ["Land_Cargo_Patrol_V3_F",[7404.62,6452,0],[],0,"CAN_COLLIDE"];
	_this = _item131;
	_objects pushback _this;
	_objectIDs pushback 131;
	_this setPosWorld [7404.62,6452,9.905];
	_this setVectorDirAndUp [[-0.909046,-0.416696,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item132 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item132 = createVehicle ["Land_Cargo_Patrol_V3_F",[7404.02,6380.42,0],[],0,"CAN_COLLIDE"];
	_this = _item132;
	_objects pushback _this;
	_objectIDs pushback 132;
	_this setPosWorld [7404.02,6380.42,9.905];
	_this setVectorDirAndUp [[-0.424203,0.905567,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item234 = objNull;
if (_layer136 && _layer135 && _layer134 && _layer133 && _layer6 && _layer5 && _layer802) then {
	_item234 = createVehicle ["Land_Cargo_House_V3_F",[7387.29,6433.31,0],[],0,"CAN_COLLIDE"];
	_this = _item234;
	_objects pushback _this;
	_objectIDs pushback 234;
	_this setPosWorld [7387.29,6433.31,5.69];
	_this setVectorDirAndUp [[0.906431,0.422354,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item236 = objNull;
if (_layer136 && _layer135 && _layer134 && _layer133 && _layer6 && _layer5 && _layer802) then {
	_item236 = createVehicle ["Land_Cargo_House_V3_F",[7405.6,6416.46,0],[],0,"CAN_COLLIDE"];
	_this = _item236;
	_objects pushback _this;
	_objectIDs pushback 236;
	_this setPosWorld [7405.6,6416.46,5.69];
	_this setVectorDirAndUp [[0.90327,0.429073,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item237 = objNull;
if (_layer136 && _layer135 && _layer134 && _layer133 && _layer6 && _layer5 && _layer802) then {
	_item237 = createVehicle ["Land_Cargo_House_V3_F",[7399.35,6413.59,0],[],0,"CAN_COLLIDE"];
	_this = _item237;
	_objects pushback _this;
	_objectIDs pushback 237;
	_this setPosWorld [7399.35,6413.59,5.69];
	_this setVectorDirAndUp [[-0.902661,-0.430353,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
private _item246 = objNull;
if (_layer136 && _layer135 && _layer134 && _layer133 && _layer6 && _layer5 && _layer802) then {
	_item246 = createVehicle ["Land_WaterTower_01_F",[7401.82,6404.97,0],[],0,"CAN_COLLIDE"];
	_this = _item246;
	_objects pushback _this;
	_objectIDs pushback 246;
	_this setPosWorld [7401.82,6404.97,9.34407];
	_this setVectorDirAndUp [[-0.41561,0.909543,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	;
};
// TARGET OBJECTS
private _item297 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item297 = createVehicle ["B_Slingload_01_Fuel_F",[7410.43,6384.31,0],[],0,"CAN_COLLIDE"];
	_this = _item297;
	_objects pushback _this;
	_objectIDs pushback 297;
	_this setPosWorld [7410.43,6384.31,6.36245];
	_this setVectorDirAndUp [[-0.415074,0.909788,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	[_this,"[[[[],[]],[[],[]],[[],[]],[[],[]]],false]"] call bis_fnc_initAmmoBox;;
	;
	if (10000 != (_this call ace_refuel_fnc_getFuelCargo)) then {[_this, 10000] call ace_refuel_fnc_makeSource};
	[_this, 50] call ace_cargo_fnc_setSize;
};
private _item298 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item298 = createVehicle ["B_Slingload_01_Repair_F",[7411.89,6413.19,0],[],0,"CAN_COLLIDE"];
	_this = _item298;
	_objects pushback _this;
	_objectIDs pushback 298;
	_this setPosWorld [7411.89,6413.19,6.36052];
	_this setVectorDirAndUp [[-0.912982,-0.407999,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	[_this,"[[[[],[]],[[],[]],[[""ToolKit""],[1]],[[],[]]],false]"] call bis_fnc_initAmmoBox;;
	;
	if (1 != (if (isNumber (configOf _this >> "ace_repair_canRepair")) then {getNumber (configOf _this >> "ace_repair_canRepair")} else {(parseNumber (getRepairCargo _this > 0))})) then {_this setVariable ['s', 1, true]};
	[_this, 50] call ace_cargo_fnc_setSize;
};
private _item299 = objNull;
if (_layer6 && _layer5 && _layer802) then {
	_item299 = createVehicle ["B_Slingload_01_Ammo_F",[7417.9,6415.86,0],[],0,"CAN_COLLIDE"];
	_this = _item299;
	_objects pushback _this;
	_objectIDs pushback 299;
	_this setPosWorld [7417.9,6415.86,6.36204];
	_this setVectorDirAndUp [[-0.904211,-0.427086,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	[_this,"[[[[],[]],[[],[]],[[],[]],[[],[]]],false]"] call bis_fnc_initAmmoBox;;
	;
	if (1200 != (if (isNumber (configOf _this >> 'ace_rearm_defaultSupply')) then {getNumber (configOf _this >> 'ace_rearm_defaultSupply')} else {(if (getAmmoCargo _this > 0) then {getAmmoCargo _this} else {-1})})) then {[_this, 1200] call ace_rearm_fnc_makeSource};
	[_this, 50] call ace_cargo_fnc_setSize;
};
private _item813 = objNull;
if (_layerRoot) then {
	_item813 = createVehicle ["Box_EAF_AmmoVeh_F",[7382.55,6376.82,0],[],0,"CAN_COLLIDE"];
	_this = _item813;
	_objects pushback _this;
	_objectIDs pushback 813;
	_this setPosWorld [7382.55,6376.82,5.78981];
	_this setVectorDirAndUp [[0.916362,0.40035,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	[_this,"[[[[],[]],[[],[]],[[],[]],[[],[]]],false]"] call bis_fnc_initAmmoBox;;
	;
	if (1200 != (if (isNumber (configOf _this >> 'ace_rearm_defaultSupply')) then {getNumber (configOf _this >> 'ace_rearm_defaultSupply')} else {(if (getAmmoCargo _this > 0) then {getAmmoCargo _this} else {-1})})) then {[_this, 1200] call ace_rearm_fnc_makeSource};
	[_this, 2] call ace_cargo_fnc_setSize;
};
private _item815 = objNull;
if (_layerRoot) then {
	_item815 = createVehicle ["Box_EAF_AmmoVeh_F",[7381.93,6378.24,0],[],0,"CAN_COLLIDE"];
	_this = _item815;
	_objects pushback _this;
	_objectIDs pushback 815;
	_this setPosWorld [7381.93,6378.24,5.78981];
	_this setVectorDirAndUp [[0.916362,0.40035,0],[0,0,1]];
	[_this, 0] remoteExec ['setFeatureType', 0, _this];
	[_this,"[[[[],[]],[[],[]],[[],[]],[[],[]]],false]"] call bis_fnc_initAmmoBox;;
	;
	if (1200 != (if (isNumber (configOf _this >> 'ace_rearm_defaultSupply')) then {getNumber (configOf _this >> 'ace_rearm_defaultSupply')} else {(if (getAmmoCargo _this > 0) then {getAmmoCargo _this} else {-1})})) then {[_this, 1200] call ace_rearm_fnc_makeSource};
	[_this, 2] call ace_cargo_fnc_setSize;
};
////////////////////////////////////////////////////////////////////////////////////////////
// Triggers
private _triggers = [];
private _triggerIDs = [];
////////////////////////////////////////////////////////////////////////////////////////////
// Group attributes (applied only once group units exist)
////////////////////////////////////////////////////////////////////////////////////////////
// Waypoints
private _waypoints = [];
private _waypointIDs = [];
////////////////////////////////////////////////////////////////////////////////////////////
// Logics
private _logics = [];
private _logicIDs = [];
////////////////////////////////////////////////////////////////////////////////////////////
// Layers
if (_layer6) then {missionNamespace setVariable ["FOB_Hunting_targets",[[_item297,_item298,_item299],[]]];}; 
if (_layerRoot) then {missionNamespace setVariable ["FOB_Hunting_ammoveh",[[_item813,_item815],[]]];};
// ---- end inlined FOB building composition ----

// Allow object initialisation to settle
sleep 2;

// Collect all FOB building objects for cleanup at mission end
private _fobObjects = [];
{ if (!isNull _x) then { _fobObjects pushBack _x } } forEach _objects;

diag_log format ["[GROUND-FOB] Building SQF created %1 objects.", count _fobObjects];

// =====================================================
// 3. LOCATE TARGET OBJECTS
// =====================================================
private _repairPod = objNull;
private _ammoPod   = objNull;
private _fuelPod   = objNull;
private _ammoBoxes = [];

{
    switch (typeOf _x) do {
        case "B_Slingload_01_Repair_F": { _repairPod = _x };
        case "B_Slingload_01_Ammo_F":   { _ammoPod   = _x };
        case "B_Slingload_01_Fuel_F":   { _fuelPod   = _x };
        case "Box_EAF_AmmoVeh_F":       { _ammoBoxes pushBack _x };
    };
} forEach nearestObjects [_fobCenter,
    ["B_Slingload_01_Repair_F",
     "B_Slingload_01_Ammo_F",
     "B_Slingload_01_Fuel_F",
     "Box_EAF_AmmoVeh_F"],
    _searchRadius];

// Validate all required targets were found
if (isNull _repairPod || isNull _ammoPod || isNull _fuelPod || count _ammoBoxes < 1) exitWith {
    diag_log "[GROUND-FOB] ERROR: One or more target objects not found. Aborting.";
    { if (!isNull _x) then { deleteVehicle _x } } forEach _fobObjects;
    DYN_ground_active = false;
};

diag_log format [
    "[GROUND-FOB] Targets confirmed - Repair: %1  Ammo: %2  Fuel: %3  AmmoBoxes: %4",
    !isNull _repairPod, !isNull _ammoPod, !isNull _fuelPod, count _ammoBoxes
];

// =====================================================
// 4. SPAWN ENEMY GARRISON
// =====================================================
// Six infantry groups spread around the compound interior and perimeter
private _spawnZones = [
    [30,  10],   // Near gate - north approach
    [45,  80],   // East inner wall
    [45, 160],   // South courtyard
    [45, 250],   // West inner wall
    [20,  40],   // Deep interior NE (near slingloads)
    [25, 220],   // Deep interior SW (near ammo boxes)
];

private _infantryTypes = [
    "CUP_O_TK_Soldier_F",
    "CUP_O_TK_Soldier_SL_F",
    "CUP_O_TK_Soldier_Marksman_F",
    "CUP_O_TK_Soldier_MG_F",
    "CUP_O_TK_Soldier_RPG_F"
];

{
    private _dist = _x select 0;
    private _dir  = _x select 1;
    private _spawnPos = [_fobCenter, _dist, _dir] call DYN_fnc_posOffset;
    private _grpSize  = 4 + floor random 5;  // 4-8 per group
    private _grp = createGroup east;

    for "_i" from 1 to _grpSize do {
        private _unitPos = [_spawnPos, random 8, random 360] call DYN_fnc_posOffset;
        if (surfaceIsWater _unitPos) then { _unitPos = _spawnPos };

        private _unit = _grp createUnit [selectRandom _infantryTypes, _unitPos, [], 0, "NONE"];
        if (!isNull _unit) then {
            _unit allowFleeing 0.1;
            _unit setSkill ["aimingAccuracy", 0.40 + random 0.35];
            _unit setSkill ["aimingShake",    0.45 + random 0.30];
            _unit setSkill ["aimingSpeed",    0.45 + random 0.30];
            _unit setSkill ["spotDistance",   0.70 + random 0.30];
            _unit setSkill ["spotTime",       0.65 + random 0.30];
            _unit setSkill ["courage",        0.75 + random 0.25];
            DYN_ground_enemies pushBack _unit;
        };
    };

    if (units _grp isEqualTo []) then {
        deleteGroup _grp;
    } else {
        _grp setBehaviourStrong "AWARE";
        _grp setCombatMode "RED";
        _grp setSpeedMode "NORMAL";

        // Local patrol around spawn zone
        private _wp = _grp addWaypoint [_spawnPos, 35];
        _wp setWaypointType "PATROL";
        _wp setWaypointLoiterRadius 35;

        DYN_ground_enemyGroups pushBack _grp;
    };
} forEach _spawnZones;

// Two static MG posts near the FOB perimeter walls
private _mgPosts = [
    [60,  15],
    [65, 195],
];

{
    private _mgPos = [_fobCenter, _x select 0, _x select 1] call DYN_fnc_posOffset;
    private _mgGrp = createGroup east;

    private _gunner = _mgGrp createUnit ["CUP_O_TK_Soldier_MG_F", _mgPos, [], 0, "NONE"];
    if (!isNull _gunner) then {
        _gunner allowFleeing 0;
        _gunner setSkill 0.85;
        _gunner disableAI "PATH";
        DYN_ground_enemies pushBack _gunner;
    };

    if (units _mgGrp isEqualTo []) then {
        deleteGroup _mgGrp;
    } else {
        _mgGrp setBehaviourStrong "COMBAT";
        _mgGrp setCombatMode "RED";
        DYN_ground_enemyGroups pushBack _mgGrp;
    };
} forEach _mgPosts;

// Outer roving patrol - 1 group circling outside the walls
private _outerPatrolGrp = createGroup east;
private _outerPatrolSize = 4 + floor random 3;

for "_i" from 1 to _outerPatrolSize do {
    private _unitPos = [_fobCenter, 80 + random 30, random 360] call DYN_fnc_posOffset;
    if (surfaceIsWater _unitPos) then { _unitPos = _fobCenter };

    private _unit = _outerPatrolGrp createUnit [selectRandom _infantryTypes, _unitPos, [], 0, "NONE"];
    if (!isNull _unit) then {
        _unit allowFleeing 0.2;
        _unit setSkill 0.6;
        DYN_ground_enemies pushBack _unit;
    };
};

if (units _outerPatrolGrp isEqualTo []) then {
    deleteGroup _outerPatrolGrp;
} else {
    _outerPatrolGrp setBehaviourStrong "AWARE";
    _outerPatrolGrp setCombatMode "RED";
    _outerPatrolGrp setSpeedMode "NORMAL";

    private _wp = _outerPatrolGrp addWaypoint [_fobCenter, 90];
    _wp setWaypointType "PATROL";
    _wp setWaypointLoiterRadius 90;

    DYN_ground_enemyGroups pushBack _outerPatrolGrp;
};

diag_log format [
    "[GROUND-FOB] Garrison spawned: %1 groups, %2 infantry total.",
    count DYN_ground_enemyGroups,
    count DYN_ground_enemies
];

// Register FOB objects for global cleanup
{ DYN_ground_objects pushBack _x } forEach _fobObjects;

// =====================================================
// 5. MARKER AND TASK
// =====================================================
private _taskId = format ["ground_fob_%1", round (diag_tickTime * 1000)];

private _mkr = format ["ground_mkr_fob_%1", round (diag_tickTime * 1000)];
createMarker [_mkr, _fobCenter];
_mkr setMarkerShape "ELLIPSE";
_mkr setMarkerSize [_searchRadius * 0.6, _searchRadius * 0.6];
_mkr setMarkerColor "ColorRed";
_mkr setMarkerBrush "FDiagonal";
_mkr setMarkerAlpha 0.4;
_mkr setMarkerText "Enemy FOB";
DYN_ground_markers pushBack _mkr;

[
    west,
    _taskId,
    [
        "Intelligence has confirmed an active enemy Forward Operating Base. The FOB is heavily garrisoned and holds critical supply assets that are sustaining enemy operations in the region.<br/><br/><t color='#FF4444'>OBJECTIVES - destroy all of the following:</t><br/><br/>- Repair Pod (B_Slingload_01_Repair_F)<br/>- Ammunition Pod (B_Slingload_01_Ammo_F)<br/>- Fuel Pod (B_Slingload_01_Fuel_F)<br/>- Ammunition Vehicles (Box_EAF_AmmoVeh_F)<br/><br/>Expect a heavily armed garrison. All supply assets must be eliminated to complete the mission.",
        "FOB Hunting",
        ""
    ],
    _fobCenter,
    "CREATED",
    3,
    true,
    "destroy"
] remoteExec ["BIS_fnc_taskCreate", 0, _taskId];

DYN_ground_tasks pushBack _taskId;

diag_log format ["[GROUND-FOB] Mission active. FOB centre: %1", _fobCenter];

// =====================================================
// 6. COMPLETION MONITOR
// =====================================================
private _localEnemies  = +DYN_ground_enemies;
private _localGroups   = +DYN_ground_enemyGroups;
private _localObjects  = +DYN_ground_objects;
private _localMarkers  = +DYN_ground_markers;

[
    _taskId, _timeout, _cleanupDelay,
    _repairPod, _ammoPod, _fuelPod, _ammoBoxes,
    _repPerSlingload, _repPerAmmoBox,
    _localEnemies, _localGroups, _localObjects, _localMarkers
] spawn {
    params [
        "_tid", "_tOut", "_despawnDelay",
        "_repairPod", "_ammoPod", "_fuelPod", "_ammoBoxes",
        "_repPerSlingload", "_repPerAmmoBox",
        "_localEnemies", "_localGroups", "_localObjects", "_localMarkers"
    ];

    private _startTime   = diag_tickTime;
    private _repairDone  = false;
    private _ammoDone    = false;
    private _fuelDone    = false;
    private _ammoBoxDone = false;

    // Helper - vehicle considered destroyed at 90 % damage or when no longer alive
    private _isDead = { (damage _this >= 0.9) || { !alive _this } || { isNull _this } };

    waitUntil {
        sleep 5;

        // ---- Repair pod ----
        if (!_repairDone && (_repairPod call _isDead)) then {
            _repairDone = true;
            [_repPerSlingload, "Enemy Repair Pod Destroyed"] call DYN_fnc_changeReputation;
            diag_log format ["[GROUND-FOB] Repair pod destroyed. +%1 rep.", _repPerSlingload];
        };

        // ---- Ammo pod ----
        if (!_ammoDone && (_ammoPod call _isDead)) then {
            _ammoDone = true;
            [_repPerSlingload, "Enemy Ammo Pod Destroyed"] call DYN_fnc_changeReputation;
            diag_log format ["[GROUND-FOB] Ammo pod destroyed. +%1 rep.", _repPerSlingload];
        };

        // ---- Fuel pod ----
        if (!_fuelDone && (_fuelPod call _isDead)) then {
            _fuelDone = true;
            [_repPerSlingload, "Enemy Fuel Pod Destroyed"] call DYN_fnc_changeReputation;
            diag_log format ["[GROUND-FOB] Fuel pod destroyed. +%1 rep.", _repPerSlingload];
        };

        // ---- Ammo vehicles (all must be destroyed for the reward) ----
        if (!_ammoBoxDone) then {
            private _allGone = (_ammoBoxes findIf { !(_x call _isDead) }) isEqualTo -1;
            if (_allGone && { count _ammoBoxes > 0 }) then {
                _ammoBoxDone = true;
                private _boxRep = _repPerAmmoBox * count _ammoBoxes;
                [_boxRep, "Enemy Ammo Vehicles Destroyed"] call DYN_fnc_changeReputation;
                diag_log format ["[GROUND-FOB] All ammo vehicles destroyed. +%1 rep.", _boxRep];
            };
        };

        // ---- Completion check ----
        private _allDone = _repairDone && _ammoDone && _fuelDone && _ammoBoxDone;
        private _timedOut = (diag_tickTime - _startTime) > _tOut;

        _allDone || _timedOut
    };

    private _allDone = _repairDone && _ammoDone && _fuelDone && _ammoBoxDone;

    if (_allDone) then {
        [_tid, "SUCCEEDED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
        ["TaskSucceeded", [
            "FOB Hunting complete! All enemy supply assets have been destroyed.",
            "FOB Hunting"
        ]] remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-FOB] SUCCESS - all targets destroyed.";
    } else {
        [_tid, "FAILED", false] remoteExec ["BIS_fnc_taskSetState", 0, _tid];
        ["TaskFailed", [
            "FOB Hunting Failed",
            "Not all supply assets were destroyed before the deadline."
        ]] remoteExecCall ["BIS_fnc_showNotification", 0];
        diag_log "[GROUND-FOB] TIMED OUT - mission failed.";
    };

    { deleteMarker _x } forEach _localMarkers;
    DYN_ground_markers = DYN_ground_markers - _localMarkers;

    sleep 15;
    [_tid] remoteExec ["BIS_fnc_deleteTask", 0];
    [] remoteExec ["", 0, _tid];

    DYN_ground_active = false;

    diag_log format ["[GROUND-FOB] Despawning in %1 seconds.", _despawnDelay];
    sleep _despawnDelay;

    // Delete infantry and their groups
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localEnemies;
    { if (!isNull _x) then { deleteGroup _x } } forEach _localGroups;

    // Delete all FOB building objects
    { if (!isNull _x) then { deleteVehicle _x } } forEach _localObjects;

    DYN_ground_enemies     = DYN_ground_enemies     - _localEnemies;
    DYN_ground_enemyGroups = DYN_ground_enemyGroups - _localGroups;
    DYN_ground_objects     = DYN_ground_objects     - _localObjects;

    diag_log "[GROUND-FOB] Full cleanup complete.";
};

diag_log "[GROUND-FOB] FOB Hunting mission initialised successfully.";
