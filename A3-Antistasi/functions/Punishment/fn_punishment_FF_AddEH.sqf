/*
Function:
	A3A_fnc_punishment_FF_addEH

Description:
	Adds EHs for Punishment FF check.
	This is the default entry point for the Punishment Module.
	Nothing else should be called from Antistasi.

Scope:
	<LOCAL> Execute on object you wish to assign the EH to.

Environment:
	<ANY>

Parameters:
	<OBJECT> The Object that the Event Handlers are being added to.

Returns:
	<BOOLEAN> true if it hasn't crashed; false if tkPunish is disabled or invalid params; nil if it has crashed.

Examples:
	if (hasInterface) then {
		[player] call A3A_fnc_punishment_FF_addEH; // Recommended to add to "onPlayerRespawn.sqf"
	};
	[cursorObject] remoteExec ["A3A_fnc_punishment_FF_addEH",cursorObject,false];

Author: Caleb Serafin
Date Updated: 12 June 2020
License: MIT License, Copyright (c) 2019 Barbolani & The Official AntiStasi Community
*/
params [["_unit",objNull,[objNull]]];
private _fileName = "fn_punishment_FF_addEH.sqf";

if (!tkPunish) exitWith {false};
if (!(_unit isKindOf "Man")) exitWith {
	[1,"No unit given",_fileName] remoteExecCall ["A3A_fnc_log",2,false];
	false;
};

_unit addEventHandler ["Killed", {
	params ["_unit", "_killer", "_instigator", "_useEffects"];
	if (!isPlayer _instigator && {!isPlayer _killer}) exitWith {}; // A certain company that develops a specific game called ArmaIII hasn't mastered the EH yet. So it's full objNull if a hippo crosses a stream when the day is divisible by the second fortnight of the month during a full moon on a warm summers day while the mosquitoes bit down on Richard Parker as he struggles during the October revolution.
	[[_instigator,_killer], 60, 0.4, _unit] remoteExec ["A3A_fnc_punishment_FF",[_killer,_instigator] select (isPlayer _instigator),false];
}];
_unit addEventHandler ["Hit", {
	params ["_unit", "_source", "_damage", "_instigator"];
	if (!isPlayer _instigator && {!isPlayer _source}) exitWith {};
	[[_instigator,_source], 60, 0.4, _unit] remoteExec ["A3A_fnc_punishment_FF",[_source,_instigator] select (isPlayer _instigator),false];
}];

if (!isPlayer _unit || !hasInterface) exitWith {true}; // Because it added killed handlers for Ai.
if !(_unit isEqualTo player) exitWith {false}; // Needs to be local for ace, self punishment, and checkStatus.

if (hasACE) then {
	["ace_firedPlayer", {
		params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile"];
		if (!isPlayer _unit) exitWith {};
		[_unit,_weapon,_projectile] call A3A_fnc_punishment_FF_checkNearHQ;
	}] call CBA_fnc_addEventHandler;
	["ace_explosives_place", {
		params ["_explosive","_dir","_pitch","_unit"];
		if (!isPlayer _unit) exitWith {};
		[_unit,"Put",_explosive] call A3A_fnc_punishment_FF_checkNearHQ;
	}] call CBA_fnc_addEventHandler;
} else {
	_unit addEventHandler ["Fired", {
		params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_gunner"];
		if (!isPlayer _unit) exitWith {};
		[_unit,_weapon,_projectile] call A3A_fnc_punishment_FF_checkNearHQ;
	}];
};

[getPlayerUID player] remoteExec ["A3A_fnc_punishment_checkStatus",2,false];
[3,format["Punishment Event Handlers Added to: %1",name _unit],_fileName] remoteExecCall ["A3A_fnc_log",2,false];
true;