local _, ns = ...

ns.State = ns.State or {}
local State = ns.State

-- What a single camping object can do for you right now.
-- status is one of:
--   "place"    - you have the item in your bags and a campfire is in range
--   "carry"    - you have the item, but no campfire nearby
--   "craft"    - you can craft it now
--   "mats"     - you know the recipe but materials are missing
--   "cooldown" - the shared 1 hour camping cooldown is running
--   "unknown"  - recipe not learned (or not craftable yet at all)
function State:Get(entry)
    local API = ns.API
    local info = {
        entry = entry,
        known = entry.spellID and API.IsSpellKnown(entry.spellID) or false,
        count = entry.itemID and API.GetItemCount(entry.itemID) or 0,
        missing = {},
        fireNearby = API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA),
    }

    for _, r in ipairs(entry.reagents) do
        local have = r.itemID and API.GetItemCount(r.itemID) or 0
        local need = r.count or 1
        r.have = have
        if have < need then
            table.insert(info.missing, { name = r.name, have = have, need = need, itemID = r.itemID })
        end
    end

    -- Tools are carried, not consumed, but without one the craft is refused.
    for _, tool in ipairs(entry.tools or {}) do
        local have = tool.itemID and API.GetItemCount(tool.itemID) or 0
        tool.have = have
        if have < 1 then
            table.insert(info.missing, { name = tool.name, have = have, need = 1, itemID = tool.itemID, isTool = true })
        end
    end

    if entry.itemID then
        local start, duration = API.GetItemCooldown(entry.itemID)
        if start and duration and duration > 0 then
            info.cooldownStart, info.cooldownDuration = start, duration
        end
    end

    if info.count > 0 then
        if info.cooldownStart then
            info.status = "cooldown"
        elseif info.fireNearby == false then
            info.status = "carry"
        else
            info.status = "place" -- also when fireNearby is nil: let the game decide
        end
    elseif not info.known then
        info.status = "unknown"
    elseif #info.missing > 0 then
        info.status = "mats"
    else
        info.status = "craft"
    end

    return info
end

-- Objects worth drawing for this character, in panel order.
function State:GetVisibleObjects()
    local settings = ns.db.settings
    local professions, detected = ns.API.GetKnownProfessions()
    local list = {}

    for _, entry in ipairs(ns.Data.objects) do
        local mine = (not detected) or settings.showAll or professions[string.lower(entry.profession)]
        local info = self:Get(entry)
        local show = mine and (settings.showUnknown or info.status ~= "unknown")
        if show then
            info.order = (entry.tier or 1) * 100 + (info.status == "unknown" and 50 or 0)
            table.insert(list, info)
        end
    end

    table.sort(list, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        if a.entry.profession ~= b.entry.profession then
            return a.entry.profession < b.entry.profession
        end
        return a.entry.name < b.entry.name
    end)

    return list
end

-- The same objects, one row per profession and tiers left to right: a flat grid
-- of 30-odd icons is unreadable, a row per trade is not.
function State:GetGroupedObjects()
    local professions, detected = ns.API.GetKnownProfessions()
    local groups, order = {}, {}

    for _, info in ipairs(self:GetVisibleObjects()) do
        local profession = info.entry.profession
        if not groups[profession] then
            groups[profession] = {
                profession = profession,
                mine = (not detected) or professions[string.lower(profession)] or false,
                items = {},
            }
            table.insert(order, groups[profession])
        end
        table.insert(groups[profession].items, info)
    end

    for _, group in ipairs(order) do
        table.sort(group.items, function(a, b)
            return (a.entry.tier or 1) < (b.entry.tier or 1)
        end)
    end

    table.sort(order, function(a, b)
        if a.mine ~= b.mine then
            return a.mine -- your own trades first
        end
        return a.profession < b.profession
    end)

    return order
end

-- Everything you are short of, aggregated across the objects you could craft.
function State:GetShoppingList()
    local totals, order = {}, {}
    for _, info in ipairs(self:GetVisibleObjects()) do
        if info.status == "mats" then
            for _, m in ipairs(info.missing) do
                if not totals[m.name] then
                    totals[m.name] = { name = m.name, have = m.have, need = 0, itemID = m.itemID }
                    table.insert(order, m.name)
                end
                totals[m.name].need = totals[m.name].need + (m.need - m.have)
            end
        end
    end

    local list = {}
    for _, name in ipairs(order) do
        table.insert(list, totals[name])
    end
    return list
end

function State:PrintShoppingList()
    local list = self:GetShoppingList()
    if #list == 0 then
        ns.Print("Nothing missing - every camping object you know is craftable.")
        return
    end
    ns.Print("Missing materials:")
    for _, m in ipairs(list) do
        ns.Print("  " .. ns.Accent(m.name) .. " x" .. m.need .. " (you have " .. m.have .. ")")
    end
end
