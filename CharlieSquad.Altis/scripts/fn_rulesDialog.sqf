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
        ["GENERAL CONDUCT", true],
        ["Treat all players with respect. No racism, harassment, or hate speech.", false],
        ["No griefing — do not intentionally ruin the experience for other players.", false],
        ["No cheating, exploiting, or using mods that give an unfair advantage.", false],
        ["English in side-chat so everyone can communicate.", false],
        ["Do not argue with admins in public chat. Raise disputes calmly and privately.", false],

        ["TEAMKILLING", true],
        ["Intentional teamkilling is an immediate ban — zero tolerance.", false],
        ["Accidental TKs must be acknowledged and apologized for in chat.", false],
        ["Friendly fire during an active engagement must be reported to your squad leader.", false],

        ["VEHICLES & ASSETS", true],
        ["Do not steal, destroy, or abandon friendly vehicles.", false],
        ["Return all vehicles to base when no longer in use. Abandoned vehicles may be deleted.", false],
        ["Jets and helicopters require competent piloting. Do not take high-value aircraft if you cannot fly them safely.", false],
        ["Destroyed shop vehicles are permanently lost — they cost squad reputation to replace, so use them wisely.", false],
        ["Do not block spawn points or vehicle pads.", false],

        ["COMBAT & OPERATIONS", true],
        ["Coordinate with your squad before attacking the main AO.", false],
        ["Do not fire weapons inside the base safe zone at any time.", false],
        ["Do not waste expensive assets on soft targets infantry can handle.", false],
        ["Follow squad leader orders during active operations. If you disagree, discuss it after the op.", false],

        ["REPUTATION SYSTEM", true],
        ["Reputation is earned by completing objectives and is shared across the server.", false],
        ["Admins may deduct reputation for rule violations without prior warning.", false],
        ["Do not exploit reputation mechanics, AO triggers, or mission scripts.", false],

        ["ADMIN & ENFORCEMENT", true],
        ["Admin decisions are final. Persistent disputes will result in removal.", false],
        ["Report rule violations to an admin — do not take matters into your own hands.", false],
        ["Bans are issued for: intentional TK, cheating, repeated conduct violations, or admin disrespect.", false]
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
