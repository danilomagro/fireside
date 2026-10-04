local _, ns = ...

ns.Auras = ns.Auras or {}
local Auras = ns.Auras

-- There is no API for what is placed at a campsite: the client exposes no camp
-- namespace at all. The only readable trace a placed object leaves is the buff
-- it gives the people sitting there, so that is what we collect.
--
-- This file harvests auras the way Probe.lua harvests recipes: it writes what
-- it sees into SavedVariables, near a fire and away from one, so the buffs that
-- belong to camping objects can be told apart from everything else.
--
-- It reads the player and nobody else. Other people's buffs would answer a
-- different question - which class buffs a group already covers - and that is
-- not worth reading anyone's auras until the feature actually exists.

local MAX_AURAS = 60
local MAX_SESSIONS = 30

local function readAura(unit, index)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        return nil
    end
    local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
    if not ok or type(data) ~= "table" then
        return nil
    end
    -- A secret aura must not be compared or branched on, so it is skipped
    -- entirely rather than half-read.
    if ns.IsSecret(data.spellId) or ns.IsSecret(data.name) then
        return nil
    end
    return data
end

-- Every helpful aura on a unit, as plain data. Returns nil when the client
-- refuses to answer for that unit rather than an empty list, so "no buffs" and
-- "cannot look" stay different things.
function Auras:Read(unit)
    if not (UnitExists and UnitExists(unit)) then
        return nil
    end

    local list, sawAny = {}, false
    for index = 1, 40 do
        local data = readAura(unit, index)
        if data and data.spellId then
            sawAny = true
            table.insert(list, {
                spellID = data.spellId,
                name = data.name,
                duration = data.duration,
                expires = data.expirationTime,
                source = data.sourceUnit,
                icon = data.icon,
            })
        elseif not data then
            -- Index gaps are normal; only stop when the first read fails.
            if index == 1 then
                return sawAny and list or nil
            end
        end
    end
    return list
end

function Auras:Snapshot(reason)
    -- A developer harvester: normal users never write aura history.
    if not (ns.db and ns.DEBUG) then
        return
    end
    -- UNIT_AURA fires in bursts; one sample every few seconds is plenty.
    local clock = GetTime and GetTime() or 0
    if reason ~= "slash" and self.lastSnapshot and (clock - self.lastSnapshot) < 5 then
        return
    end
    self.lastSnapshot = clock

    local nearFire = ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA)
    local mine = self:Read("player")
    if not mine then
        return
    end

    ns.db.auras = ns.db.auras or { seen = {}, sessions = {} }
    local store = ns.db.auras
    local now = date("%Y-%m-%d %H:%M:%S")

    local ids = {}
    for _, aura in ipairs(mine) do
        table.insert(ids, aura.spellID)
        -- Record the benefit lines whenever the aura is there, not only when
        -- the panel happens to be open and refreshing.
        if aura.spellID == ns.Data.CAMP_BENEFITS_ID then
            self:ReadCampBenefits()
        end
        local record = store.seen[aura.spellID]
        if not record then
            record = {
                name = aura.name,
                firstSeen = now,
                nearFireCount = 0,
                awayCount = 0,
            }
            store.seen[aura.spellID] = record
        end
        record.lastSeen = now
        record.duration = aura.duration or record.duration
        record.source = aura.source or record.source
        if nearFire == true then
            record.nearFireCount = (record.nearFireCount or 0) + 1
        else
            record.awayCount = (record.awayCount or 0) + 1
        end
    end

    -- A session row is a moment at a fire. The object count itself comes from
    -- the Camp Benefits lines (ReadCampBenefits), not from counting buffs: all
    -- the objects arrive folded into that single aura.
    if nearFire == true then
        table.insert(store.sessions, {
            at = now,
            reason = reason,
            count = #mine,
            spellIDs = ids,
        })
        while #store.sessions > MAX_SESSIONS do
            table.remove(store.sessions, 1)
        end
    end

    local count = 0
    for _ in pairs(store.seen) do
        count = count + 1
    end
    if count > MAX_AURAS then
        store.seen = {} -- start over rather than grow without bound
    end
end

-- The Camp Benefits aura, found by id and read through its tooltip. Returns
-- nil when you do not have it, or a table with the raw tooltip lines and the
-- minutes left. The lines also go into SavedVariables so the exact wording the
-- client uses can be checked against the catalog.
function Auras:ReadCampBenefits()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return nil
    end
    local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, ns.Data.CAMP_BENEFITS_ID)
    if not ok or type(data) ~= "table" then
        return nil
    end

    local result = { lines = {} }
    local expires = data.expirationTime
    if expires and not ns.IsSecret(expires) and expires > 0 then
        result.minutesLeft = math.max(0, math.floor((expires - GetTime()) / 60 + 0.5))
    end

    local tip
    if C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID and data.auraInstanceID then
        local okTip, value = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", data.auraInstanceID)
        tip = okTip and value or nil
    end
    -- The client packs every benefit into ONE tooltip line separated by
    -- "\r\n", so split it into the logical lines the catalog is matched on.
    for _, line in ipairs((tip and tip.lines) or {}) do
        local text = line.leftText
        if type(text) == "string" and not ns.IsSecret(text) then
            for segment in text:gmatch("[^\r\n]+") do
                segment = segment:gsub("^%s+", ""):gsub("%s+$", "")
                if segment ~= "" then
                    table.insert(result.lines, segment)
                end
            end
        end
    end

    if ns.db and ns.DEBUG then
        ns.db.auras = ns.db.auras or { seen = {}, sessions = {} }
        ns.db.auras.campBenefits = {
            at = date("%Y-%m-%d %H:%M:%S"),
            lines = result.lines,
            minutesLeft = result.minutesLeft,
        }
    end
    return result
end

-- Seconds left on the Welcoming Campfire wait, or nil when you are not waiting.
function Auras:WelcomingSecondsLeft()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return nil
    end
    for _, auraID in ipairs(ns.Data.WELCOMING_CAMPFIRE_IDS) do
        local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
        if ok and type(data) == "table" then
            local expires = data.expirationTime
            if expires and not ns.IsSecret(expires) and expires > 0 then
                return math.max(0, math.ceil(expires - GetTime()))
            end
        end
    end
    return nil
end

-- Two different things can be read off your own buffs, and they must not be
-- mixed up:
--   benefits - what your Camp Benefits aura says you already carry, one entry
--              per object named in its tooltip. It outlives the camp by an
--              hour, so it means "what you have", never "what is at this fire".
--   covered  - a class buff an object is exclusive with (a mage's own Arcane
--              Intellect covers the Incense Candle). Known before you place
--              anything: that object would add nothing for you.
function Auras:CampBuffState()
    local benefits, covered = {}, {}

    local camp = self:ReadCampBenefits()
    if camp then
        -- English name and the client's own item name, so another client
        -- language still matches.
        for _, entry in ipairs(ns.Data.objects) do
            for _, name in ipairs(ns.Data:NamesFor(entry)) do
                local prefix = string.lower(name) .. ":"
                for _, line in ipairs(camp.lines) do
                    if string.lower(line):sub(1, #prefix) == prefix then
                        benefits[entry.key] = { line = line, minutesLeft = camp.minutesLeft }
                    end
                end
            end
        end
    end

    local byClassBuff = {}
    for _, entry in ipairs(ns.Data.objects) do
        if entry.exclusive then
            byClassBuff[string.lower(entry.exclusive)] = entry
        end
    end
    for _, aura in ipairs(self:Read("player") or {}) do
        local match = aura.name and byClassBuff[string.lower(aura.name)]
        if match then
            covered[match.key] = { name = aura.name, spellID = aura.spellID }
        end
    end

    return benefits, covered, camp and camp.minutesLeft
end

function Auras:Print()
    local mine = self:Read("player")
    if not mine then
        ns.PrintWarn("Cannot read your auras right now.")
        return
    end

    local nearFire = ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA)
    ns.Print(("%d buff(s) on you, campfire nearby: %s"):format(#mine, tostring(nearFire)))
    for _, aura in ipairs(mine) do
        ns.Print(("  %s %s"):format(ns.Accent(aura.name or "?"), tostring(aura.spellID)))
    end
    self:Snapshot("slash")
    ns.Print("Saved to " .. ns.Accent("FiresideDB.auras") .. " - it is written on logout.")
end
