/*
    scripts\reputation\fn_laptopAction.sqf
    UPDATED: Hint disappears after 10 seconds.
*/

params ["_laptop"];

if (isNull _laptop) exitWith {};

_laptop addAction [
    "<t color='#00FFFF'>Check Reputation Status</t>", 
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        
        // Spawn a thread to handle the display and timeout
        [] spawn {
            private _rep = missionNamespace getVariable ["DYN_Reputation", 0];
            private _status = "";
            private _color = "#FFFFFF";

            // Determine Status Text
            if (_rep >= 50) then { _status = "Heroic"; _color = "#00FF00"; };
            if (_rep >= 20 && _rep < 50) then { _status = "Respected"; _color = "#AAFF00"; };
            if (_rep >= 0 && _rep < 20) then { _status = "Neutral"; _color = "#FFFFFF"; };
            if (_rep < 0 && _rep > -20) then { _status = "Questionable"; _color = "#FFAA00"; };
            if (_rep <= -20) then { _status = "War Criminal"; _color = "#FF0000"; };

            private _txt = format [
                "<t size='1.5' color='#5555ff'>REPUTATION SYSTEM</t><br/><br/>" +
                "Current Score: <t size='1.2' color='%2'>%1</t><br/>" +
                "Status: <t size='1.2' color='%2'>%3</t><br/><br/>" +
                "Protect civilians and provide medical aid to increase standing.",
                _rep, _color, _status
            ];

            hint parseText _txt;
            
            // Wait 10 seconds then clear
            sleep 10;
            hintSilent "";
        };
    },
    nil,    // arguments
    1.5,    // priority
    true,   // showWindow
    true,   // hideOnUse
    "",     // shortcut
    "true", // condition
    5       // radius
];