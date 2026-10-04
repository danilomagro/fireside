local _, ns = ...

ns.Probe = ns.Probe or {}
local Probe = ns.Probe

local function yesno(value)
    return value and "|cff40ff40yes|r" or "|cffff4040no|r"
end

local function now()
    return date("%Y-%m-%d %H:%M:%S")
end

-- Everything we want to know about this client, collected into ns.db.probe.
-- The beta writes SavedVariables on logout even though it never reads them
-- back, so this file on disk is how the data leaves the game. Runs by itself
-- shortly after login; /fire probe also prints a summary to chat.
function Probe:Capture()
    if not ns.db then
        return nil
    end

    local version, build, _, tocVersion = GetBuildInfo()
    local snapshot = {
        capturedAt = now(),
        client = {
            version = version,
            build = build,
            tocVersion = tocVersion,
            projectID = WOW_PROJECT_ID,
            locale = GetLocale and GetLocale() or nil,
        },
        player = {
            name = UnitName and UnitName("player") or nil,
            level = UnitLevel and UnitLevel("player") or nil,
            class = UnitClass and select(1, UnitClass("player")) or nil,
            faction = UnitFactionGroup and UnitFactionGroup("player") or nil,
        },
        api = {},
        professions = {},
        catalog = {},
    }

    local checks = {
        { "C_Item.GetItemCount", C_Item and C_Item.GetItemCount },
        { "C_Item.GetItemCooldown", C_Item and C_Item.GetItemCooldown },
        { "C_Spell.GetSpellInfo", C_Spell and C_Spell.GetSpellInfo },
        { "C_Spell.GetSpellIDForSpellIdentifier", C_Spell and C_Spell.GetSpellIDForSpellIdentifier },
        { "IsSpellKnown", IsSpellKnown },
        { "IsPlayerSpell", IsPlayerSpell },
        { "GetProfessions", GetProfessions },
        { "AuraUtil.FindAuraByName", AuraUtil and AuraUtil.FindAuraByName },
        { "C_UnitAuras.GetAuraDataBySpellName", C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName },
        { "C_TradeSkillUI.GetAllRecipeIDs", C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs },
        { "C_TradeSkillUI.GetRecipeInfo", C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo },
        { "C_TradeSkillUI.GetRecipeSchematic", C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic },
        { "C_TradeSkillUI.OpenRecipe", C_TradeSkillUI and C_TradeSkillUI.OpenRecipe },
        { "C_TradeSkillUI.CraftRecipe", C_TradeSkillUI and C_TradeSkillUI.CraftRecipe },
        { "C_TradeSkillUI.GetTradeSkillLine", C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine },
        { "issecretvalue", issecretvalue },
        { "loadstring_untainted", loadstring_untainted },
        { "C_Traits.GetConfigInfo", C_Traits and C_Traits.GetConfigInfo },
    }
    for _, check in ipairs(checks) do
        snapshot.api[check[1]] = (type(check[2]) == "function")
    end

    local professions, detected = ns.API.GetKnownProfessions()
    snapshot.professionsDetected = detected
    for name in pairs(professions) do
        table.insert(snapshot.professions, name)
    end
    table.sort(snapshot.professions)

    local fire = ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA)
    snapshot.campfireAura = (fire == nil) and "unreadable" or tostring(fire)

    -- Which profession frame this client actually uses, and whether it was open.
    snapshot.frames = {}
    for _, name in ipairs(ns.UI.TRADE_SKILL_FRAMES or {}) do
        local frame = _G[name]
        snapshot.frames[name] = frame and (frame.IsShown and frame:IsShown() and "shown" or "exists") or "missing"
    end
    -- What the spellbook offers per profession: this is where the spell that
    -- opens each profession window has to come from.
    snapshot.professionSpells = {}
    for profession, record in pairs(ns.API.GetProfessionSpells()) do
        snapshot.professionSpells[profession] = {
            spellID = record.spellID,
            name = record.name or (record.spellID and ns.API.GetSpellName(record.spellID)) or nil,
        }
    end

    snapshot.useKeyDown = ns.API.UseKeyDown()
    snapshot.spellBook = ns.API.DumpSpellBook()
    snapshot.tradeSkillOpen = ns.UI:IsTradeSkillOpen()
    snapshot.workingPlaceRoute = ns.UI.workingPlaceMode

    for _, entry in ipairs(ns.Data.objects) do
        local info = ns.State:Get(entry)
        local record = {
            name = entry.name,
            profession = entry.profession,
            tier = entry.tier,
            spellID = entry.spellID,
            spellName = entry.spellName,
            itemID = entry.itemID,
            known = info.known,
            count = info.count,
            status = info.status,
            reagents = {},
        }
        for _, r in ipairs(entry.reagents) do
            table.insert(record.reagents, { name = r.name, itemID = r.itemID, have = r.have, need = r.count })
        end
        table.insert(snapshot.catalog, record)
    end

    ns.db.probe = snapshot
    ns.dprint("probe captured at " .. snapshot.capturedAt)
    return snapshot
end

-- Appended every time a craft button is clicked, so the SavedVariables file
-- says whether the direct spell cast worked or the profession-window fallback
-- had to step in. This is the one open question of the whole addon.
function Probe:LogCraftAttempt(entry, result, detail)
    if not (ns.db and ns.DEBUG) then
        return
    end
    ns.db.craftLog = ns.db.craftLog or {}
    table.insert(ns.db.craftLog, {
        at = now(),
        name = entry.name,
        spellID = entry.spellID,
        itemID = entry.itemID,
        result = result,  -- "cast" | "no-cast" | "fallback-opened" | "fallback-failed"
        detail = detail,
    })
    -- Keep the file small: only the last 50 attempts matter.
    while #ns.db.craftLog > 50 do
        table.remove(ns.db.craftLog, 1)
    end
end

function Probe:Run()
    local snapshot = self:Capture()
    if not snapshot then
        return
    end

    ns.Print(("client %s build %s toc %s, WOW_PROJECT_ID %s"):format(
        tostring(snapshot.client.version), tostring(snapshot.client.build),
        tostring(snapshot.client.tocVersion), tostring(snapshot.client.projectID)))

    local missing = {}
    for name, present in pairs(snapshot.api) do
        if not present then
            table.insert(missing, name)
        end
    end
    table.sort(missing)
    ns.Print("missing API: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))

    ns.Print("professions detected: " .. yesno(snapshot.professionsDetected)
        .. " (" .. (#snapshot.professions > 0 and table.concat(snapshot.professions, ", ") or "none") .. ")")
    ns.Print("campfire aura: " .. snapshot.campfireAura)

    local known = 0
    for _, record in ipairs(snapshot.catalog) do
        if record.known then
            known = known + 1
        end
    end
    ns.Print(("catalog: %d of %d camping objects known on this character"):format(known, #snapshot.catalog))
    ns.Print("Saved to " .. ns.Accent("FiresideDB.probe") .. " - log out and the file is written to disk.")
end

-- Harvest real recipe data from an open profession window. Called by hand with
-- /fire scan, and automatically whenever a profession window updates.
function Probe:HarvestTradeSkill(silent)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then
        if not silent then
            ns.PrintWarn("C_TradeSkillUI is not available on this client - run /fire probe.")
        end
        return
    end

    local ok, recipeIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok or type(recipeIDs) ~= "table" or #recipeIDs == 0 then
        if not silent then
            ns.PrintWarn("No recipes readable - open a profession window first, then run /fire scan.")
        end
        return
    end

    local wanted = {}
    for _, entry in ipairs(ns.Data.objects) do
        for _, name in ipairs(ns.Data:NamesFor(entry)) do
            wanted[string.lower(name)] = entry
        end
    end

    ns.db.harvest.recipes = ns.db.harvest.recipes or {}
    local found, fresh = 0, 0

    for _, recipeID in ipairs(recipeIDs) do
        local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        local name = okInfo and type(info) == "table" and info.name
        local entry = name and wanted[string.lower(name)]
        if entry then
            found = found + 1
            local record = {
                name = name,
                recipeID = recipeID,
                learned = okInfo and info.learned or nil,
                harvestedAt = now(),
                reagents = {},
            }

            if C_TradeSkillUI.GetRecipeSchematic then
                local okSchem, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
                if okSchem and type(schematic) == "table" then
                    record.outputItemID = schematic.outputItemID
                    record.quantityMin = schematic.quantityMin
                    record.quantityMax = schematic.quantityMax
                    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
                        local reagent = slot.reagents and slot.reagents[1]
                        if reagent then
                            table.insert(record.reagents, {
                                itemID = reagent.itemID,
                                name = ns.API.GetItemName(reagent.itemID),
                                quantity = slot.quantityRequired,
                            })
                        end
                    end
                end
            end

            if not ns.db.harvest.recipes[name] then
                fresh = fresh + 1
            end
            -- Only kept on disk while debugging; the live catalog below is
            -- fed either way, which is what makes the panel work this session.
            if ns.DEBUG then
                ns.db.harvest.recipes[name] = record
            end

            -- Feed the live catalog straight away.
            entry.spellID = entry.spellID or recipeID
            entry.itemID = entry.itemID or record.outputItemID
        end
    end

    if found == 0 then
        if not silent then
            ns.Print("No camping objects in this profession window (open the right profession).")
        end
        return
    end

    if not silent then
        ns.Print(("harvested %d camping recipe(s)%s."):format(found, fresh > 0 and (", " .. fresh .. " new") or ""))
    end
    if ns.DEBUG then
        self:Capture()
    end
    ns.UI:Refresh()
end

-- Profession windows fire their list update several times in a row.
function Probe:ScheduleHarvest()
    if self.harvestPending then
        return
    end
    self.harvestPending = true
    C_Timer.After(1, function()
        self.harvestPending = nil
        local ok, err = pcall(function()
            self:HarvestTradeSkill(true)
        end)
        if not ok then
            ns.dprint("harvest failed: " .. tostring(err))
        end
    end)
end
