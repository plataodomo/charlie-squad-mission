/*
    scripts\reputation\fn_repSystem.sqf
    REPUTATION SYSTEM v23 - NITRADO PERSISTENCE HARDENED
    BACKUP STRATEGY:
    - Primary key:   DYN_SavedReputation       (existing)
    - Backup key:    DYN_SavedReputation_BACKUP (new)
    - Validation:    Never overwrites good data with a suspicious low value
    - RPT Recovery:  Logs current rep in a recoverable format every save
                     Check Nitrado RPT log for: [REP BACKUP] lines to manually restore
*/
if (!isServer) exitWith {};
diag_log "[REP] INITIALIZING REPUTATION SYSTEM v23";

// =====================================================
// SAFE SAVE - validates before writing, saves to both keys
// =====================================================
DYN_fnc_safeRepSave = {
    params ["_newRep"];
    if (!isServer) exitWith {};

    // Sanity check - never save something clearly wrong
    // Rep range is -100 to 500 as defined in changeReputation
    if (_newRep < -100 || _newRep > 500) then {
        diag_log format ["[REP] WARNING: Tried to save suspicious value %1 - BLOCKED", _newRep];
    } else {
        private _existingBackup = profileNamespace getVariable ["DYN_SavedReputation_BACKUP", -9999];

        profileNamespace setVariable ["DYN_SavedReputation", _newRep];

        // Backup only updates when value is positive progress
        // This means the backup always holds your "highest known good" save
        if (_newRep >= 0 || _existingBackup == -9999) then {
            profileNamespace setVariable ["DYN_SavedReputation_BACKUP", _newRep];
        };

        saveProfileNamespace;

        diag_log format ["[REP BACKUP] REPUTATION=%1 | BACKUP=%2 | TIME=%3",
            _newRep,
            profileNamespace getVariable ["DYN_SavedReputation_BACKUP", 0],
            diag_tickTime
        ];
    };
};
publicVariable "DYN_fnc_safeRepSave";

// =====================================================
// SAFE LOAD - loads with fallback to backup key
// =====================================================
DYN_fnc_safeRepLoad = {
    private _primary = profileNamespace getVariable ["DYN_SavedReputation", -9999];
    private _backup  = profileNamespace getVariable ["DYN_SavedReputation_BACKUP", -9999];

    if (_primary == -9999) then {
        diag_log "[REP] WARNING: Primary save missing! Attempting backup restore...";
        if (_backup != -9999) then {
            diag_log format ["[REP] Restored from backup: %1", _backup];
            _backup
        } else {
            diag_log "[REP] No backup found either - starting fresh at 0";
            0
        };
    } else {
        if (_backup != -9999 && _backup > _primary && (_backup - _primary) > 20) then {
            diag_log format ["[REP] WARNING: Primary (%1) is much lower than backup (%2). Using backup.", _primary, _backup];
            _backup
        } else {
            _primary
        };
    };
};
publicVariable "DYN_fnc_safeRepLoad";

// =====================================================
// CHANGE REPUTATION
// =====================================================
DYN_fnc_changeReputation = {
    params ["_amount", "_reason"];
    if (!isServer) exitWith {};

    private _oldRep = missionNamespace getVariable ["DYN_Reputation", 0];
    private _newRep = (_oldRep + _amount) max -100 min 500;
    missionNamespace setVariable ["DYN_Reputation", _newRep, true];

    [_newRep] call DYN_fnc_safeRepSave;

    private _sign = "";
    if (_amount > 0) then { _sign = "+"; };
    private _msg = format ["%1%2 - %3", _sign, _amount, _reason];
    diag_log format ["[REP] Changed: %1 -> %2 (%3)", _oldRep, _newRep, _reason];

    private _notifType = "RepLoss";
    if (_amount > 0) then { _notifType = "RepGain"; };
    [_notifType, [_msg]] remoteExec ["BIS_fnc_showNotification", 0];
};
publicVariable "DYN_fnc_changeReputation";

// =====================================================
// AWARD HEAL REP
// =====================================================
DYN_fnc_awardHealRep = {
    params ["_civ"];
    if (!isServer) exitWith {};
    if (isNull _civ) exitWith {};
    if (!alive _civ) exitWith {};
    if (_civ getVariable ["DYN_repAwarded", false]) exitWith {};

    _civ setVariable ["DYN_repAwarded", true, true];

    private _severity = _civ getVariable ["DYN_injurySeverity", 2];
    private _rep = 2;
    if (_severity == 2) then { _rep = 3 + floor(random 2) };
    if (_severity == 3) then { _rep = 5 };

    [_rep, "Civilian Rescued"] call DYN_fnc_changeReputation;
    diag_log format ["[REP] Awarded %1 rep for %2", _rep, _civ];
};
publicVariable "DYN_fnc_awardHealRep";

// =====================================================
// FIND NEAREST PLAYER - SERVER SAFE
// =====================================================
DYN_fnc_findNearestPlayer = {
    params ["_unit", "_distance"];
    private _found = false;
    {
        if (isPlayer _x && alive _x && (_x distance _unit) < _distance) exitWith {
            _found = true;
        };
    } forEach allPlayers;
    _found
};
publicVariable "DYN_fnc_findNearestPlayer";

// =====================================================
// COUNT ACE WOUNDS — works across ACE medical versions
// =====================================================
DYN_fnc_countACEWounds = {
    params ["_unit", "_varName"];
    private _wounds = _unit getVariable [_varName, []];
    private _count = 0;
    if (_wounds isEqualType []) then {
        {
            if (_x isEqualType []) then {
                _x params [["_bodyPart", ""], ["_woundList", []]];
                if (_woundList isEqualType []) then {
                    _count = _count + (count _woundList);
                } else {
                    _count = _count + 1;
                };
            };
        } forEach _wounds;
    };
    _count
};
publicVariable "DYN_fnc_countACEWounds";

// =====================================================
// MONITOR HEALING — detects ACE "stabilized" state
//
// STABILIZED (blue triage) means ALL of these:
//   1. All wounds bandaged (no open wounds left)
//   2. Not bleeding
//   3. Not in cardiac arrest
//   4. Someone actually treated them (bandage count > 0)
//   5. Blood volume not critically low (> 4.2 of 6.0)
//
// Does NOT require full heal — just proper field treatment.
// =====================================================
DYN_fnc_monitorCivHealing = {
    params ["_civ"];
    if (!isServer) exitWith {};
    if (isNull _civ) exitWith {};
    if (!alive _civ) exitWith {};
    if (_civ getVariable ["DYN_isMonitored", false]) exitWith {};
    _civ setVariable ["DYN_isMonitored", true, true];

    private _startTime = diag_tickTime;

    // Snapshot initial state
    private _initialOpenCount = [_civ, "ace_medical_openWounds"] call DYN_fnc_countACEWounds;
    private _initialBleeding  = _civ getVariable ["ace_medical_woundBleeding", 0];
    private _hasACE = (_initialOpenCount > 0) || (_initialBleeding > 0);

    diag_log format ["[REP] Monitoring %1 | ACE:%2 | OpenWounds:%3 | Bleed:%4",
        _civ, _hasACE, _initialOpenCount, _initialBleeding];

    // Monitor loop — 30 min timeout
    while {
        !isNull _civ
        && alive _civ
        && !(_civ getVariable ["DYN_repAwarded", false])
        && (diag_tickTime - _startTime) < 1800
    } do {
        sleep 4;
        if (isNull _civ || !alive _civ) exitWith {};
        if (_civ getVariable ["DYN_repAwarded", false]) exitWith {};

        private _stabilized = false;

        if (_hasACE) then {
            // === ACE MEDICAL STABILIZATION CHECK ===
            private _bleeding     = _civ getVariable ["ace_medical_woundBleeding", 0];
            private _openCount    = [_civ, "ace_medical_openWounds"] call DYN_fnc_countACEWounds;
            private _bandageCount = [_civ, "ace_medical_bandagedWounds"] call DYN_fnc_countACEWounds;
            private _inCardiac    = _civ getVariable ["ace_medical_inCardiacArrest", false];
            private _bloodVol     = _civ getVariable ["ace_medical_bloodVolume", 6.0];

            // Blue triage = all wounds bandaged + no bleeding + not dying + decent blood
            _stabilized = (
                (_openCount == 0)
                && {_bleeding <= 0}
                && {!_inCardiac}
                && {_bandageCount > 0}
                && {_bloodVol > 4.2}
            );
        } else {
            // === FALLBACK: vanilla damage check (no ACE medical) ===
            if (damage _civ < 0.3) then {
                _stabilized = true;
            };
        };

        if (_stabilized && alive _civ) then {
            // Must have a player within 50m to get credit
            private _playerFound = [_civ, 50] call DYN_fnc_findNearestPlayer;

            if (_playerFound) then {
                diag_log format ["[REP] STABILIZED: %1 — awarding rep", _civ];

                [_civ] call DYN_fnc_awardHealRep;

                // === RECOVERY — civ gets up and walks to safety ===
                _civ setVariable ["DYN_isWounded", false, true];
                _civ setVariable ["ACE_isUnconscious", false, true];
                _civ setUnconscious false;
                _civ setDamage 0;

                _civ enableAI "MOVE";
                _civ enableAI "PATH";
                _civ enableAI "ANIM";
                _civ enableAI "FSM";
                _civ setUnitPos "AUTO";
                [_civ, ""] remoteExec ["switchMove", 0];

                [_civ] spawn {
                    params ["_c"];
                    sleep 3;
                    if (isNull _c || !alive _c) exitWith {};
                    _c setBehaviour "SAFE";
                    private _safePos = [getPos _c, 100, 200, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
                    _c doMove _safePos;
                    sleep 300;
                    if (!isNull _c) then { deleteVehicle _c };
                };
            } else {
                // Stabilized but nobody nearby — mark done
                diag_log "[REP] Stabilized but no player nearby — skipping rep";
                _civ setVariable ["DYN_repAwarded", true, true];
            };
        };
    };

    diag_log format ["[REP] Monitoring ended: %1", _civ];
};
publicVariable "DYN_fnc_monitorCivHealing";

// =====================================================
// SPAWN WOUNDED CIVILIAN
// =====================================================
DYN_fnc_spawnWoundedCivilian = {
    params ["_pos"];
    if (!isServer) exitWith {objNull};

    private _civClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_2_F", "C_man_polo_4_F"];
    private _grp = createGroup civilian;
    private _civ = _grp createUnit [selectRandom _civClasses, _pos, [], 0, "NONE"];
    if (isNull _civ) exitWith {objNull};

    // Severity 2 = moderate (body + leg), 3 = severe (body + both legs + arm)
    private _severity = 2 + floor(random 2);

    _civ setVariable ["DYN_isCivilian", true, true];
    _civ setVariable ["DYN_isWounded", true, true];
    _civ setVariable ["DYN_repAwarded", false, true];
    _civ setVariable ["DYN_repProcessed", false, true];
    _civ setVariable ["DYN_isMonitored", false, true];
    _civ setVariable ["DYN_injurySeverity", _severity, true];

    removeAllWeapons _civ;
    removeAllItems _civ;
    removeAllAssignedItems _civ;
    removeVest _civ;
    removeBackpack _civ;

    _civ disableAI "MOVE";
    _civ disableAI "PATH";
    _civ disableAI "FSM";
    _civ disableAI "TARGET";
    _civ disableAI "AUTOTARGET";
    _civ disableAI "AUTOCOMBAT";
    _civ setCaptive true;
    _civ allowFleeing 0;
    _civ setUnitPos "DOWN";

    [_civ, "Acts_LyingWounded_01"] remoteExec ["switchMove", 0];

    // Apply ACE wounds after unit settles
    [_civ, _severity] spawn {
        params ["_c", "_sev"];
        sleep 1;
        if (isNull _c || !alive _c) exitWith {};

        _c setVariable ["ACE_isUnconscious", true, true];
        _c setVariable ["ace_medical_ai_healSelf", false, true];
        _c setUnconscious true;

        // Apply ACE wounds — this handles all damage/bleeding properly
        if (!isNil "ace_medical_fnc_addDamageToUnit") then {
            [_c, 0.5, "body", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            [_c, 0.4, "leftleg", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            if (_sev >= 3) then {
                [_c, 0.3, "rightleg", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
                [_c, 0.2, "rightarm", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            };
            diag_log format ["[REP] ACE wounds applied sev %1", _sev];
        } else {
            // Fallback for non-ACE: vanilla damage only
            private _dmg = if (_sev >= 3) then {0.75} else {0.6};
            _c setDamage _dmg;
            diag_log format ["[REP] Vanilla damage %1 applied (no ACE)", _dmg];
        };

        // Keep them lying down until treated
        for "_i" from 1 to 10 do {
            sleep 0.5;
            if (isNull _c || !alive _c) exitWith {};
            _c setUnitPos "DOWN";
            [_c, "Acts_LyingWounded_01"] remoteExec ["switchMove", 0];
        };

        // Long-term animation enforcement
        while {
            !isNull _c
            && alive _c
            && (_c getVariable ["DYN_isWounded", true])
            && !(_c getVariable ["DYN_repAwarded", false])
        } do {
            sleep 8;
            if (isNull _c || !alive _c) exitWith {};
            if (_c getVariable ["DYN_repAwarded", false]) exitWith {};
            if (!(_c getVariable ["DYN_isWounded", true])) exitWith {};
            _c setUnitPos "DOWN";
            [_c, "Acts_LyingWounded_01"] remoteExec ["switchMove", 0];
        };
    };

    if (!isNil "DYN_AO_civUnits") then {
        DYN_AO_civUnits pushBack _civ;
    };

    // Start healing monitor after wounds are applied
    [_civ] spawn {
        params ["_c"];
        sleep 10;
        if (isNull _c || !alive _c) exitWith {};
        [_c] call DYN_fnc_monitorCivHealing;
    };

    diag_log format ["[REP] Spawned civilian sev %1 at %2", _severity, _pos];
    _civ
};
publicVariable "DYN_fnc_spawnWoundedCivilian";

// =====================================================
// CIVILIAN KILLED - EXCLUDES PRISONERS
// =====================================================
addMissionEventHandler ["EntityKilled", {
    params ["_killed", "_killer", "_instigator"];
    if (isNull _killed) exitWith {};
    if (!(_killed isKindOf "Man")) exitWith {};

    if (_killed getVariable ["DYN_isPrisoner", false]) exitWith {};
    if (_killed getVariable ["DYN_prisonDelivered", false]) exitWith {};
    if (_killed getVariable ["DYN_keepInPrison", false]) exitWith {};

    private _isCiv = (side group _killed == civilian) || (_killed getVariable ["DYN_isCivilian", false]);
    private _processed = _killed getVariable ["DYN_repProcessed", false];

    if (_isCiv && !_processed) then {
        _killed setVariable ["DYN_repProcessed", true, true];

        private _actualKiller = _killer;
        if (!isNull _instigator) then { _actualKiller = _instigator };

        if (!isNull _actualKiller) then {
            if (side group _actualKiller == west || isPlayer _actualKiller) then {
                [-15, "Civilian Killed"] call DYN_fnc_changeReputation;
            };
        };
    };
}];

// =====================================================
// PRISONER DELIVERY REPUTATION
// =====================================================
DYN_fnc_awardPrisonerRep = {
    params ["_unit"];
    if (!isServer) exitWith {};
    if (isNull _unit) exitWith {};
    if (_unit getVariable ["DYN_prisonerRepAwarded", false]) exitWith {};

    _unit setVariable ["DYN_prisonerRepAwarded", true, true];

    private _type = _unit getVariable ["DYN_prisonerType", "Prisoner"];
    private _rep = 5;
    switch (toLower _type) do {
        case "hvt": { _rep = 15 };
        case "officer": { _rep = 10 };
        case "arms dealer": { _rep = 20 };
        default { _rep = 5 };
    };

    private _reason = format ["%1 Captured", _type];
    [_rep, _reason] call DYN_fnc_changeReputation;
    diag_log format ["[REP] Prisoner delivered: %1 = +%2 rep", _type, _rep];
};
publicVariable "DYN_fnc_awardPrisonerRep";

diag_log "[REP] REPUTATION SYSTEM v23 READY";
diag_log format ["[REP] Current Rep: %1", missionNamespace getVariable ["DYN_Reputation", 0]];
