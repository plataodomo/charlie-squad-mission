// dialogs\squadMenu.hpp
// GROUP MANAGEMENT - IMPROVED READABILITY

#define CT_STATIC           0
#define CT_BUTTON           1
#define CT_COMBO            4
#define CT_LISTNBOX         102

#define ST_LEFT             0x00
#define ST_CENTER           0x02
#define ST_RIGHT            0x01
#define ST_PICTURE          0x30

class DYN_SquadMenu {
    idd = 9500;
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[] spawn DYN_fnc_squadMenuInit";
    onUnload = "";
    
    class ControlsBackground {
        class MainBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.05; y = 0.06; w = 0.90; h = 0.88;
            colorBackground[] = {0.13, 0.13, 0.13, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class HeaderBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.05; y = 0.06; w = 0.90; h = 0.09;
            colorBackground[] = {0.17, 0.17, 0.17, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class LeftPanelBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.06; y = 0.16; w = 0.26; h = 0.665;
            colorBackground[] = {0.10, 0.10, 0.10, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class MiddlePanelBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.33; y = 0.16; w = 0.34; h = 0.665;
            colorBackground[] = {0.10, 0.10, 0.10, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class RightPanelBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.68; y = 0.16; w = 0.26; h = 0.665;
            colorBackground[] = {0.10, 0.10, 0.10, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class BottomBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.05; y = 0.835; w = 0.90; h = 0.105;
            colorBackground[] = {0.15, 0.15, 0.15, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
    };
    
    class Controls {
        class HeaderTitle {
            idc = 9599;
            type = CT_STATIC;
            style = ST_CENTER;
            x = 0.05; y = 0.075; w = 0.90; h = 0.06;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1, 1, 1, 1};
            text = "GROUP MANAGEMENT";
            font = "RobotoCondensedBold";
            sizeEx = 0.055;
            shadow = 2;
        };
        
        class CloseBtn {
            idc = -1;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.91; y = 0.085; w = 0.035; h = 0.045;
            colorBackground[] = {0.25, 0.25, 0.25, 1};
            colorBackgroundActive[] = {0.50, 0.30, 0.30, 1};
            colorBackgroundDisabled[] = {0.15, 0.15, 0.15, 1};
            colorText[] = {0.8, 0.8, 0.8, 1};
            colorFocused[] = {0.25, 0.25, 0.25, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.4, 0.4, 0.4, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "X";
            font = "RobotoCondensedBold";
            sizeEx = 0.04;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "closeDialog 0";
        };
        
        class LeftHeader {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.065; y = 0.165; w = 0.18; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.75, 0.75, 0.75, 1};
            text = "UNGROUPED";
            font = "RobotoCondensedBold";
            sizeEx = 0.030;
        };
        
        class UngroupedCount {
            idc = 9501;
            type = CT_STATIC;
            style = ST_RIGHT;
            x = 0.26; y = 0.165; w = 0.05; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.70, 0.70, 0.70, 1};
            text = "0";
            font = "RobotoCondensed";
            sizeEx = 0.028;
        };
        
        class UngroupedList {
            idc = 9502;
            type = CT_LISTNBOX;
            style = ST_LEFT;
            x = 0.065; y = 0.195; w = 0.25; h = 0.48;
            colorBackground[] = {0.07, 0.07, 0.07, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorDisabled[] = {0.4, 0.4, 0.4, 1};
            colorSelect[] = {1, 1, 1, 1};
            colorSelect2[] = {1, 1, 1, 1};
            colorSelectBackground[] = {0.28, 0.28, 0.28, 1};
            colorSelectBackground2[] = {0.25, 0.25, 0.25, 1};
            colorScrollbar[] = {0.3, 0.3, 0.3, 1};
            colorPicture[] = {1, 1, 1, 1};
            colorPictureSelected[] = {1, 1, 1, 1};
            colorPictureDisabled[] = {0.5, 0.5, 0.5, 1};
            colorPictureRight[] = {1, 1, 1, 1};
            colorPictureRightSelected[] = {1, 1, 1, 1};
            colorPictureRightDisabled[] = {0.5, 0.5, 0.5, 1};
            colorTextRight[] = {0.85, 0.85, 0.85, 1};
            colorSelectRight[] = {1, 1, 1, 1};
            colorSelect2Right[] = {1, 1, 1, 1};
            font = "RobotoCondensed";
            sizeEx = 0.030;
            rowHeight = 0.036;
            columns[] = {0.02, 0.14};
            drawSideArrows = 0;
            idcLeft = -1;
            idcRight = -1;
            maxHistoryDelay = 1;
            autoScrollSpeed = -1;
            autoScrollDelay = 5;
            autoScrollRewind = 0;
            arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
            arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
            border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
            soundSelect[] = {"", 0.1, 1};
            period = 0;
            shadow = 0;
            class ListScrollBar {
                color[] = {1, 1, 1, 0.6};
                colorActive[] = {1, 1, 1, 1};
                colorDisabled[] = {1, 1, 1, 0.3};
                thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
                arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            };
        };
        
        class InviteBtn {
            idc = 9530;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.065; y = 0.69; w = 0.25; h = 0.038;
            colorBackground[] = {0.20, 0.20, 0.20, 1};
            colorBackgroundActive[] = {0.32, 0.32, 0.32, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorFocused[] = {0.20, 0.20, 0.20, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "INVITE TO SQUAD";
            font = "RobotoCondensed";
            sizeEx = 0.028;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadInvite";
        };
        
        class MiddleHeader {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.335; y = 0.165; w = 0.18; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.75, 0.75, 0.75, 1};
            text = "SQUADS";
            font = "RobotoCondensedBold";
            sizeEx = 0.030;
        };
        
        class SquadCount {
            idc = 9510;
            type = CT_STATIC;
            style = ST_RIGHT;
            x = 0.61; y = 0.165; w = 0.05; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.70, 0.70, 0.70, 1};
            text = "0";
            font = "RobotoCondensed";
            sizeEx = 0.028;
        };
        
        class SquadsList {
            idc = 9511;
            type = CT_LISTNBOX;
            style = ST_LEFT;
            x = 0.335; y = 0.195; w = 0.33; h = 0.36;
            colorBackground[] = {0.07, 0.07, 0.07, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorDisabled[] = {0.4, 0.4, 0.4, 1};
            colorSelect[] = {1, 1, 1, 1};
            colorSelect2[] = {1, 1, 1, 1};
            colorSelectBackground[] = {0.28, 0.28, 0.28, 1};
            colorSelectBackground2[] = {0.25, 0.25, 0.25, 1};
            colorScrollbar[] = {0.3, 0.3, 0.3, 1};
            colorPicture[] = {1, 1, 1, 1};
            colorPictureSelected[] = {1, 1, 1, 1};
            colorPictureDisabled[] = {0.5, 0.5, 0.5, 1};
            colorPictureRight[] = {1, 1, 1, 1};
            colorPictureRightSelected[] = {1, 1, 1, 1};
            colorPictureRightDisabled[] = {0.5, 0.5, 0.5, 1};
            colorTextRight[] = {0.85, 0.85, 0.85, 1};
            colorSelectRight[] = {1, 1, 1, 1};
            colorSelect2Right[] = {1, 1, 1, 1};
            font = "RobotoCondensed";
            sizeEx = 0.029;
            rowHeight = 0.034;
            columns[] = {0.01, 0.06};
            drawSideArrows = 0;
            idcLeft = -1;
            idcRight = -1;
            maxHistoryDelay = 1;
            autoScrollSpeed = -1;
            autoScrollDelay = 5;
            autoScrollRewind = 0;
            arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
            arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
            border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
            soundSelect[] = {"", 0.1, 1};
            period = 0;
            shadow = 0;
            class ListScrollBar {
                color[] = {1, 1, 1, 0.6};
                colorActive[] = {1, 1, 1, 1};
                colorDisabled[] = {1, 1, 1, 0.3};
                thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
                arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            };
        };
        
        class JoinBtn {
            idc = 9532;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.335; y = 0.56; w = 0.33; h = 0.035;
            colorBackground[] = {0.20, 0.20, 0.20, 1};
            colorBackgroundActive[] = {0.32, 0.32, 0.32, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorFocused[] = {0.20, 0.20, 0.20, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "JOIN SQUAD";
            font = "RobotoCondensed";
            sizeEx = 0.027;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadJoin";
        };
        
        class CreateLabel {
            idc = 9540;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.335; y = 0.60; w = 0.15; h = 0.022;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.70, 0.70, 0.70, 1};
            text = "CREATE NEW SQUAD";
            font = "RobotoCondensedBold";
            sizeEx = 0.024;
        };
        
        class SquadNameCombo {
            idc = 9512;
            type = CT_COMBO;
            style = 0;
            x = 0.335; y = 0.625; w = 0.22; h = 0.032;
            colorBackground[] = {0.18, 0.18, 0.18, 1};
            colorSelectBackground[] = {0.30, 0.30, 0.30, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorDisabled[] = {0.4, 0.4, 0.4, 1};
            colorSelect[] = {1, 1, 1, 1};
            colorScrollbar[] = {0.3, 0.3, 0.3, 1};
            font = "RobotoCondensed";
            sizeEx = 0.028;
            wholeHeight = 0.32;
            rowHeight = 0.032;
            maxHistoryDelay = 1;
            arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
            arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
            border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
            soundSelect[] = {"\A3\ui_f\data\sound\RscCombo\soundSelect", 0.09, 1};
            soundExpand[] = {"\A3\ui_f\data\sound\RscCombo\soundExpand", 0.09, 1};
            soundCollapse[] = {"\A3\ui_f\data\sound\RscCombo\soundCollapse", 0.09, 1};
            class ComboScrollBar {
                color[] = {1, 1, 1, 0.6};
                colorActive[] = {1, 1, 1, 1};
                colorDisabled[] = {1, 1, 1, 0.3};
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
                thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
            };
        };
        
        class CreateBtn {
            idc = 9513;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.56; y = 0.625; w = 0.105; h = 0.032;
            colorBackground[] = {0.18, 0.28, 0.18, 1};
            colorBackgroundActive[] = {0.25, 0.38, 0.25, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.75, 0.92, 0.75, 1};
            colorFocused[] = {0.18, 0.28, 0.18, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "CREATE";
            font = "RobotoCondensed";
            sizeEx = 0.028;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadCreate";
        };
        
        class InviteNotification {
            idc = 9560;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.335; y = 0.665; w = 0.23; h = 0.024;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.85, 0.70, 0.45, 1};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.024;
        };
        
        class AcceptBtn {
            idc = 9561;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.57; y = 0.662; w = 0.046; h = 0.028;
            colorBackground[] = {0.18, 0.30, 0.18, 1};
            colorBackgroundActive[] = {0.25, 0.42, 0.25, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.75, 0.92, 0.75, 1};
            colorFocused[] = {0.18, 0.30, 0.18, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "YES";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadAcceptInvite";
        };
        
        class DeclineBtn {
            idc = 9562;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.619; y = 0.662; w = 0.046; h = 0.028;
            colorBackground[] = {0.30, 0.18, 0.18, 1};
            colorBackgroundActive[] = {0.45, 0.25, 0.25, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.92, 0.75, 0.75, 1};
            colorFocused[] = {0.30, 0.18, 0.18, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "NO";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadDeclineInvite";
        };
        
        class RightHeader {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.685; y = 0.165; w = 0.18; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.75, 0.75, 0.75, 1};
            text = "YOUR SQUAD";
            font = "RobotoCondensedBold";
            sizeEx = 0.030;
        };
        
        class YourSquadStatus {
            idc = 9521;
            type = CT_STATIC;
            style = ST_RIGHT;
            x = 0.85; y = 0.165; w = 0.08; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.55, 0.80, 0.55, 1};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.026;
        };
        
        class YourSquadBoxBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.685; y = 0.195; w = 0.25; h = 0.055;
            colorBackground[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class YourSquadName {
            idc = 9520;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.695; y = 0.210; w = 0.23; h = 0.04;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.95, 0.95, 0.95, 1};
            text = "NOT IN SQUAD";
            font = "RobotoCondensedBold";
            sizeEx = 0.038;
        };
        
        class LeaderBoxBG {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.685; y = 0.255; w = 0.25; h = 0.09;
            colorBackground[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0,0,0,0};
            text = "";
            font = "RobotoCondensed";
            sizeEx = 0.03;
        };
        
        class LeaderLabel {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.69; y = 0.26; w = 0.12; h = 0.022;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.70, 0.70, 0.70, 1};
            text = "SQUAD LEADER";
            font = "RobotoCondensedBold";
            sizeEx = 0.024;
        };
        
        class LeaderDisplay {
            idc = 9522;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.69; y = 0.28; w = 0.24; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.92, 0.92, 0.92, 1};
            text = "---";
            font = "RobotoCondensedBold";
            sizeEx = 0.032;
        };
        
        class ActingLabel {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.69; y = 0.305; w = 0.12; h = 0.022;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.70, 0.70, 0.70, 1};
            text = "ACTING LEADER";
            font = "RobotoCondensedBold";
            sizeEx = 0.024;
        };
        
        class ActingDisplay {
            idc = 9523;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.69; y = 0.325; w = 0.24; h = 0.028;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.92, 0.92, 0.92, 1};
            text = "---";
            font = "RobotoCondensedBold";
            sizeEx = 0.032;
        };
        
        class MembersLabel {
            idc = -1;
            type = CT_STATIC;
            style = ST_LEFT;
            x = 0.685; y = 0.35; w = 0.12; h = 0.024;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.75, 0.75, 0.75, 1};
            text = "MEMBERS";
            font = "RobotoCondensedBold";
            sizeEx = 0.026;
        };
        
        class MemberCount {
            idc = 9524;
            type = CT_STATIC;
            style = ST_RIGHT;
            x = 0.86; y = 0.35; w = 0.07; h = 0.024;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.70, 0.70, 0.70, 1};
            text = "0/11";
            font = "RobotoCondensed";
            sizeEx = 0.026;
        };
        
        class YourSquadList {
            idc = 9525;
            type = CT_LISTNBOX;
            style = ST_LEFT;
            x = 0.685; y = 0.375; w = 0.25; h = 0.22;
            colorBackground[] = {0.07, 0.07, 0.07, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorDisabled[] = {0.4, 0.4, 0.4, 1};
            colorSelect[] = {1, 1, 1, 1};
            colorSelect2[] = {1, 1, 1, 1};
            colorSelectBackground[] = {0.28, 0.28, 0.28, 1};
            colorSelectBackground2[] = {0.25, 0.25, 0.25, 1};
            colorScrollbar[] = {0.3, 0.3, 0.3, 1};
            colorPicture[] = {1, 1, 1, 1};
            colorPictureSelected[] = {1, 1, 1, 1};
            colorPictureDisabled[] = {0.5, 0.5, 0.5, 1};
            colorPictureRight[] = {1, 1, 1, 1};
            colorPictureRightSelected[] = {1, 1, 1, 1};
            colorPictureRightDisabled[] = {0.5, 0.5, 0.5, 1};
            colorTextRight[] = {0.85, 0.85, 0.85, 1};
            colorSelectRight[] = {1, 1, 1, 1};
            colorSelect2Right[] = {1, 1, 1, 1};
            font = "RobotoCondensed";
            sizeEx = 0.029;
            rowHeight = 0.034;
            columns[] = {0.02, 0.14};
            drawSideArrows = 0;
            idcLeft = -1;
            idcRight = -1;
            maxHistoryDelay = 1;
            autoScrollSpeed = -1;
            autoScrollDelay = 5;
            autoScrollRewind = 0;
            arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
            arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
            border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
            soundSelect[] = {"", 0.1, 1};
            period = 0;
            shadow = 0;
            class ListScrollBar {
                color[] = {1, 1, 1, 0.6};
                colorActive[] = {1, 1, 1, 1};
                colorDisabled[] = {1, 1, 1, 0.3};
                thumb = "\A3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
                arrowFull = "\A3\ui_f\data\gui\cfg\scrollbar\arrowFull_ca.paa";
                arrowEmpty = "\A3\ui_f\data\gui\cfg\scrollbar\arrowEmpty_ca.paa";
                border = "\A3\ui_f\data\gui\cfg\scrollbar\border_ca.paa";
            };
        };
        
        class PromoteBtn {
            idc = 9534;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.685; y = 0.60; w = 0.082; h = 0.033;
            colorBackground[] = {0.20, 0.20, 0.20, 1};
            colorBackgroundActive[] = {0.32, 0.32, 0.32, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorFocused[] = {0.20, 0.20, 0.20, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "PROMOTE";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadPromote";
        };
        
        class KickBtn {
            idc = 9535;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.77; y = 0.60; w = 0.082; h = 0.033;
            colorBackground[] = {0.30, 0.18, 0.18, 1};
            colorBackgroundActive[] = {0.45, 0.25, 0.25, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.90, 0.72, 0.72, 1};
            colorFocused[] = {0.30, 0.18, 0.18, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "KICK";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadKick";
        };
        
        class LockBtn {
            idc = 9514;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.855; y = 0.60; w = 0.082; h = 0.033;
            colorBackground[] = {0.20, 0.20, 0.20, 1};
            colorBackgroundActive[] = {0.32, 0.32, 0.32, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorFocused[] = {0.20, 0.20, 0.20, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "LOCK";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadToggleLock";
        };
        
        class LeaveBtn {
            idc = 9533;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.685; y = 0.638; w = 0.12; h = 0.033;
            colorBackground[] = {0.20, 0.20, 0.20, 1};
            colorBackgroundActive[] = {0.32, 0.32, 0.32, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.85, 0.85, 0.85, 1};
            colorFocused[] = {0.20, 0.20, 0.20, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "LEAVE";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadLeave";
        };
        
        class DisbandBtn {
            idc = 9536;
            type = CT_BUTTON;
            style = ST_CENTER;
            x = 0.81; y = 0.638; w = 0.125; h = 0.033;
            colorBackground[] = {0.30, 0.18, 0.18, 1};
            colorBackgroundActive[] = {0.45, 0.25, 0.25, 1};
            colorBackgroundDisabled[] = {0.12, 0.12, 0.12, 1};
            colorText[] = {0.85, 0.68, 0.68, 1};
            colorFocused[] = {0.30, 0.18, 0.18, 1};
            colorBorder[] = {0, 0, 0, 0};
            colorDisabled[] = {0.35, 0.35, 0.35, 1};
            colorShadow[] = {0, 0, 0, 0};
            text = "DISBAND";
            font = "RobotoCondensed";
            sizeEx = 0.024;
            offsetX = 0;
            offsetY = 0;
            offsetPressedX = 0.001;
            offsetPressedY = 0.001;
            borderSize = 0;
            soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick", 0.09, 1};
            soundEnter[] = {"", 0.1, 1};
            soundPush[] = {"", 0.1, 1};
            soundEscape[] = {"", 0.1, 1};
            action = "[] call DYN_fnc_squadDisband";
        };
        
        class KeyHint {
            idc = -1;
            type = CT_STATIC;
            style = ST_RIGHT;
            x = 0.80; y = 0.87; w = 0.14; h = 0.03;
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.50, 0.50, 0.50, 1};
            text = "Press U to close";
            font = "RobotoCondensed";
            sizeEx = 0.024;
        };
    };
};