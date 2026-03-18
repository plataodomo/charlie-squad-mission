// Export of 'FOB%20Hunting%2esqf.VR' by Domo on v0.9
////////////////////////////////////////////////////////////////////////////////////////////
// Init
params [["_layerWhiteList",[],[[]]],["_layerBlacklist",[],[[]]],["_posCenter",[0,0,0],[[]]],["_dir",0,[0]],["_idBlacklist",[],[[]]]];
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
////////////////////////////////////////////////////////////////////////////////////////////
// Inits
isNil {
};
////////////////////////////////////////////////////////////////////////////////////////////
[[_objects,_groups,_triggers,_waypoints,_logics,_markers],[_objectIDs,_groupIDs,_triggerIDs,_waypointIDs,_logicIDs,_markerIDs]]
