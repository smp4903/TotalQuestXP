-- COMMANDS
SLASH_TQXP1 = '/tqxp'; 

function SlashCmdList.TQXP(msg, editbox)
    local cmd = msg:lower()

    if cmd == "options" then
        InterfaceOptionsFrame_OpenToCategory(TotalQuestXPRoot.optionsPanel)
    end

    if cmd == "unlock" or cmd == "u"  then
        print(ADDON_NAME.." - UNLOCKED.")
        TotalQuestXP:unlock()
    end

    if cmd == "lock" or cmd == "l" then
        print(ADDON_NAME.." - LOCKED.")
        TotalQuestXP:lock()
    end

    if cmd == "reset" then
        print(ADDON_NAME.." - RESET.")
        TotalQuestXP:reset()
    end

    if cmd == "" or cmd == "help" then
        TotalQuestXP:PrintHelp()
        InterfaceOptionsFrame_OpenToCategory(TotalQuestXPRoot.optionsPanel)
    end
end