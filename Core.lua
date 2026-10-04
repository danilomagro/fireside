local addonName, ns = ...

-- Chat output colors (AARRGGBB).
local COLOR_PREFIX = "|cffffd100" -- gold
local COLOR_ACCENT = "|cff69ccf0" -- light blue for commands and keywords
local COLOR_WARN = "|cffff8000"   -- orange for warnings
local COLOR_DEBUG = "|cff9d9d9d"  -- gray for debug output
local COLOR_RESET = "|r"

ns.addonName = addonName
ns.CHAT_PREFIX = COLOR_PREFIX .. "[Fireside]" .. COLOR_RESET .. " "

function ns.Print(msg)
    print(ns.CHAT_PREFIX .. tostring(msg))
end

function ns.PrintWarn(msg)
    print(ns.CHAT_PREFIX .. COLOR_WARN .. tostring(msg) .. COLOR_RESET)
end

function ns.Accent(text)
    return COLOR_ACCENT .. tostring(text) .. COLOR_RESET
end

ns.DEBUG = false
function ns.dprint(msg)
    if ns.DEBUG then
        print(ns.CHAT_PREFIX .. COLOR_DEBUG .. tostring(msg) .. COLOR_RESET)
    end
end

-- Registering an event the client does not know throws on the Forever beta and
-- aborts the rest of the file, so every registration goes through here.
function ns.SafeRegisterEvent(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then
        ns.dprint("event not available on this client: " .. tostring(event))
    end
    return ok
end

-- Defaults live here because the Forever beta client writes SavedVariables on
-- exit but never reads them back: every session starts from these values.
local DEFAULTS = {
    autoShow = false,      -- the panel opens from the minimap button, not by itself
    sound = true,          -- chime when you walk into a campsite's range
    soundPreset = 1,       -- index into ns.Minimap.SOUND_PRESETS
    showAll = false,       -- show objects from professions you do not have
    showUnknown = true,    -- show objects you have not learned yet, greyed out
    locked = false,
    debug = false,
    point = { "CENTER", "CENTER", 0, 120 },
}

local frame = CreateFrame("Frame")
ns.eventFrame = frame

local function InitDB()
    FiresideDB = FiresideDB or {}
    ns.db = FiresideDB
    ns.db.settings = ns.db.settings or {}
    for key, value in pairs(DEFAULTS) do
        if ns.db.settings[key] == nil then
            ns.db.settings[key] = value
        end
    end
    -- Harvested IDs go here; the client still writes the file on logout, so this
    -- is how we get real spell/item IDs out of the beta and into Data.lua.
    ns.db.harvest = ns.db.harvest or {}
    ns.DEBUG = ns.db.settings.debug and true or false
end

-- Copying errors out of the chat frame is painful on this client, so we keep
-- our own copy in the SavedVariables file. BugGrabber still gets everything:
-- the previous handler is always called.
local function InstallErrorRecorder()
    if ns._errorRecorderInstalled or not seterrorhandler then
        return
    end
    ns._errorRecorderInstalled = true

    local previous = geterrorhandler and geterrorhandler()
    seterrorhandler(function(err)
        if ns.db and type(err) == "string" then
            ns.db.errors = ns.db.errors or {}
            table.insert(ns.db.errors, {
                at = date("%Y-%m-%d %H:%M:%S"),
                message = err,
                mine = err:find(addonName, 1, true) ~= nil,
                stack = debugstack and debugstack(2, 6, 6) or nil,
            })
            while #ns.db.errors > 25 do
                table.remove(ns.db.errors, 1)
            end
        end
        if previous then
            return previous(err)
        end
    end)
end

local function PrintHelp()
    ns.Print(ns.Accent("/fire") .. " - toggle the camping panel")
    ns.Print(ns.Accent("/fire mats") .. " - list the materials you are missing")
    ns.Print(ns.Accent("/fire all") .. " - show every profession, not just yours")
    ns.Print(ns.Accent("/fire minimap on|off") .. " - show or hide the minimap button")
    ns.Print(ns.Accent("/fire sound on|off|<n>") .. " - chime when you reach a campfire, pick the sound")
    ns.Print(ns.Accent("/fire lock") .. " | " .. ns.Accent("/fire resetpos"))
    ns.Print(ns.Accent("/fire log on|off") .. " - record what Fireside sees, for bug reports")
    if ns.DEBUG then
        ns.Print(ns.Accent("/fire probe") .. " | " .. ns.Accent("/fire scan") .. " | " .. ns.Accent("/fire auras"))
    end
end

local function HandleSlash(msg)
    local trimmed = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = string.lower(trimmed):match("^(%S*)%s*(.*)$")

    if cmd == "" then
        ns.UI:Toggle()
    elseif cmd == "help" or cmd == "?" then
        PrintHelp()
    elseif cmd == "show" then
        ns.UI:Show()
    elseif cmd == "hide" then
        ns.UI:Hide()
    elseif cmd == "mats" then
        ns.State:PrintShoppingList()
    elseif cmd == "all" then
        ns.db.settings.showAll = not ns.db.settings.showAll
        ns.Print("Showing " .. ns.Accent(ns.db.settings.showAll and "every profession" or "your professions only"))
        ns.UI:Refresh()
    elseif cmd == "minimap" then
        if arg == "on" or arg == "off" then
            ns.Minimap:SetShown(arg == "on")
            ns.Print("Minimap button " .. ns.Accent(arg == "on" and "shown" or "hidden"))
        else
            ns.Print("Usage: " .. ns.Accent("/fire minimap on|off"))
        end
    elseif cmd == "sound" then
        local number = tonumber(arg)
        if arg == "on" or arg == "off" then
            ns.db.settings.sound = (arg == "on")
            ns.Print("Campfire chime " .. ns.Accent(arg))
            if arg == "on" then
                ns.Minimap:PlayChime(true) -- let you hear what you just turned on
            end
        elseif number then
            local kit, preset = ns.Minimap:ResolveSound(number)
            if not preset then
                ns.Print("No preset " .. number .. ".")
            elseif not kit then
                ns.PrintWarn("Preset " .. number .. " (" .. preset.label .. ") does not exist on this client.")
            else
                ns.db.settings.soundPreset = number
                ns.db.settings.sound = true
                ns.Print("Campfire chime: " .. ns.Accent(preset.label))
                ns.Minimap:PlayChime(true)
            end
        else
            ns.Print("Usage: " .. ns.Accent("/fire sound on|off") .. " or " .. ns.Accent("/fire sound <n>") .. " to pick and preview:")
            for index, preset in ipairs(ns.Minimap.SOUND_PRESETS) do
                local kit = ns.Minimap:ResolveSound(index)
                local current = (index == ns.db.settings.soundPreset) and " <" or ""
                ns.Print(("  %d  %s%s%s"):format(index, preset.label, kit and "" or " (missing)", current))
            end
        end
    elseif cmd == "auras" then
        ns.Auras:Print()
    elseif cmd == "scan" then
        ns.Probe:HarvestTradeSkill()
    elseif cmd == "probe" then
        ns.Probe:Run()
    elseif cmd == "lock" then
        ns.db.settings.locked = not ns.db.settings.locked
        ns.Print("Panel " .. ns.Accent(ns.db.settings.locked and "locked" or "unlocked"))
    elseif cmd == "resetpos" then
        ns.db.settings.point = { unpack(DEFAULTS.point) }
        ns.UI:ApplyPosition()
        ns.Minimap:ResetPosition()
        ns.Print("Panel and minimap button positions reset")
    elseif cmd == "log" or cmd == "debug" then
        -- One switch for bug reports: it records what Fireside sees (client
        -- API, every click, craft and placement, camp auras, Lua errors) into
        -- the SavedVariables file, which the game writes on /reload or logout.
        if arg == "on" or arg == "off" then
            ns.DEBUG = (arg == "on")
            ns.db.settings.debug = ns.DEBUG
            if ns.DEBUG then
                InstallErrorRecorder()
                ns.Probe:Capture()
                ns.Print("Logging " .. ns.Accent("on") .. ". Reproduce the problem, then type "
                    .. ns.Accent("/reload") .. " or log out, and send this file:")
                ns.Print("  " .. ns.Accent("WTF/Account/<your account>/SavedVariables/Fireside.lua"))
                ns.Print("It stays on until " .. ns.Accent("/fire log off") .. ".")
            else
                ns.Print("Logging " .. ns.Accent("off"))
            end
        else
            ns.Print("Logging is " .. ns.Accent(ns.DEBUG and "on" or "off") .. " - "
                .. ns.Accent("/fire log on|off") .. " to change it.")
        end
    else
        PrintHelp()
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then
            return
        end

        InitDB()
        if ns.DEBUG then
            InstallErrorRecorder()
        end
        ns.Data:Initialize()
        ns.UI:Initialize()
        ns.Minimap:Initialize()

        SLASH_FIRESIDE1 = "/fireside"
        SLASH_FIRESIDE2 = "/fire"
        SlashCmdList.FIRESIDE = HandleSlash

        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local version = getMeta and getMeta(addonName, "Version")
        if version and version:find("@", 1, true) then
            version = "dev" -- unpackaged copy: the packager fills in the tag
        end
        ns.Print(addonName .. " " .. (version and (ns.Accent("v" .. version) .. " ") or "") .. "loaded - " .. ns.Accent("/fire"))
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Item and spell data are not available yet at login.
        C_Timer.After(6, function()
            ns.Data:ResolveIDs(true)
            -- Developer harvesting only: nothing is written for normal users.
            if ns.DEBUG then
                ns.Auras:Snapshot("login")
                ns.Probe:Capture()
            end
        end)
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        ns.Probe:ScheduleHarvest()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- Protected calls do not raise a Lua error, they fire this: the only
        -- way to see which API this client refuses us.
        local blockedAddon, func = ...
        if ns.DEBUG and blockedAddon == addonName and ns.db then
            ns.db.blocked = ns.db.blocked or {}
            table.insert(ns.db.blocked, {
                at = date("%Y-%m-%d %H:%M:%S"),
                event = event,
                func = tostring(func),
                stack = debugstack and debugstack(2, 6, 6) or nil,
            })
            while #ns.db.blocked > 25 do
                table.remove(ns.db.blocked, 1)
            end
        end
        return
    elseif event == "PLAYER_LOGOUT" then
        if ns.DEBUG then
            ns.Probe:Capture() -- last state before the file is written to disk
        end
        return
    end

    ns.UI:OnEvent(event, ...)
end)

ns.SafeRegisterEvent(frame, "ADDON_LOADED")
ns.SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")
ns.SafeRegisterEvent(frame, "BAG_UPDATE_DELAYED")
ns.SafeRegisterEvent(frame, "SPELLS_CHANGED")
ns.SafeRegisterEvent(frame, "SKILL_LINES_CHANGED")
ns.SafeRegisterEvent(frame, "UNIT_AURA")
ns.SafeRegisterEvent(frame, "SPELL_UPDATE_COOLDOWN")
ns.SafeRegisterEvent(frame, "UNIT_SPELLCAST_SUCCEEDED")
ns.SafeRegisterEvent(frame, "UNIT_SPELLCAST_START")
ns.SafeRegisterEvent(frame, "TRADE_SKILL_SHOW")
ns.SafeRegisterEvent(frame, "TRADE_SKILL_LIST_UPDATE")
ns.SafeRegisterEvent(frame, "TRADE_SKILL_CLOSE")
ns.SafeRegisterEvent(frame, "PLAYER_REGEN_ENABLED")
ns.SafeRegisterEvent(frame, "PLAYER_LOGOUT")
ns.SafeRegisterEvent(frame, "ADDON_ACTION_BLOCKED")
ns.SafeRegisterEvent(frame, "ADDON_ACTION_FORBIDDEN")
