-- NAMESPACE: TotalQuestXP
local ADDON_NAME = "TotalQuestXP"
TotalQuestXP = {} 

local DEFAULT_BAR_WIDTH = 200
local DEFAULT_BAR_HEIGHT = 20

local defaults = {
    ["unlocked"] = false,
    ["includeSpeakQuests"] = true,
    ["showProjectedRewards"] = true,
    ["barWidth"] = DEFAULT_BAR_WIDTH,
    ["barHeight"] = DEFAULT_BAR_HEIGHT,
    ["barLeft"] = GetScreenWidth() / 2 - DEFAULT_BAR_WIDTH/2,
    ["barTop"] = -20,
}

-- STATE
local TotalQuestXPRoot = CreateFrame("Frame") -- Root frame
local totalQuestXpBar = CreateFrame("StatusBar", ADDON_NAME.."Statusbar", UIParent) 
local projectedRewards = {}
local previousProjectionsLeftOffset = 0
local missingXp = 0
local xpBarFull = false

-- REGISTER EVENT LISTENERS
TotalQuestXPRoot:RegisterEvent("ADDON_LOADED")
TotalQuestXPRoot:RegisterEvent("PLAYER_ENTERING_WORLD")
TotalQuestXPRoot:RegisterEvent("QUEST_LOG_UPDATE")
TotalQuestXPRoot:RegisterEvent("PLAYER_XP_UPDATE")
TotalQuestXPRoot:RegisterEvent("PLAYER_LOGIN")

TotalQuestXPRoot:SetScript("OnEvent", function(self, event, arg1, ...) TotalQuestXP:onEvent(self, event, arg1, ...) end);

function TotalQuestXP:onEvent(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then 
            TotalQuestXP:PrintHelp()
            TotalQuestXP:Init()
        end
    end

    if event == "QUEST_LOG_UPDATE" then
        TotalQuestXP:Update()
    end

    if event == "PLAYER_XP_UPDATE" then
        TotalQuestXP:Update()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        TotalQuestXP_Options.unlocked = false
        TotalQuestXP:Update()
    end

end

function TotalQuestXP:Init() 
    TotalQuestXP:LoadOptions()
    TotalQuestXP:Update()
end

function TotalQuestXP:LoadOptions()
    TotalQuestXP_Options = TotalQuestXP_Options or AddonUtils:deepcopy(defaults)

    for key,value in pairs(defaults) do
        if (TotalQuestXP_Options[key] == nil) then
            TotalQuestXP_Options[key] = value
        end
    end
end

function TotalQuestXP:Update() 
    -- UPDATE PRIMARY BAR
    TotalQuestXP:UpdateTotalQuestXpBar()

    -- GET REWARDS
    local questRewards = TotalQuestXP:GetQuestRewards()

    -- CALCULATE SUM
    local xpSum = TotalQuestXP:CalculateXPSum(questRewards) 

    -- DETERMINE PROJECTED REWARDS
    TotalQuestXP:RefreshProjectedRewards(questRewards, xpSum)

    -- DETERMINE WHETHER OR NOT ENOUGH XP HAS BEEN ACQUIRED
    if (xpSum >= TotalQuestXP:GetRemainingXP()) then
        local msg = "Turn in quests to DING!"

        totalQuestXpBar:SetValue(xpSum)
        totalQuestXpBar.value:SetText(msg)
        totalQuestXpBar:SetStatusBarColor(0, 0.80, 0)
    else
        totalQuestXpBar:SetValue(xpSum)
        totalQuestXpBar.value:SetText("Total XP Reward: "..string.format("%.0f", xpSum).."/"..TotalQuestXP:GetRemainingXP())
        totalQuestXpBar:SetStatusBarColor(0.80, 0, 0.80)
    end
end

function TotalQuestXP:RefreshProjectedRewards(questRewards, xpSum)
    previousProjectionsLeftOffset = 0
    missingXp = TotalQuestXP:GetRemainingXP() - xpSum

    for key,statusbar in pairs(projectedRewards) do
        projectedRewards[key]:Hide()
        projectedRewards[key]:SetUserPlaced(false)
        projectedRewards[key] = nil
    end

    if (TotalQuestXP_Options.showProjectedRewards and (not TotalQuestXP_Options.unlocked)) then
        for key,quest in pairs(questRewards) do
            if (quest.completed) then
                if (not projectedRewards[quest.title] == nil) then
                    projectedRewards[quest.title]:Hide()
                end
            else
                if (projectedRewards[quest.title] == nil) then
                    projectedRewards[quest.title] = TotalQuestXP:CreateStatusbarForProjectedQuest(quest, xpSum)
                end
            end
        end
    end

end

function TotalQuestXP:UpdateTotalQuestXpBar()
    -- POSITION, SIZE
    totalQuestXpBar:ClearAllPoints()
    totalQuestXpBar:SetWidth(TotalQuestXP_Options.barWidth)
    totalQuestXpBar:SetHeight(TotalQuestXP_Options.barHeight)
    totalQuestXpBar:SetPoint("TOPLEFT", TotalQuestXP_Options.barLeft, TotalQuestXP_Options.barTop)
    totalQuestXpBar:SetFrameLevel(1)

    -- DRAGGING
    totalQuestXpBar:SetScript("OnMouseDown", function(self, button) TotalQuestXP:onMouseDown(button); end)
    totalQuestXpBar:SetScript("OnMouseUp", function(self, button) TotalQuestXP:onMouseUp(button); end)
    totalQuestXpBar:SetMovable(true)
    totalQuestXpBar:SetResizable(true)
    totalQuestXpBar:EnableMouse(TotalQuestXP_Options.unlocked)
    totalQuestXpBar:SetClampedToScreen(true)

    -- VALUE
    totalQuestXpBar:SetMinMaxValues(0, TotalQuestXP:GetRequiredXP())

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
        totalQuestXpBar.bg:SetVertexColor(0.50, 0.50, 0.50)
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

    TotalQuestXP:UpdateFont()

    -- SET REMAINING XP
    totalQuestXpBar:SetMinMaxValues(0, TotalQuestXP:GetRemainingXP())

    totalQuestXpBar:Show()
end

function TotalQuestXP:CreateStatusbarForProjectedQuest(quest, xpSum)
    if (missingXp <= 0) then
        return nil
    end

    -- MAPPING MAXES
    local totalWidth = TotalQuestXP_Options.barWidth
    local projectionMax = TotalQuestXP:GetRemainingXP() - xpSum

    -- MAPPING PART
    local completedWidth = xpSum / TotalQuestXP:GetRemainingXP() * totalWidth
    local width = quest.reward / projectionMax * totalWidth - completedWidth
    local left = previousProjectionsLeftOffset + completedWidth
    local isLast = missingXp - quest.reward <= 0

    local statusbar = CreateFrame("StatusBar", ADDON_NAME..quest.title, totalQuestXpBar) 
    statusbar:SetMovable(true)
    statusbar:SetResizable(true)
    statusbar:SetUserPlaced(false)
    statusbar:SetClampedToScreen(true)
    statusbar:SetFrameLevel(1)

    statusbar:ClearAllPoints()
    statusbar:SetHeight(TotalQuestXP_Options.barHeight)

    if (isLast) then
        local missingXpWidth = missingXp / projectionMax * (totalWidth - completedWidth)
        statusbar:SetWidth(missingXpWidth)
        statusbar:SetPoint("TOPLEFT", totalQuestXpBar, left, 0)
    else
        statusbar:SetWidth(width)
        statusbar:SetPoint("TOPLEFT", totalQuestXpBar, left, 0)
    end

    -- VALUE
    statusbar:SetMinMaxValues(0, 1)
    statusbar:SetValue(1)

    -- FOREGROUND
    statusbar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    statusbar:GetStatusBarTexture():SetHorizTile(false)
    statusbar:GetStatusBarTexture():SetVertTile(false)
    statusbar:SetStatusBarColor(0, 1, 0, 0.4)

    statusbar:Show()

    previousProjectionsLeftOffset = previousProjectionsLeftOffset + width
    missingXp = missingXp - quest.reward

    return statusbar
end

-- GETTERS
function TotalQuestXP:GetQuestRewards()
    local questCount = GetNumQuestLogEntries()

    local rewards = {}

    for i = 1,questCount do
        SelectQuestLogEntry(i)

        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(i);
        local questDescription, questObjectives = GetQuestLogQuestText();

        if (not isHeader) then 
            local speakQuest = TotalQuestXP_Options.includeSpeakQuests and string.match(string.lower(questObjectives), "speak with")
            
            local quest = {
                title = title,
                reward = GetQuestLogRewardXP(),
                completed = isComplete == 1 or speakQuest
            }

            table.insert(rewards, quest)
        end

    end

    return rewards
end

function TotalQuestXP:CalculateXPSum(questRewards) 
    local xpSum = 0
    for key,quest in pairs(questRewards) do
        if (quest.completed) then
            xpSum = xpSum + quest.reward
        end
    end
    return xpSum
end

function TotalQuestXP:GetCurrentXP()
    return UnitXP("player")
end

function TotalQuestXP:GetRequiredXP()
    return UnitXPMax("player")
end

function TotalQuestXP:GetRemainingXP()
    return TotalQuestXP:GetRequiredXP() - TotalQuestXP:GetCurrentXP()
end

-- UI HELPERS

function TotalQuestXP:UpdateFont()
    local height = totalQuestXpBar:GetHeight()
    local remainder = AddonUtils:modulus(height, 2)
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

-- DRAG LISTENERS

function TotalQuestXP:onMouseDown(button)
    if button == "LeftButton" then
        totalQuestXpBar:StartMoving();
    elseif button == "RightButton" then
        totalQuestXpBar:StartSizing("BOTTOMRIGHT");
        totalQuestXpBar.resizing = 1
    end
end

function TotalQuestXP:onMouseUp()
    TotalQuestXP:UpdateFont()
    totalQuestXpBar:StopMovingOrSizing();

    TotalQuestXP_Options.barLeft = totalQuestXpBar:GetLeft()
    TotalQuestXP_Options.barTop = -1 * (GetScreenHeight() - totalQuestXpBar:GetTop())
    TotalQuestXP_Options.barWidth = totalQuestXpBar:GetWidth()
    TotalQuestXP_Options.barHeight = totalQuestXpBar:GetHeight()

    TotalQuestXP:Update()
    TotalQuestXP.OptionsPanelFrame:UpdateOptionValues()
end

-- COMMANDS

function TotalQuestXP:unlock()
    TotalQuestXP_Options.unlocked = true

    totalQuestXpBar:EnableMouse(true)

    for key,statusbar in pairs(projectedRewards) do
        statusbar:Hide()
    end
end

function TotalQuestXP:lock() 
    TotalQuestXP_Options.unlocked = false

    totalQuestXpBar:EnableMouse(false)
    totalQuestXpBar:StopMovingOrSizing();
    totalQuestXpBar.resizing = nil

    TotalQuestXP:Update()
end

function TotalQuestXP:reset()
    totalQuestXpBar:SetUserPlaced(false)
    TotalQuestXP_Options = AddonUtils:deepcopy(defaults)
    TotalQuestXP:Init()
end

function TotalQuestXP:PrintHelp() 
    print("# Total Quest XP")
    print("#    - /tqxp options      Opens the Addon page for the addon")
    print("#    - /tqxp unlock (U)   Unlock the frame and enable drag.")
    print("#                         - Hold LEFT mouse button (on the frame) to move.")
    print("#                         - Hold RIGHT mouse button (on the frame) to resize.")
    print("#    - /tqxp lock (L)     Lock the frame and disable drag.")
    print("#    - /tqxp reset        Resets all settings.")
    print("#    - /tqxp help         Print this help message.")
    print("# Source: https://github.com/smp4903/TotalQuestXP")
end
