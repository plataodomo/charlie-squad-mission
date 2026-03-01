// fn_checkTFR.sqf
// Checks TFAR plugin and TeamSpeak connection status.
// Displays a blocking screen with blur if the player is not connected.
// Runs on clients only (guarded by hasInterface in init.sqf).

[] spawn {
    disableSerialization;
    _blurHandle = -1;

    // Wait until mission is fully loaded
    waitUntil {time > 0};

    while {true} do {
        // Check TFAR status (Beta version syntax)
        _pluginEnabled = [] call TFAR_fnc_isTeamSpeakPluginEnabled;
        _onServer = ["TaskForceRadio"] call TFAR_fnc_isTeamSpeakServerConnected;

        if (!_pluginEnabled || !_onServer) then {
            // Open the dialog if it is not already open
            if (isNull (findDisplay 9999)) then {
                createDialog "TFR_BlurScreen";

                // Block ESC key so the player cannot dismiss the screen
                (findDisplay 9999) displayAddEventHandler ["KeyDown", {
                    params ["_display", "_keyCode"];
                    if (_keyCode == 1) exitWith { true };
                }];

                // Activate blur effect
                if (_blurHandle == -1) then {
                    _blurHandle = ppEffectCreate ["DynamicBlur", 400];
                    _blurHandle ppEffectEnable true;
                    _blurHandle ppEffectAdjust [5];
                    _blurHandle ppEffectCommit 0.5;
                };
            };
        } else {
            // Player is correctly connected — close everything
            if (!isNull (findDisplay 9999)) then {
                closeDialog 9999;

                // Remove blur effect smoothly
                if (_blurHandle != -1) then {
                    _blurHandle ppEffectAdjust [0];
                    _blurHandle ppEffectCommit 0.5;
                    sleep 0.5;
                    ppEffectDestroy _blurHandle;
                    _blurHandle = -1;
                };
            };
        };

        // Check every 2 seconds to keep performance impact low
        sleep 2;
    };
};
