-- COMMANDS
SLASH_TQXP1 = '/tqxp'; 

function SlashCmdList.TQXP(msg, editbox)
    local cmd = msg:lower()

    if cmd == "options" then
        InterfaceOptionsFrame_OpenToCategory(TotalQuestXPRoot.optionsPanel)
    end

    if cmd == "unlock" or cmd == "u"  then
        print(ADDON_NAME.." - UNLOCKED.")
        unlock()
    end

    if cmd == "lock" or cmd == "l" then
        print(ADDON_NAME.." - LOCKED.")
        lock()
    end

    if cmd == "reset" then
        print(ADDON_NAME.." - RESET.")
        reset()
    end

    if cmd == "" or cmd == "help" then
        PrintHelp()  
    end
end