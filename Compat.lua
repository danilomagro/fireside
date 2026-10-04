local _, ns = ...

-- Forever (1.60.1 / interface 16001) runs the modern Mainline API: the Classic
-- globals GetItemInfo, GetSpellInfo, GetNumSkillLines and friends are gone.
-- Everything the addon needs goes through this file so a single edit fixes the
-- next build that moves a function again.
local API = {}
ns.API = API

local function firstOf(...)
    for i = 1, select("#", ...) do
        local fn = select(i, ...)
        if type(fn) == "function" then
            return fn
        end
    end
end

local getItemInfo = firstOf(C_Item and C_Item.GetItemInfo, GetItemInfo)
local getItemCount = firstOf(C_Item and C_Item.GetItemCount, GetItemCount)
local getItemIcon = firstOf(C_Item and C_Item.GetItemIconByID, GetItemIcon)
local getItemCooldown = firstOf(C_Item and C_Item.GetItemCooldown, GetItemCooldown)
local requestItemData = firstOf(C_Item and C_Item.RequestLoadItemDataByID)

function API.GetItemName(itemID)
    if not itemID or not getItemInfo then
        return nil
    end
    local ok, name = pcall(getItemInfo, itemID)
    if ok and name then
        return name
    end
    if requestItemData then
        pcall(requestItemData, itemID)
    end
    return nil
end

function API.GetItemIcon(itemID)
    if not itemID or not getItemIcon then
        return nil
    end
    local ok, icon = pcall(getItemIcon, itemID)
    return ok and icon or nil
end

function API.GetItemCount(itemID)
    if not itemID or not getItemCount then
        return 0
    end
    local ok, count = pcall(getItemCount, itemID)
    if not ok or type(count) ~= "number" then
        return 0
    end
    return count
end

-- Returns start, duration, enabled. Wrapped because some cooldown values can
-- come back as secret values that must not be compared or used in arithmetic.
function API.GetItemCooldown(itemID)
    if not itemID or not getItemCooldown then
        return nil
    end
    local ok, start, duration, enabled = pcall(getItemCooldown, itemID)
    if not ok then
        return nil
    end
    if ns.IsSecret(start) or ns.IsSecret(duration) then
        return nil
    end
    return start, duration, enabled
end

local getSpellInfo = firstOf(C_Spell and C_Spell.GetSpellInfo)
local getSpellIDForIdentifier = firstOf(C_Spell and C_Spell.GetSpellIDForSpellIdentifier)
local isSpellKnown = firstOf(IsSpellKnown, C_SpellBook and C_SpellBook.IsSpellKnown)
local isPlayerSpell = firstOf(IsPlayerSpell, C_SpellBook and C_SpellBook.IsSpellInSpellBook)

function API.GetSpellName(spellID)
    if not spellID then
        return nil
    end
    if getSpellInfo then
        local ok, info = pcall(getSpellInfo, spellID)
        if ok and type(info) == "table" then
            return info.name, info.iconID
        elseif ok and type(info) == "string" then
            return info -- very old signature, just in case
        end
    end
    return nil
end

function API.GetSpellIDByName(name)
    if not name or not getSpellIDForIdentifier then
        return nil
    end
    local ok, id = pcall(getSpellIDForIdentifier, name)
    return (ok and type(id) == "number") and id or nil
end

function API.IsSpellKnown(spellID)
    if not spellID then
        return false
    end
    for _, fn in ipairs({ isSpellKnown, isPlayerSpell }) do
        if fn then
            local ok, known = pcall(fn, spellID)
            if ok and known then
                return true
            end
        end
    end
    return false
end

-- True when the player has the "Campfire Nearby" buff, which is the only cue
-- the game gives that a campsite is in range. Aura reads can throw on secret
-- auras, so this never branches on anything it did not safely receive.
function API.HasCampfireNearby(auraName)
    local auraID = ns.Data and ns.Data.CAMPFIRE_AURA_ID
    if auraID and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
        if ok then
            return data ~= nil
        end
    end
    if not auraName then
        return nil
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, name = pcall(AuraUtil.FindAuraByName, auraName, "player", "HELPFUL")
        if ok then
            return name ~= nil
        end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", auraName, "HELPFUL")
        if ok then
            return data ~= nil
        end
    end
    return nil -- unknown: treat as "cannot tell", never as "no fire"
end

-- Professions the character actually has: a set of skill line ids, which are
-- the same in every client language, and a set of lowercased names as a
-- fallback for a client that does not report the skill line.
function API.GetKnownProfessions()
    local names, lines = {}, {}
    if not (GetProfessions and GetProfessionInfo) then
        return names, false, lines
    end
    local ok, a, b, arch, fishing, cooking, firstAid = pcall(GetProfessions)
    if not ok then
        return names, false, lines
    end
    for _, index in ipairs({ a, b, arch, fishing, cooking, firstAid }) do
        if index then
            local ok2, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, index)
            if ok2 and name then
                names[string.lower(name)] = true
            end
            if ok2 and type(skillLine) == "number" then
                lines[skillLine] = true
            end
        end
    end
    return names, true, lines
end

-- Whether a catalog entry belongs to one of the player's professions.
function API.HasProfession(entry, names, lines)
    if entry.skillLine and next(lines) then
        return lines[entry.skillLine] == true
    end
    return names[string.lower(entry.profession)] == true
end

-- The spell that opens each profession window. Casting the profession by name
-- does nothing on this client, so we read the real spell out of the profession
-- pages of the spellbook instead of guessing at names.
function API.GetProfessionSpells()
    if API._professionSpells then
        return API._professionSpells
    end

    local spells = {}
    API._professionSpells = spells

    if not (GetProfessions and GetProfessionInfo) then
        return spells
    end

    local ok, a, b, arch, fishing, cooking, firstAid = pcall(GetProfessions)
    if not ok then
        return spells
    end

    for _, index in ipairs({ a, b, arch, fishing, cooking, firstAid }) do
        if index then
            local okInfo, name, _, _, _, numSpells, spellOffset = pcall(GetProfessionInfo, index)
            if okInfo and name and numSpells and spellOffset then
                for slot = 1, numSpells do
                    local bookIndex = spellOffset + slot
                    local spellID, spellName = API.GetSpellBookSpell(bookIndex)
                    if spellID then
                        local record = spells[string.lower(name)]
                        if not record then
                            spells[string.lower(name)] = { spellID = spellID, name = spellName, profession = name }
                        end
                    end
                end
            end
        end
    end

    return spells
end

-- The whole player spellbook, name and id. GetProfessionInfo only reports
-- spells for some professions on this client, so the reliable way to find what
-- opens a profession window is to look at everything the character knows.
function API.DumpSpellBook(limit)
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local spells, seen = {}, {}

    local function add(index)
        local spellID, name = API.GetSpellBookSpell(index)
        if spellID and not seen[spellID] then
            seen[spellID] = true
            table.insert(spells, {
                index = index,
                spellID = spellID,
                name = name or API.GetSpellName(spellID),
            })
        end
    end

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo then
        local okLines, numLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        if okLines and numLines then
            for line = 1, numLines do
                local okLine, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
                if okLine and type(info) == "table" then
                    local offset = info.itemIndexOffset or 0
                    for slot = 1, (info.numSpellBookItems or 0) do
                        add(offset + slot)
                    end
                end
            end
        end
    end

    if #spells == 0 then
        for index = 1, (limit or 250) do
            add(index)
        end
    end

    return spells
end

function API.GetSpellBookSpell(index)
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
        if ok and type(info) == "table" then
            return info.spellID or info.actionID, info.name
        end
    end
    if GetSpellBookItemInfo then
        local ok, itemType, actionID = pcall(GetSpellBookItemInfo, index, "spell")
        if ok and actionID then
            return actionID, nil
        end
    end
    return nil
end

-- Secure action buttons fire on the edge this CVar picks: key down when it is
-- set (the Retail default), key up otherwise. Anything that reacts to the
-- same click has to pick the same edge, or it acts on a click the game ignored.
function API.UseKeyDown()
    local get = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
    if not get then
        return false
    end
    local ok, value = pcall(get, "ActionButtonUseKeyDown")
    return (ok and value) and true or false
end

function ns.IsSecret(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret
    end
    return false
end
