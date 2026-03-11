/*
    scripts\fn_rulesDialog.sqf
    SERVER RULES DIALOG — runs on each client, called by DYN_RulesDialog's onLoad event.

    -----------------------------------------------------------------------
    HOW TO EDIT YOUR RULES
    -----------------------------------------------------------------------
    _rulesLeft  → shown in the LEFT  column (rules 1–6)
    _rulesRight → shown in the RIGHT column (rules 7–12)

    Each entry: ["Text", isHeader]
      isHeader = true  → gold bold section heading
      isHeader = false → rule description underneath it

    Keep each column roughly balanced in length for a clean look.
    -----------------------------------------------------------------------
*/

DYN_fnc_rulesDialogLoad = {

    // ====================================================================
    //  LEFT COLUMN — rules 1 to 6
    // ====================================================================
    private _rulesLeft = [
        ["RESPECT EACH OTHER", true],
        ["Treat all players with respect. Toxic behavior, insults, or harassment will not be tolerated.", false],

        ["NO EXPLOITING", true],
        ["Exploiting bugs, glitches, or game mechanics to gain an unfair advantage is strictly prohibited.", false],

        ["DYNAMIC OBJECTS", true],
        ["The unnecessary placement of dynamic objects (e.g. trenches) is not allowed.", false],

        ["COMMUNICATION", true],
        ["When 4 or more players are online, communication must take place via TeamSpeak using TFAR.", false],

        ["HELICOPTER USAGE", true],
        ["After using a helicopter, it must either be destroyed or marked on the map and returned to base after the mission is completed.", false],

        ["NO EXPLOSIVES IN BASE", true],
        ["The use of explosives or explosive ammunition inside the base is strictly forbidden (except when engaging enemies).", false]
    ];

    // ====================================================================
    //  RIGHT COLUMN — rules 7 to 12
    // ====================================================================
    private _rulesRight = [
        ["PURCHASED ASSETS", true],
        ["Assets bought with points must be returned to base if they were not destroyed.", false],

        ["NO FRIENDLY FIRE", true],
        ["Friendly fire is not allowed. Mutual agreement between players is the only exception.", false],

        ["ARSENAL CLEANLINESS", true],
        ["Do not leave inventory items lying around in the arsenal building.", false],

        ["ARTILLERY USAGE", true],
        ["Firing artillery at friendly units without request is prohibited.", false],

        ["AIR SUPPORT RULES", true],
        ["Jets may only engage targets they were requested for.", false],
        ["Attack helicopters are exempt but must report the targets they are engaging.", false],

        ["TEAM PLAY FIRST", true],
        ["Teamwork is the top priority. Admins may kick players who refuse to cooperate with the team, as unnecessary respawning disrupts medic gameplay.", false]
    ];
    // ====================================================================

    // Build structured text from a rules array.
    // NOTE: All text uses size='1.0' (the control's base size = 0.028).
    //       Never use fractional sizes — they cause pixelation in Arma 3.
    private _fnBuild = {
        params ["_rules"];
        private _txt = "";
        {
            if (_x select 1) then {
                // Blank line before each header (except the very first entry)
                if (_txt != "") then { _txt = _txt + "<br/>"; };
                _txt = _txt + format [
                    "<t color='#E0A830' font='RobotoCondensedBold'>  %1</t><br/>",
                    (_x select 0)
                ];
            } else {
                _txt = _txt + format [
                    "<t color='#BEBEBE'>  • %1</t><br/>",
                    (_x select 0)
                ];
            };
        } forEach _rules;
        _txt
    };

    private _display = findDisplay 9700;
    (_display displayCtrl 9701) ctrlSetStructuredText parseText ([_rulesLeft]  call _fnBuild);
    (_display displayCtrl 9702) ctrlSetStructuredText parseText ([_rulesRight] call _fnBuild);
};
