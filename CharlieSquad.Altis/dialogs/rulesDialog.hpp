// dialogs\rulesDialog.hpp
// SERVER RULES DIALOG — shown to every player on join

class DYN_RulesDialog {
    idd = 9700;
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[] spawn DYN_fnc_rulesDialogLoad;";
    onKeyDown = "if ((_this select 1) == 1) exitWith { true }; false";

    // ─── Layout reference ────────────────────────────────────────────────
    //  Dialog  : x=0.08  y=0.02  w=0.84  h=0.96   (0.08–0.92 / 0.02–0.98)
    //  HeaderBG: y=0.02  h=0.13  → bottom 0.15
    //  BottomBG: y=0.875 h=0.105 → bottom 0.98
    //  Cols    : y=0.155 h=0.710 → bottom 0.865
    //  LeftCol : x=0.095 w=0.395 → right  0.490
    //  Divider : x=0.499 w=0.002
    //  RightCol: x=0.510 w=0.395 → right  0.905
    // ─────────────────────────────────────────────────────────────────────

    class ControlsBackground {
        class MainBG {
            idc = -1; type = 0; style = 0;
            x = 0.08; y = 0.02; w = 0.84; h = 0.96;
            colorBackground[] = {0.09, 0.09, 0.09, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
        class HeaderBG {
            idc = -1; type = 0; style = 0;
            x = 0.08; y = 0.02; w = 0.84; h = 0.13;
            colorBackground[] = {0.20, 0.05, 0.05, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
        class BottomBG {
            idc = -1; type = 0; style = 0;
            x = 0.08; y = 0.875; w = 0.84; h = 0.105;
            colorBackground[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
        // Thin vertical divider between the two columns
        class ColDivider {
            idc = -1; type = 0; style = 0;
            x = 0.499; y = 0.158; w = 0.002; h = 0.704;
            colorBackground[] = {0.28, 0.28, 0.28, 1};
            colorText[] = {0,0,0,0}; text = "";
            font = "RobotoCondensed"; sizeEx = 0.03;
        };
    };

    class Controls {
        class HeaderTitle {
            idc = -1; type = 0; style = 2;
            x = 0.08; y = 0.032; w = 0.84; h = 0.056;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1.0, 0.84, 0.84, 1};
            text = "SERVER RULES";
            font = "RobotoCondensedBold"; sizeEx = 0.052; shadow = 2;
        };
        class SubTitle {
            idc = -1; type = 0; style = 2;
            x = 0.08; y = 0.091; w = 0.84; h = 0.030;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.58, 0.40, 0.40, 1};
            text = "Read carefully before playing. Violations may result in removal from the server.";
            font = "RobotoCondensed"; sizeEx = 0.028; shadow = 0;
        };

        // Left column — rules 1–6 — IDC 9701
        class RulesLeft {
            idc = 9701;
            type = 13;
            style = 0x10;
            text = "";
            size = 0.028;
            x = 0.095; y = 0.158; w = 0.395; h = 0.704;
            colorBackground[] = {0.09, 0.09, 0.09, 1};
            font = "RobotoCondensed"; sizeEx = 0.028;
            class VScrollbar {
                color[]         = {0.55, 0.55, 0.55, 0.50};
                colorActive[]   = {0.85, 0.85, 0.85, 0.90};
                colorDisabled[] = {0.35, 0.35, 0.35, 0.20};
                thumb      = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
                arrowFull  = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                border     = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
                scrollSpeed = 0.15;
                width  = 0.018;
                height = 0.018;
                autoScrollEnabled = false;
            };
        };

        // Right column — rules 7–12 — IDC 9702
        class RulesRight {
            idc = 9702;
            type = 13;
            style = 0x10;
            text = "";
            size = 0.028;
            x = 0.510; y = 0.158; w = 0.395; h = 0.704;
            colorBackground[] = {0.09, 0.09, 0.09, 1};
            font = "RobotoCondensed"; sizeEx = 0.028;
            class VScrollbar {
                color[]         = {0.55, 0.55, 0.55, 0.50};
                colorActive[]   = {0.85, 0.85, 0.85, 0.90};
                colorDisabled[] = {0.35, 0.35, 0.35, 0.20};
                thumb      = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
                arrowFull  = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                border     = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
                scrollSpeed = 0.15;
                width  = 0.018;
                height = 0.018;
                autoScrollEnabled = false;
            };
        };

        class AcknowledgeBtn {
            idc = -1;
            type = 1; style = 2;
            x = 0.31; y = 0.893; w = 0.38; h = 0.054;
            colorBackground[]         = {0.13, 0.27, 0.13, 1};
            colorBackgroundActive[]   = {0.20, 0.40, 0.20, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[]     = {0.70, 0.92, 0.70, 1};
            colorFocused[]  = {0.13, 0.27, 0.13, 1};
            colorBorder[]   = {0,0,0,0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[]   = {0,0,0,0};
            text = "I UNDERSTAND  —  ENTER SERVER";
            font = "RobotoCondensedBold"; sizeEx = 0.034;
            offsetX = 0; offsetY = 0; offsetPressedX = 0.001; offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[]  = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "closeDialog 0;";
        };
    };
};
