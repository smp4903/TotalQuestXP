-- NAMESPACE: TotalQuestXP
local ADDON_NAME = "TotalQuestXP"
TotalQuestXP = {} 

local DEFAULT_BAR_WIDTH = 200
local DEFAULT_BAR_HEIGHT = 20

local defaults = {
    ["includeSpeakQuests"] = true,
    ["showProjectedRewards"] = true,
    ["barWidth"] = DEFAULT_BAR_WIDTH,
    ["barHeight"] = DEFAULT_BAR_HEIGHT,
    ["barLeft"] = GetScreenWidth() - 3*DEFAULT_BAR_WIDTH,
    ["barTop"] = 1 * (GetScreenHeight() / 2 + DEFAULT_BAR_HEIGHT / 2),
}

-- STATE
local TotalQuestXPRoot = CreateFrame("Frame") -- Root frame
local totalQuestXpBar = CreateFrame("StatusBar", "TotalQuestXP Statusbar", UIParent) 
local unlocked = false
local projectedRewards = {}
local previousProjectionsLeftOffset = 0

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
            PrintHelp()
            Init()
        end
    end

    if event == "PLAYER_LOGIN" then
        if not TotalQuestXPRoot.optionsPanel then
            TotalQuestXPRoot.optionsPanel = TotalQuestXPRoot:CreateGUI(ADDON_NAME)
            InterfaceOptions_AddCategory(TotalQuestXPRoot.optionsPanel);
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
    EvaluateQuestLog()
end

function LoadOptions()
    TotalQuestXP_Options = TotalQuestXP_Options or deepcopy(defaults)

    for key,value in pairs(defaults) do
        if (TotalQuestXP_Options[key] == nil) then
            TotalQuestXP_Options[key] = value
        end
    end
end

function CreateTotalQuestXpBar()

   -- POSITION, SIZE
   totalQuestXpBar:SetWidth(TotalQuestXP_Options.barWidth)
   totalQuestXpBar:SetHeight(TotalQuestXP_Options.barHeight)

   if (not totalQuestXpBar:IsUserPlaced()) then
    totalQuestXpBar:ClearAllPoints()
    totalQuestXpBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", TotalQuestXP_Options.barLeft, TotalQuestXP_Options.barTop)
   end
   
   totalQuestXpBar:SetFrameLevel(1)

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

    UpdateFont()

    totalQuestXpBar:Show()
end

function EvaluateQuestLog() 
    -- RESET PROJECTIONS
    for key,statusbar in pairs(projectedRewards) do
        projectedRewards[key]:Hide()
        projectedRewards[key]:SetUserPlaced(false)
        projectedRewards[key] = nil
    end

    -- RESET PROJECTION OFFSET
    previousProjectionsLeftOffset = 0

    -- SET REMAINING XP
    totalQuestXpBar:SetMinMaxValues(0, GetRemainingXP())

    -- GET REWARDS
    local rewards = GetQuestRewards()

    -- CALCULATE SUM
    local xpSum = 0
    for key,quest in pairs(rewards) do
        if (quest.completed) then
            xpSum = xpSum + quest.reward
        end
    end

    -- DETERMINE PROJECTED REWARDS
    if (TotalQuestXP_Options.showProjectedRewards) then
        for key,quest in pairs(rewards) do
            if (quest.completed) then
                if (not projectedRewards[quest.title] == nil) then
                    projectedRewards[quest.title]:Hide()
                end
            else
                if (projectedRewards[quest.title] == nil) then
                    projectedRewards[quest.title] = CreateStatusbarForProjectedQuest(quest, xpSum)
                end
            end
        end
    end

    -- DETERMINE WHETHER OR NOT ENOUGH XP HAS BEEN ACQUIRED
    if (xpSum >= GetRemainingXP()) then
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

function CreateStatusbarForProjectedQuest(quest, xpSum)
    local totalWidth = TotalQuestXP_Options.barWidth
    local remainingXp = GetRemainingXP()

    local width = quest.reward / remainingXp * totalWidth
    local left = previousProjectionsLeftOffset + xpSum / remainingXp * totalWidth
    local top = TotalQuestXP_Options.barTop

    local statusbar = CreateFrame("StatusBar", quest.title, totalQuestXpBar) 
    statusbar:ClearAllPoints()
    
    statusbar:SetMovable(true)
    statusbar:SetResizable(true)
    statusbar:SetUserPlaced(false)
    statusbar:SetClampedToScreen(true)

    statusbar:SetWidth(width)
    statusbar:SetHeight(TotalQuestXP_Options.barHeight)
    statusbar:SetPoint("TOPLEFT", totalQuestXpBar, left, 0)
    statusbar:SetFrameLevel(1)

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

    return statusbar
end

-- GETTERS
function GetQuestRewards()
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

function GetCurrentXP()
    return UnitXP("player")
end

function GetRequiredXP()
    return UnitXPMax("player")
end

function GetRemainingXP()
    return GetRequiredXP() - GetCurrentXP()
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

    TotalQuestXP_Options.barLeft = floor(totalQuestXpBar:GetLeft() + 0.5)
    TotalQuestXP_Options.barTop = floor(totalQuestXpBar:GetTop() + 0.5)

    EvaluateQuestLog()
end

-- HELPERS

function modulus(a,b)
    return a - math.floor(a/b)*b
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- COMMANDS

function unlock()
    unlocked = true

    totalQuestXpBar:EnableMouse(true)

    for key,statusbar in pairs(projectedRewards) do
        statusbar:Hide()
    end
end

function lock() 
    unlocked = false

    totalQuestXpBar:EnableMouse(false)
    totalQuestXpBar:StopMovingOrSizing();
    totalQuestXpBar.resizing = nil

    EvaluateQuestLog()
end

function reset()
    totalQuestXpBar:SetUserPlaced(false)
    TotalQuestXP_Options = deepcopy(defaults)
    Init()
end

function PrintHelp() 
    print("# Total Quest XP")
    print("#    - /tqxp options      Opens the Addon page for the addon")
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
    if msg == "options" then
        InterfaceOptionsFrame_OpenToCategory(TotalQuestXPRoot.optionsPanel)
    end
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

function UpdateOptionValues(content)
    content.includeSpeakQuests:SetChecked(TotalQuestXP_Options.includeSpeakQuests)
    
    content.barWidth:SetText(tostring(TotalQuestXP_Options.barWidth))
    content.barHeight:SetText(tostring(TotalQuestXP_Options.barHeight))
    
    content.barWidth:SetText(tostring(TotalQuestXP_Options.barWidth))
    content.barHeight:SetText(tostring(TotalQuestXP_Options.barHeight))
end

function TotalQuestXPRoot:CreateGUI(name, parent)
    local frame = CreateFrame("Frame", nil, InterfaceOptionsFrame)
    frame:Hide()

    frame.parent = parent
    frame.name = name
 
    -- TITLE
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetPoint("TOPLEFT", 10, -15)
	label:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 10, -45)
	label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(name)

    -- ROOT
	local content = CreateFrame("Frame", "CADOptionsContent", frame)
	content:SetPoint("TOPLEFT", 10, -10)
    content:SetPoint("BOTTOMRIGHT", -10, 10)

    frame.content = content

    -- INCLUDE "SPEAK WITH" QUESTS IN THE TOTAL REWARD
    local includeSpeakQuests = MakeCheckbox(nil, content, "Check to consider quests rewards from quests that direct you to talk to an NPC as completed.")
    includeSpeakQuests.label:SetText("Include SPEAK WITH rewards")
    includeSpeakQuests:SetPoint("TOPLEFT", 10, -30)
    content.includeSpeakQuests = includeSpeakQuests
    includeSpeakQuests:SetScript("OnClick", includeSpeakQuestsChecked)

    -- INCLUDE "SPEAK WITH" QUESTS IN THE TOTAL REWARD
    local showProjectedRewards = MakeCheckbox(nil, content, "Check to show a green bar that indicates the potential / projected / incomming XP rewards from your active (but not yet completed) quests.")
    showProjectedRewards.label:SetText("Show Projected XP Rewards")
    showProjectedRewards:SetPoint("TOPLEFT", 10, -60)
    content.showProjectedRewards = showProjectedRewards
    showProjectedRewards:SetScript("OnClick", showProjectedRewardsChecked)

    -- BAR WIDTH
    local barWidth = MakeEditBox(nil, content, "Bar Width", 75, 25, barWidthOnEnter)
    barWidth:SetPoint("TOPLEFT", 250, -30)
    barWidth:SetCursorPosition(0)
    content.barWidth = barWidth

    -- BAR HEIGHT
    local barHeight = MakeEditBox(nil, content, "Bar Height", 75, 25, barHeightOnEnter)
    barHeight:SetPoint("TOPLEFT", 400, -30)
    barHeight:SetCursorPosition(0)
    content.barHeight = barHeight

    -- LOCK / UNLOCK BUTTON
    local toggleLockText = (unlocked and "Lock" or "Unlock")
    local toggleLock = MakeButton("ResetButton", content, 60, 20, toggleLockText, 14, MakeColor(1,1,1,1), 
        function(self) 
            if (unlocked) then 
                lock() 
                self:SetText("Unlock")
            else 
                unlock() 
                self:SetText("Lock")
            end 
        end
    )
    toggleLock:SetPoint("TOPLEFT", 10, -120)
    content.toggleLock = toggleLock

    -- RESET BUTTON
    local resetButton = MakeButton("ResetButton", content, 60, 20, "Reset", 14, MakeColor(1,1,1,1), function(self) reset() end)
    resetButton:SetPoint("TOPRIGHT", -30, -120)
    content.resetButton = resetButton

    -- UPDATE VALUES ON SHOW
    frame:SetScript("OnShow", function(self) UpdateOptionValues(content) end)

    return frame
end

function includeSpeakQuestsChecked(self)
    TotalQuestXP_Options.includeSpeakQuests = self:GetChecked()
    Init()
end

function showProjectedRewardsChecked(self)
    TotalQuestXP_Options.showProjectedRewards = self:GetChecked()
    Init()
end

function barWidthOnEnter(self)
    TotalQuestXP_Options.barWidth = tonumber(self:GetText())
    Init()
end

function barHeightOnEnter(self)
    TotalQuestXP_Options.barHeight = tonumber(self:GetText())
    Init()
end

-- UI CREATORS

function MakeCheckbox(name, parent, tooltip_text)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetWidth(25)
    cb:SetHeight(25)
    cb:Show()

    local cblabel = cb:CreateFontString(nil, "OVERLAY")
    cblabel:SetFontObject("GameFontHighlight")
    cblabel:SetPoint("LEFT", cb,"RIGHT", 5,0)
    cb.label = cblabel

    cb.tooltip = tooltip_text

    return cb
end

function MakeText(parent, text, size)
    local text_obj = parent:CreateFontString(nil, "ARTWORK")
    text_obj:SetFont("Fonts/FRIZQT__.ttf", size)
    text_obj:SetJustifyV("CENTER")
    text_obj:SetJustifyH("CENTER")
    text_obj:SetText(text)
    return text_obj
end

function MakeEditBox(name, parent, title, w, h, enter_func)
    local edit_box_obj = CreateFrame("EditBox", name, parent)
    edit_box_obj.title_text = MakeText(edit_box_obj, title, 12)
    edit_box_obj.title_text:SetPoint("TOP", 0, 12)
    edit_box_obj:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 26,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4}
    })
    edit_box_obj:SetBackdropColor(0,0,0,1)
    edit_box_obj:SetSize(w, h)
    edit_box_obj:SetMultiLine(false)
    edit_box_obj:SetAutoFocus(false)
    edit_box_obj:SetMaxLetters(4)
    edit_box_obj:SetJustifyH("CENTER")
	edit_box_obj:SetJustifyV("CENTER")
    edit_box_obj:SetFontObject(GameFontNormal)
    edit_box_obj:SetScript("OnEnterPressed", function(self)
        enter_func(self)
        self:ClearFocus()
    end)
    edit_box_obj:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return edit_box_obj
end

function MakeColorPicker(name, parent, r, g, b, a, text, on_click_func)
    local color_picker = CreateFrame('Button', ADDON_NAME .. name, parent)
    color_picker:SetSize(15, 15)
    color_picker.normal = color_picker:CreateTexture(nil, 'BACKGROUND')
    color_picker.normal:SetColorTexture(1, 1, 1, 1)
    color_picker.normal:SetPoint('TOPLEFT', -1, 1)
    color_picker.normal:SetPoint('BOTTOMRIGHT', 1, -1)
    color_picker.foreground = color_picker:CreateTexture(nil, 'ARTWORK')
    color_picker.foreground:SetColorTexture(r, g, b, a)
    color_picker.foreground:SetAllPoints()
    color_picker:SetNormalTexture(color_picker.normal)
    color_picker:SetScript('OnClick', on_click_func)
    color_picker.text = addon_data.config.TextFactory(color_picker, text, 12)
    color_picker.text:SetPoint('LEFT', 25, 0)
    return color_picker
end

function MakeButton(name, parent, width, height, text, textSize, color, on_click_func)
    local button = CreateFrame('Button', ADDON_NAME .. name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    button:SetScript('OnClick', on_click_func)
    return button
end

function MakeColor(r,g,b,a) 
    return {r = r, g = g, b = b, a = a}
end