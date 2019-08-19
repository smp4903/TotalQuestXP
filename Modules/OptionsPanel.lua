-- CONFIGURE
local ADDON_NAME = "TotalQuestXP"
local NAMESPACE = TotalQuestXP

-- STATE
local frame = nil

-- LOADER
local OptionsPanelFrame = CreateFrame("Frame", ADDON_NAME.."OptionsPanelFrame")

-- EXPOSE OPTIONS PANEL TO NAMESPACE
NAMESPACE.OptionsPanelFrame = OptionsPanelFrame

OptionsPanelFrame:RegisterEvent("PLAYER_LOGIN")
OptionsPanelFrame:SetScript("OnEvent", 
    function(self, event, arg1, ...)
        if event == "PLAYER_LOGIN" then
            local loader = CreateFrame('Frame', nil, InterfaceOptionsFrame)
            loader:SetScript('OnShow', function(self)
                self:SetScript('OnShow', nil)

                if not OptionsPanelFrame.optionsPanel then
                    OptionsPanelFrame.optionsPanel = OptionsPanelFrame:CreateGUI(ADDON_NAME)
                    InterfaceOptions_AddCategory(OptionsPanelFrame.optionsPanel);
                end
            end)
        end
    end
);

-- LOADING VALUES

function OptionsPanelFrame:UpdateOptionValues()
    if (frame.content.includeSpeakQuests) then
        frame.content.includeSpeakQuests:SetChecked(TotalQuestXP_Options.includeSpeakQuests == true)
    end

    if (frame.content.showProjectedRewards) then
        frame.content.showProjectedRewards:SetChecked(TotalQuestXP_Options.showProjectedRewards == true)
    end

    if (frame.content.barWidth) then
        frame.content.barWidth:SetText(tostring(TotalQuestXP_Options.barWidth))
    end

    if (frame.content.barHeight) then
        frame.content.barHeight:SetText(tostring(TotalQuestXP_Options.barHeight))
    end

    if (frame.content.barWidth) then
        frame.content.barWidth:SetText(tostring(TotalQuestXP_Options.barWidth))
    end
end

-- GUI
function OptionsPanelFrame:CreateGUI(name, parent)
    if (not frame) then
        frame = CreateFrame("Frame", nil, InterfaceOptionsFrame)
    end
    
    frame:Hide()
    frame.parent = parent
    frame.name = name
 
    -- TITLE
    if (not frame.title) then
        local title = frame:CreateFontString(ADDON_NAME.."Title", "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 10, -15)
        title:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 10, -45)
        title:SetJustifyH("LEFT")
        title:SetJustifyV("TOP")
        title:SetText(name)
        frame.title = title
    end

    -- ROOT
    if (not frame.content) then
        local content = CreateFrame("Frame", "CADOptionsContent", frame)
        content:SetPoint("TOPLEFT", 10, -10)
        content:SetPoint("BOTTOMRIGHT", -10, 10)
        frame.content = content
    end

    -- INCLUDE "SPEAK WITH" QUESTS IN THE TOTAL REWARD
    local includeSpeakQuests = UIFactory:MakeCheckbox(ADDON_NAME.."SpeakQuests", frame.content, "Check to consider quests rewards from quests that direct you to talk to an NPC as completed.")
    includeSpeakQuests.label:SetText("Include SPEAK WITH rewards")
    includeSpeakQuests:SetPoint("TOPLEFT", 10, -30)
    includeSpeakQuests:SetScript("OnClick", function(self)
        TotalQuestXP_Options.includeSpeakQuests = self:GetChecked()
        TotalQuestXP:Update()
    end)
    frame.content.includeSpeakQuests = includeSpeakQuests

    -- INCLUDE "SPEAK WITH" QUESTS IN THE TOTAL REWARD
    local showProjectedRewards = UIFactory:MakeCheckbox(ADDON_NAME.."ProjectedRewards", frame.content, "Check to show a green bar that indicates the potential / projected / incomming XP rewards from your active (but not yet completed) quests.")
    showProjectedRewards.label:SetText("Show Projected XP Rewards")
    showProjectedRewards:SetPoint("TOPLEFT", 10, -60)
    showProjectedRewards:SetScript("OnClick", function(self)
        TotalQuestXP_Options.showProjectedRewards = self:GetChecked()
        TotalQuestXP:Update()
    end)
    frame.content.showProjectedRewards = showProjectedRewards

    -- BAR WIDTH
    local barWidth = UIFactory:MakeEditBox(ADDON_NAME.."BarWidth", frame.content, "Bar Width", 75, 25, function(self)
        TotalQuestXP_Options.barWidth = tonumber(self:GetText())
        TotalQuestXP:Update()
    end)
    barWidth:SetPoint("TOPLEFT", 250, -30)
    barWidth:SetCursorPosition(0)
    frame.content.barWidth = barWidth

    -- BAR HEIGHT
    local barHeight = UIFactory:MakeEditBox(ADDON_NAME.."BarHeight", frame.content, "Bar Height", 75, 25, function(self)
        TotalQuestXP_Options.barHeight = tonumber(self:GetText())
        TotalQuestXP:Update()
    end)
    barHeight:SetPoint("TOPLEFT", 400, -30)
    barHeight:SetCursorPosition(0)
    frame.content.barHeight = barHeight

    -- LOCK / UNLOCK BUTTON

    local function lockToggled(self)
        if (TotalQuestXP_Options.unlocked) then 
            TotalQuestXP:lock() 
            self:SetText("Unlock")
        else 
            TotalQuestXP:unlock() 
            self:SetText("Lock")
        end 
    end

    local toggleLockText = (TotalQuestXP_Options.unlocked and "Lock" or "Unlock")
    local toggleLock = UIFactory:MakeButton("LockButton", frame.content, 60, 20, toggleLockText, 14, UIFactory:MakeColor(1,1,1,1), lockToggled)
    toggleLock:SetPoint("TOPLEFT", 10, -120)
    frame.content.toggleLock = toggleLock

    -- RESET BUTTON
    local resetButton = UIFactory:MakeButton("ResetButton", frame.content, 60, 20, "Reset", 14, UIFactory:MakeColor(1,1,1,1), function(self) 
        if (TotalQuestXP_Options.unlocked) then
            lockToggled(toggleLock)
        end

        TotalQuestXP:reset()
    end)
    resetButton:SetPoint("TOPRIGHT", -30, -120)
    frame.content.resetButton = resetButton

    -- UPDATE VALUES ON SHOW
    frame:SetScript("OnShow", function(self) OptionsPanelFrame:UpdateOptionValues() end)

    return frame
end