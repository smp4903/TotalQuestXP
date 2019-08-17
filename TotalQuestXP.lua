-- NAMESPACE: TotalQuestXP
local ADDON_NAME = "TotalQuestXP"
TotalQuestXP = {} 

local DEFAULT_BAR_WIDTH = 200
local DEFAULT_BAR_HEIGHT = 20

local defaults = {
    ["barWidth"] = DEFAULT_BAR_WIDTH,
    ["barHeight"] = DEFAULT_BAR_HEIGHT,
    ["barLeft"] = GetScreenWidth() - 3*DEFAULT_BAR_WIDTH,
    ["barTop"] = 1 * (GetScreenHeight() / 2 + DEFAULT_BAR_HEIGHT / 2),
}

local TotalQuestXPRoot = CreateFrame("Frame") -- Root frame
local totalQuestXpBar = CreateFrame("StatusBar", "TotalQuestXP Statusbar", UIParent) 

-- STATE
local unlocked = false

-- REGISTER EVENT LISTENERS
TotalQuestXPRoot:RegisterEvent("ADDON_LOADED")
TotalQuestXPRoot:RegisterEvent("PLAYER_ENTERING_WORLD")
TotalQuestXPRoot:RegisterEvent("QUEST_LOG_UPDATE")
TotalQuestXPRoot:RegisterEvent("PLAYER_XP_UPDATE")

TotalQuestXPRoot:SetScript("OnEvent", function(self, event, arg1, ...) TotalQuestXP:onEvent(self, event, arg1, ...) end);

function TotalQuestXP:onEvent(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then 
            PrintHelp()
            Init()
        end
    end

    if event == "QUEST_LOG_UPDATE" then
        EvaluateQuestLog()
    end

    if event == "PLAYER_XP_UPDATE" then
        EvaluateQuestLog()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        EvaluateQuestLog()
    end

end

function Init() 
    LoadOptions()
    CreateTotalQuestXpBar()
end

function LoadOptions()
    TotalQuestXP_Options = TotalQuestXP_Options or defaults

    for key,value in pairs(defaults) do
        if (TotalQuestXP_Options[key] == nil) then
            TotalQuestXP_Options[key] = value
        end
    end

    for key,value in pairs(defaults) do
        print("Default", key, value)
    end
end

function CreateTotalQuestXpBar()
   -- POSITION, SIZE
   totalQuestXpBar:ClearAllPoints()

   totalQuestXpBar:SetWidth(TotalQuestXP_Options.barWidth)
   totalQuestXpBar:SetHeight(TotalQuestXP_Options.barHeight)
   totalQuestXpBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", TotalQuestXP_Options.barLeft, TotalQuestXP_Options.barTop)

    -- DRAGGING
    totalQuestXpBar:SetScript("OnMouseDown", function(self, button) TotalQuestXP:onMouseDown(button); end)
    totalQuestXpBar:SetScript("OnMouseUp", function(self, button) TotalQuestXP:onMouseUp(button); end)
    totalQuestXpBar:SetMovable(true)
    totalQuestXpBar:SetResizable(true)
    totalQuestXpBar:EnableMouse(false)
    totalQuestXpBar:SetClampedToScreen(true)

    -- VALUE
    totalQuestXpBar:SetMinMaxValues(0, GetRequiredXP())

    -- FOREGROUND
    totalQuestXpBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    totalQuestXpBar:GetStatusBarTexture():SetHorizTile(false)
    totalQuestXpBar:GetStatusBarTexture():SetVertTile(false)
    totalQuestXpBar:SetStatusBarColor(0.80, 0, 0.80)

    -- BACKGROUND
    if (totalQuestXpBar.bg == nil) then
        totalQuestXpBar.bg = totalQuestXpBar:CreateTexture(nil, "BACKGROUND")
        totalQuestXpBar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        totalQuestXpBar.bg:SetAllPoints(true)
        totalQuestXpBar.bg:SetVertexColor(0.50, 0, 0.50)
        totalQuestXpBar.bg:SetAlpha(0.5)
    end

    -- TEXT
    if (totalQuestXpBar.value == nil) then
        totalQuestXpBar.value = totalQuestXpBar:CreateFontString(nil, "OVERLAY")
        totalQuestXpBar.value:SetPoint("LEFT", totalQuestXpBar, "LEFT", 4, 0)
        totalQuestXpBar.value:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        totalQuestXpBar.value:SetJustifyH("LEFT")
        totalQuestXpBar.value:SetShadowOffset(1, -1)
        totalQuestXpBar.value:SetTextColor(0.95, 0.95, 0.95)
    end

    UpdateFont()

    totalQuestXpBar:Show()
end

function EvaluateQuestLog() 
    totalQuestXpBar:SetMinMaxValues(0, GetRemainingXP())

    local xpSum = GetCompletedQuestXpSum()

    if (IsCompletedQuestXpSufficient()) then
        local msg = "Turn in quests to DING!"

        totalQuestXpBar:SetValue(xpSum)
        totalQuestXpBar.value:SetText(msg)
        totalQuestXpBar:SetStatusBarColor(0, 0.80, 0)
    else
        totalQuestXpBar:SetValue(xpSum)
        totalQuestXpBar.value:SetText("Total XP Reward: "..string.format("%.0f", xpSum).."/"..GetRemainingXP())
        totalQuestXpBar:SetStatusBarColor(0.80, 0, 0.80)
    end
end

-- GETTERS
function GetCompletedQuestXpSum()
    local questCount = GetNumQuestLogEntries()

    local xpSum = 0

    for i = 1,questCount do
        SelectQuestLogEntry(i)

        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(i);

        if (not isHeader and isComplete == 1) then 
            local xp = GetQuestLogRewardXP()
            xpSum = xpSum + xp
        end

    end

    return xpSum
end

function GetCurrentXP()
    return UnitXP("player")
end

function GetRequiredXP()
    return UnitXPMax("player")
end

function GetRemainingXP()
    return GetRequiredXP() - GetCurrentXP()
end

function IsCompletedQuestXpSufficient()
    return GetCompletedQuestXpSum() >= GetRemainingXP()
end

-- UI HELPERS

function UpdateFont()
    local height = totalQuestXpBar:GetHeight()
    local remainder = modulus(height, 2)
    local px = height - remainder - 10

    px = math.min(px, 12)
    px = math.max(px, 1)

    if (px < 8) then
        totalQuestXpBar.value:SetTextColor(0, 0, 0, 0)
    else
        totalQuestXpBar.value:SetTextColor(0.95, 0.95, 0.95)
    end

    totalQuestXpBar.value:SetFont("Fonts\\FRIZQT__.TTF", px, "OUTLINE")
end

function TotalQuestXP:onMouseDown(button)
    local shiftKey = IsShiftKeyDown()

    if button == "LeftButton" then
        totalQuestXpBar:StartMoving();
      elseif button == "RightButton" then
        totalQuestXpBar:StartSizing("BOTTOMRIGHT");
        totalQuestXpBar.resizing = 1
      end
end

function TotalQuestXP:onMouseUp()
    UpdateFont()
    totalQuestXpBar:StopMovingOrSizing();

    TotalQuestXP_Options.barLeft = totalQuestXpBar:GetLeft()
    TotalQuestXP_Options.barTop = totalQuestXpBar:GetTop()
end

-- MATH HELPERS

function modulus(a,b)
    return a - math.floor(a/b)*b
end

-- COMMANDS

function unlock()
    unlocked = true

    totalQuestXpBar:EnableMouse(true)
end

function lock() 
    unlocked = false

    totalQuestXpBar:EnableMouse(false)
    totalQuestXpBar:StopMovingOrSizing();
    totalQuestXpBar.resizing = nil
end

function reset()
    totalQuestXpBar:SetUserPlaced(false)
    FiveSecondRule_Options = defaults
    Init()
end

function PrintHelp() 
    print("# Total Quest XP")
    print("#    - /tqxp unlock (U)   Unlock the frame and enable drag.")
    print("#                         - Hold LEFT mouse button (on the frame) to move.")
    print("#                         - Hold RIGHT mouse button (on the frame) to resize.")
    print("#    - /tqxp lock (L)     Lock the frame and disable drag.")
    print("#    - /tqxp reset        Resets all settings.")
    print("#    - /tqxp help         Print this help message.")
    print("# Source: https://github.com/smp4903/five-second-rule")
end

SLASH_FSR1 = '/tqxp'; 
function SlashCmdList.FSR(msg, editbox)
     if msg == "unlock" or msg == "Unlock" or msg == "UNLOCK" or msg == "u" or msg == "U" then
         print(ADDON_NAME.." - UNLOCKED.")
         unlock()
      end
     if msg == "lock" or msg == "Lock" or msg == "LOCK" or msg == "l" or msg == "L"  then
        print(ADDON_NAME.." - LOCKED.")
        lock()
     end
     if msg == "reset" then
        print(ADDON_NAME.." - RESET.")
        reset()
     end
     if msg == "" or msg == "help" then
        PrintHelp()  
     end
end