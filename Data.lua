local _, ns = ...

ns.Data = ns.Data or {}
local Data = ns.Data

-- The only cue the game gives that a campsite is in range. Matched by id first
-- (any client language), by name as a fallback.
Data.CAMPFIRE_AURA = "Campfire Nearby"
Data.CAMPFIRE_AURA_ID = 1283391

-- After a minute at a fire every benefit arrives as ONE aura, not one per
-- object; its tooltip lists them as "<Object name>: <effect>" lines.
Data.CAMP_BENEFITS_ID = 1229741
Data.CAMP_BENEFITS = "Camp Benefits"

-- The 60 second wait before the benefits land. Its tooltip is generic: it
-- never says which objects are coming, only that something is. Player fires
-- give 1229739; ambient fires in the world (questgivers, NPC camps) give
-- 1289723 - an id spotted in the Campfire Tales addon, to verify in game.
Data.WELCOMING_CAMPFIRE_IDS = { 1229739, 1289723 }

-- Professions by skill line id: GetProfessionInfo returns the same number in
-- every client language, unlike the profession name.
Data.PROF_SKILL_LINE = {
    Mining = 186,
    Blacksmithing = 164,
    Alchemy = 171,
    Tailoring = 197,
    Enchanting = 333,
    Herbalism = 182,
    Skinning = 393,
    Leatherworking = 165,
    Engineering = 202,
    ["First Aid"] = 129,
    Fishing = 356,
    Cooking = 185,
}

-- Fallback icons only. The real item icon replaces them as soon as the item
-- data resolves: live trainer art wins over anything we guess here.
local PROF_ICON = {
    Mining          = "Interface\\Icons\\Trade_Mining",
    Blacksmithing   = "Interface\\Icons\\Trade_BlackSmithing",
    Alchemy         = "Interface\\Icons\\Trade_Alchemy",
    Tailoring       = "Interface\\Icons\\Trade_Tailoring",
    Enchanting      = "Interface\\Icons\\Trade_Engraving",
    Herbalism       = "Interface\\Icons\\Trade_Herbalism",
    Skinning        = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    Leatherworking  = "Interface\\Icons\\Trade_LeatherWorking",
    Engineering     = "Interface\\Icons\\Trade_Engineering",
    ["First Aid"]   = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    Fishing         = "Interface\\Icons\\Trade_Fishing",
    Cooking         = "Interface\\Icons\\INV_Misc_Food_15",
}
Data.PROF_ICON = PROF_ICON

-- The hand-written half of the catalog: what each object is called, where it
-- belongs and what the game cannot tell us. Ids, skill, tier, reagents and
-- effects come from Harvested.lua (scripts/build_catalog.py). Higher tiers
-- "provide all the benefits" of the first one, so they share its exclusive
-- class buff.
Data.objects = {
    { key = "lodestone", name = "Lodestone", profession = "Mining", exclusive = "Blessing of Might" },
    { key = "rock_garden", name = "Rock Garden", profession = "Mining", exclusive = "Blessing of Might" },
    { key = "molten_foundry", name = "Molten Foundry", profession = "Mining", exclusive = "Blessing of Might" },

    { key = "sharpening_wheel", name = "Sharpening Wheel", profession = "Blacksmithing", exclusive = "Strength of Earth Totem" },
    { key = "anvil", name = "Anvil", profession = "Blacksmithing", exclusive = "Strength of Earth Totem" },
    { key = "master_forge", name = "Master Forge", profession = "Blacksmithing", exclusive = "Strength of Earth Totem" },

    { key = "mana_well", name = "Mana Well", profession = "Alchemy", exclusive = "Blessing of Wisdom" },
    { key = "fermenter", name = "Fermenter", profession = "Alchemy", exclusive = "Blessing of Wisdom" },
    -- Announced, not in the Forever database yet: no recipe data.
    { key = "alchemy_laboratory", name = "Alchemy Laboratory", profession = "Alchemy", tier = 3, skill = 300, unconfirmed = true },

    { key = "faction_banner", name = "Faction Banner", profession = "Tailoring", exclusive = "Divine Spirit" },
    { key = "spinning_wheel", name = "Spinning Wheel", profession = "Tailoring", exclusive = "Divine Spirit" },
    { key = "loom", name = "Loom", profession = "Tailoring", exclusive = "Divine Spirit" },

    { key = "enchanted_lute", name = "Enchanted Lute", profession = "Enchanting", exclusive = "Mark of the Wild" },
    { key = "arcane_salvager", name = "Arcane Salvager", profession = "Enchanting", exclusive = "Mark of the Wild" },
    { key = "arcane_forge", name = "Arcane Forge", profession = "Enchanting", exclusive = "Mark of the Wild" },

    { key = "incense_candle", name = "Incense Candle", profession = "Herbalism", exclusive = "Arcane Intellect" },
    { key = "greenhouse", name = "Greenhouse", profession = "Herbalism", exclusive = "Arcane Intellect" },
    { key = "seed_hybridizer", name = "Seed Hybridizer", profession = "Herbalism", exclusive = "Arcane Intellect" },

    { key = "camp_chair", name = "Camp Chair", profession = "Skinning", exclusive = "Moonkin Aura" },
    { key = "field_guide", name = "Field Guide", profession = "Skinning", exclusive = "Moonkin Aura" },
    { key = "trappers_workbench", name = "Trapper's Workbench", profession = "Skinning", exclusive = "Moonkin Aura" },

    { key = "camp_tent", name = "Camp Tent", profession = "Leatherworking" },
    { key = "tanning_rack", name = "Tanning Rack", profession = "Leatherworking" },
    { key = "sewing_machine", name = "Sewing Machine", profession = "Leatherworking" },

    { key = "reagent_bot", name = "Reagent Bot", profession = "Engineering" },
    { key = "repair_bot", name = "Repair Bot", profession = "Engineering" },
    { key = "anarchists_workbench", name = "Anarchist's Workbench", profession = "Engineering" },

    { key = "first_aid_kit", name = "First Aid Kit", profession = "First Aid", exclusive = "Power Word: Fortitude" },
    { key = "toxin_study", name = "Toxin Study", profession = "First Aid", exclusive = "Power Word: Fortitude" },
    { key = "plague_doctors_laboratory", name = "Plague Doctor's Laboratory", profession = "First Aid", exclusive = "Power Word: Fortitude" },

    { key = "fish_bowl", name = "Fish Bowl", profession = "Fishing", exclusive = "Blessing of Kings" },
    { key = "fishing_rack", name = "Fishing Rack", profession = "Fishing", exclusive = "Blessing of Kings" },
    { key = "fishing_hut", name = "Fishing Hut", profession = "Fishing", exclusive = "Blessing of Kings" },

    {
        key = "basic_campfire", name = "Basic Campfire Kit", profession = "Cooking",
        isFire = true, -- lights a campsite instead of needing one
        aliases = { "Basic Campfire" }, -- the recipe is the fire, the item is the kit
        -- Tools are required but not consumed, so they never show up in the
        -- reagent list.
        tools = { { itemID = 4471, name = "Flint and Tinder" } },
    },
    { key = "journeyman_campfire", name = "Journeyman Campfire Kit", profession = "Cooking", isFire = true, aliases = { "Journeyman Campfire" } },
    { key = "expert_campfire", name = "Expert Campfire Kit", profession = "Cooking", isFire = true, aliases = { "Expert Campfire" } },
    { key = "cookies_feast", name = "Cookie's Feast", profession = "Cooking" },
    { key = "iron_oven", name = "Iron Oven", profession = "Cooking" },
}

Data.byKey = {}

function Data:Initialize()
    for _, entry in ipairs(self.objects) do
        entry.reagents = entry.reagents or {}
        entry.icon = entry.icon or PROF_ICON[entry.profession]
        entry.skillLine = self.PROF_SKILL_LINE[entry.profession]
        self.byKey[entry.key] = entry
    end
    self:MergeHarvested()
    self:ResolveIDs(true)
end

-- Fill each catalog entry from Harvested.lua. The Faction Banner is two
-- recipes, one per faction, so it takes the one for the player's side.
function Data:MergeHarvested(source)
    source = source or self.harvested
    if not source then
        return
    end

    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, entry in ipairs(self.objects) do
        local record = source[entry.key]
        if record and record.variants then
            record = record.variants[faction] or record.variants.Alliance or record.variants.Horde
        end
        if record then
            entry.spellID = record.spellID or entry.spellID
            entry.itemID = record.itemID or entry.itemID
            entry.creates = record.creates or entry.creates
            entry.tier = record.tier or entry.tier
            entry.skill = record.skill or entry.skill
            entry.effect = record.effect or entry.effect
            entry.skillLine = record.skillLine or entry.skillLine
            entry.reagents = {}
            for _, r in ipairs(record.reagents or {}) do
                table.insert(entry.reagents, { itemID = r.itemID, name = r.name, count = r.count or 1 })
            end
        end
    end
end

-- Every name a recipe can go by: the trainer list shows "Name (Tier I)" and the
-- Cooking kit recipes are named after the fire, not the kit item.
function Data:NamesFor(entry)
    local names = { entry.name }
    if entry.itemName and entry.itemName ~= entry.name then
        table.insert(names, entry.itemName)
    end
    for _, alias in ipairs(entry.aliases or {}) do
        table.insert(names, alias)
    end
    return names
end

-- Everything the client can tell us about names and icons. Safe to call
-- repeatedly: item and spell data arrive asynchronously. Throttled because the
-- panel refreshes on every bag update. Ids are not second-guessed here: they
-- come from the game's own database, and their names are only English there,
-- so a name mismatch on another client language is expected, not an error.
function Data:ResolveIDs(force)
    local now = GetTime and GetTime() or 0
    if not force and self.lastResolve and (now - self.lastResolve) < 5 then
        return
    end
    self.lastResolve = now

    local API = ns.API
    for _, entry in ipairs(self.objects) do
        if entry.spellID and not entry.spellName then
            entry.spellName = API.GetSpellName(entry.spellID)
        end
        if entry.itemID then
            entry.itemName = entry.itemName or API.GetItemName(entry.itemID)
            local icon = API.GetItemIcon(entry.itemID)
            if icon then
                entry.icon = icon
            end
        end
        for _, r in ipairs(entry.reagents) do
            if r.itemID and not r.localName then
                r.localName = API.GetItemName(r.itemID)
            end
        end
    end
end
