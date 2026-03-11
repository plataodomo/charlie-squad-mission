/*
    scripts\fn_rulesDialog.sqf
    SERVER RULES DIALOG — runs on each client, defines the populate function
    called by DYN_RulesDialog's onLoad event.

    -----------------------------------------------------------------------
    HOW TO EDIT YOUR RULES
    -----------------------------------------------------------------------
    Each entry in _rules is an array:  ["Text", isHeader]

      isHeader = true  → bold gold section heading
      isHeader = false → bullet-point rule underneath it

    Add, remove, or reorder entries freely. The dialog scrolls automatically
    if the content is taller than the text area.
    -----------------------------------------------------------------------
*/

DYN_fnc_rulesDialogLoad = {

    // ====================================================================
    //  YOUR SERVER RULES — EDIT THIS ARRAY
    // ====================================================================
    private _rules = [
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
        ["The use of explosives or explosive ammunition inside the base is strictly forbidden (except when engaging enemies).", false],

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

        ["TEAMPLAY FIRST", true],
        ["Teamwork is the top priority. Admins may kick players who refuse to cooperate with the team, as unnecessary respawning disrupts medic gameplay.", false]
    ];
    // ====================================================================

    // Build scrollable structured text from the rules array
    private _txt = "<t color='#111111' size='0.1'> </t>";  // top padding
    {
        _x params ["_text", "_isHeader"];
        if (_isHeader) then {
            _txt = _txt + format ["<br/><t color='#DDAA44' size='1.1' font='RobotoCondensedBold'>  %1</t><br/>", _text];
            _txt = _txt + "<t color='#4A2E1A'>  ──────────────────────────────────────</t><br/>";
        } else {
            _txt = _txt + format ["<t color='#BBBBBB'>     •  %1</t><br/>", _text];
        };
    } forEach _rules;

    private _ctrl = (findDisplay 9700) displayCtrl 9701;
    _ctrl ctrlSetStructuredText parseText _txt;
};
