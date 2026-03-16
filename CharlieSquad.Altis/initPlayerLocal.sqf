/*
    initPlayerLocal.sqf
    Runs automatically on each player's machine when they join (including JIP).

    GPS JAMMER — MAP ICON FILTER
    ============================
    When the GPS jammer objective is active, this script hides the map icons
    of any friendly player standing inside the jammer zone so their position
    is not revealed to teammates looking at the map.

    REQUIREMENT: The server difficulty must have "Extended Map Info" disabled.
    Without it the engine draws its own native player icons on top of the map
    and no script can suppress them.

    On Nitrado:
      Web Panel > Settings > Basic Settings > Difficulty = Custom
      Then edit the difficulty profile and set mapContent = 0.

    How it works:
      - The server broadcasts DYN_jammerPos + DYN_jammerRadius via setVariable
        when the jammer spawns, and clears them when it is disabled.
      - This Draw handler fires every frame while the map is open and draws
        friendly player icons manually — skipping jammed players.
      - uiNamespace is used for the one-time flag so it stays client-local
        and is never synced across the network to other clients.
*/

// =====================================================
// SERVER RULES DIALOG — shown to every player on join
// =====================================================
[] spawn {
    waitUntil { !isNull player };
    sleep 5;
    // Wait for fn_rulesDialog.sqf to finish loading (init.sqf execVM)
    waitUntil { !isNil "DYN_fnc_rulesDialogLoad" };
    createDialog "DYN_RulesDialog";
};

// =====================================================
// GPS JAMMER — SELECTIVE MAP ICON DRAW
// =====================================================
[] spawn {
    waitUntil { !isNull player };

    // Cache the west player list every 5 s so the per-frame Draw handler
    // does not call allPlayers + side/group on every rendered frame.
    [] spawn {
        while {true} do {
            uiNamespace setVariable ["DYN_cachedWestPlayers", allPlayers select { side (group _x) == west }];
            sleep 5;
        };
    };

    // Add our Draw handler the first time the player opens the map.
    // The "Map" event fires each time the map opens (true) or closes (false).
    addMissionEventHandler ["Map", {
        params ["_isOpened"];
        if (!_isOpened) exitWith {};

        // uiNamespace is client-local — never synced to other machines,
        // so JIP players always set up their own handler on first open.
        if (uiNamespace getVariable ["DYN_mapDrawHandlerSet", false]) exitWith {};

        private _mapCtrl = (findDisplay 12) displayCtrl 51;
        if (isNull _mapCtrl) exitWith {};

        _mapCtrl ctrlAddEventHandler ["Draw", {
            params ["_map"];

            private _jamPos = missionNamespace getVariable ["DYN_jammerPos",    []];
            private _jamRad = missionNamespace getVariable ["DYN_jammerRadius",  0];
            private _jammed = (_jamPos isNotEqualTo []) && { _jamRad > 0 };

            {
                if (!alive _x) then { continue };

                // The local player can always see themselves on their own map.
                // Other players inside the jammer zone are hidden.
                if (_x != player && _jammed && { _x distance2D _jamPos < _jamRad }) then { continue };

                _map drawIcon [
                    "\A3\Ui_f\data\GUI\Cfg\Cursors\track_ca.paa",
                    [0.40, 0.70, 1.00, 1],
                    getPosVisual _x,
                    24, 24,
                    getDir _x,
                    name _x,
                    1, 0.035, "RobotoCondensed", "right"
                ];
            } forEach (uiNamespace getVariable ["DYN_cachedWestPlayers", []]);
        }];

        uiNamespace setVariable ["DYN_mapDrawHandlerSet", true];
        diag_log "[GPS-MAP] Map Draw handler installed — jammed player icons will be hidden.";
    }];
};
