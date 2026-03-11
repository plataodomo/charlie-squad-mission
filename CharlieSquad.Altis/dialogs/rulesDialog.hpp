// dialogs\rulesDialog.hpp
// SERVER RULES DIALOG — shown to every player on join

class DYN_RulesDialog {
    idd = 9700;
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[] call DYN_fnc_rulesDialogLoad;";

    class ControlsBackground {
        class MainBG {
            idc = -1; type = 0; style = 0;
            x = 0.15; y = 0.05; w = 0.70; h = 0.90;
            colorBackground[] = {0.10, 0.10, 0.10, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
        class HeaderBG {
            idc = -1; type = 0; style = 0;
            x = 0.15; y = 0.05; w = 0.70; h = 0.11;
            colorBackground[] = {0.22, 0.06, 0.06, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
        class BottomBG {
            idc = -1; type = 0; style = 0;
            x = 0.15; y = 0.84; w = 0.70; h = 0.11;
            colorBackground[] = {0.13, 0.13, 0.13, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
    };

    class Controls {
        class HeaderTitle {
            idc = -1; type = 0; style = 2;
            x = 0.15; y = 0.062; w = 0.70; h = 0.055;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1.0, 0.85, 0.85, 1};
            text = "SERVER RULES";
            font = "RobotoCondensedBold"; sizeEx = 0.055; shadow = 2;
        };
        class SubTitle {
            idc = -1; type = 0; style = 2;
            x = 0.15; y = 0.118; w = 0.70; h = 0.026;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.65, 0.50, 0.50, 1};
            text = "Read carefully before playing. Violations may result in removal from the server.";
            font = "RobotoCondensed"; sizeEx = 0.023; shadow = 0;
        };
        // Scrollable structured text — IDC 9701
        class RulesText {
            idc = 9701;
            type = 13;
            x = 0.165; y = 0.155; w = 0.665; h = 0.670;
            colorBackground[] = {0.08, 0.08, 0.08, 1};
            font = "RobotoCondensed"; sizeEx = 0.028;
            class VScrollbar {
                color[] = {1, 1, 1, 0.45};
                colorActive[] = {1, 1, 1, 0.85};
                colorDisabled[] = {1, 1, 1, 0.2};
                thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
                arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
                scrollSpeed = 0.06;
                width = 0.018;
                height = 0.018;
                autoScrollEnabled = false;
            };
        };
        class AcknowledgeBtn {
            idc = -1;
            type = 1; style = 2;
            x = 0.33; y = 0.858; w = 0.34; h = 0.055;
            colorBackground[] = {0.14, 0.28, 0.14, 1};
            colorBackgroundActive[] = {0.22, 0.42, 0.22, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.72, 0.92, 0.72, 1};
            colorFocused[] = {0.14, 0.28, 0.14, 1};
            colorBorder[] = {0,0,0,0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0,0,0,0};
            text = "I UNDERSTAND  —  ENTER SERVER";
            font = "RobotoCondensedBold"; sizeEx = 0.036;
            offsetX = 0; offsetY = 0; offsetPressedX = 0.001; offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "closeDialog 0;";
        };
    };
};
