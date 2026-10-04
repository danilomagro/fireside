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
-- never says which objects are coming, only that something is.
Data.WELCOMING_CAMPFIRE_ID = 1229739

-- Reagent item IDs are the Classic ones. ResolveIDs() checks each resolved name
-- against the expected name and falls back to matching bag items by name when
-- an ID turns out to be wrong on this client.
local R = {
    roughStone      = { id = 2835,  name = "Rough Stone" },
    copperBar       = { id = 2840,  name = "Copper Bar" },
    peacebloom      = { id = 2447,  name = "Peacebloom" },
    emptyVial       = { id = 3371,  name = "Empty Vial" },
    boltOfLinen     = { id = 2996,  name = "Bolt of Linen Cloth" },
    coarseThread    = { id = 2320,  name = "Coarse Thread" },
    simpleWood      = { id = 4470,  name = "Simple Wood" },
    strangeDust     = { id = 10940, name = "Strange Dust" },
    silverleaf      = { id = 765,   name = "Silverleaf" },
    lightLeather    = { id = 2318,  name = "Light Leather" },
    linenBandage    = { id = 1251,  name = "Linen Bandage" },
    springWater     = { id = 159,   name = "Refreshing Spring Water" },
    smallfish       = { id = 6291,  name = "Raw Brilliant Smallfish" },
    flintAndTinder  = { id = 4471,  name = "Flint and Tinder" },
}

local function reagent(entry, count)
    return { itemID = entry.id, name = entry.name, count = count or 1 }
end

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

-- Tier 1 is from live beta tooltips (17-18 Sep 2026). Tiers 2 and 3 are names
-- and skill levels only: reagents, spell IDs and effects are unconfirmed, and
-- those recipes come from Blueprints that drop from dungeon bosses.
Data.objects = {
    {
        key = "lodestone", name = "Lodestone", profession = "Mining", tier = 1, skill = 20,
        spellID = 1230161, itemID = nil, creates = 2,
        icon = "Interface\\Icons\\INV_Misc_Rune_06",
        effect = "+12 melee Attack Power to everyone sitting nearby",
        exclusive = "Blessing of Might",
        reagents = { reagent(R.roughStone), reagent(R.copperBar) },
        verified = true,
    },
    {
        key = "sharpening_wheel", name = "Sharpening Wheel", profession = "Blacksmithing", tier = 1, skill = 20,
        effect = "+6 Strength to everyone sitting nearby",
        exclusive = "Strength of Earth Totem",
        reagents = { reagent(R.roughStone), reagent(R.copperBar) },
        verified = true,
    },
    {
        key = "mana_well", name = "Mana Well", profession = "Alchemy", tier = 1, skill = 20,
        effect = "+10 mana every 5 sec to everyone sitting nearby",
        exclusive = "Blessing of Wisdom",
        reagents = { reagent(R.peacebloom), reagent(R.emptyVial) },
        verified = true,
    },
    {
        key = "faction_banner", name = "Faction Banner", profession = "Tailoring", tier = 1, skill = 20,
        effect = "+14 Spirit to your own faction sitting nearby",
        exclusive = "Divine Spirit",
        reagents = { reagent(R.boltOfLinen), reagent(R.coarseThread) },
        verified = true,
    },
    {
        key = "enchanted_lute", name = "Enchanted Lute", profession = "Enchanting", tier = 1, skill = 20,
        effect = "+28 Armor to everyone sitting nearby",
        exclusive = "Mark of the Wild",
        reagents = { reagent(R.simpleWood), reagent(R.strangeDust) },
        verified = true,
    },
    {
        key = "incense_candle", name = "Incense Candle", profession = "Herbalism", tier = 1, skill = 20,
        effect = "+2 Intellect to everyone sitting nearby",
        exclusive = "Arcane Intellect",
        reagents = { reagent(R.peacebloom), reagent(R.silverleaf) },
        verified = true,
    },
    {
        key = "camp_chair", name = "Camp Chair", profession = "Skinning", tier = 1, skill = 20,
        effect = "+2% critical strike (spells and attacks) to everyone sitting nearby",
        exclusive = "Moonkin Aura",
        reagents = { reagent(R.lightLeather, 3), reagent(R.simpleWood, 2) },
        verified = true,
    },
    {
        key = "first_aid_kit", name = "First Aid Kit", profession = "First Aid", tier = 1, skill = 20,
        effect = "+3 Stamina to everyone sitting nearby",
        exclusive = "Power Word: Fortitude",
        reagents = { reagent(R.linenBandage, 3), reagent(R.springWater) },
        verified = true,
    },
    {
        key = "camp_tent", name = "Camp Tent", profession = "Leatherworking", tier = 1, skill = 20,
        effect = "Raises Rested experience to 5% of a level",
        reagents = { reagent(R.lightLeather, 5) },
        verified = true,
    },
    {
        key = "fish_bowl", name = "Fish Bowl", profession = "Fishing", tier = 1, skill = 20,
        effect = "+8% to all stats for everyone sitting nearby",
        exclusive = "Blessing of Kings",
        reagents = { reagent(R.smallfish), reagent(R.emptyVial) },
        verified = true,
    },
    {
        key = "reagent_bot", name = "Reagent Bot", profession = "Engineering", tier = 1, skill = 20,
        effect = "Reagent vendor at the camp",
        reagents = {},
        verified = false, -- reagents not seen yet
    },
    {
        key = "basic_campfire", name = "Basic Campfire Kit", profession = "Cooking", tier = 1, skill = 1,
        aliases = { "Basic Campfire" }, -- the recipe is the fire, the item is the kit
        -- Tools are required but not consumed, so they never show up in the
        -- reagent list the client gives us.
        tools = { { itemID = 4471, name = "Flint and Tinder" } },
        effect = "Places the campfire itself: up to 3 camp features, sit or craft 1 min for the benefits",
        reagents = { reagent(R.flintAndTinder), reagent(R.simpleWood, 1) },
        verified = true,
    },

    -- Tier 2 / tier 3: Blueprint recipes from dungeon bosses. Names and skill
    -- levels from the Deep Dive recap; everything else still to confirm.
    { key = "rock_garden", name = "Rock Garden", profession = "Mining", tier = 2, skill = 140, verified = false },
    { key = "molten_foundry", name = "Molten Foundry", profession = "Mining", tier = 3, skill = 300, verified = false },
    { key = "anvil", name = "Anvil", profession = "Blacksmithing", tier = 2, skill = 140, verified = false },
    { key = "master_forge", name = "Master Forge", profession = "Blacksmithing", tier = 3, skill = 300, verified = false },
    { key = "fermenter", name = "Fermenter", profession = "Alchemy", tier = 2, skill = 140, verified = false },
    { key = "alchemy_laboratory", name = "Alchemy Laboratory", profession = "Alchemy", tier = 3, skill = 300, verified = false },
    { key = "spinning_wheel", name = "Spinning Wheel", profession = "Tailoring", tier = 2, skill = 140, verified = false },
    { key = "loom", name = "Loom", profession = "Tailoring", tier = 3, skill = 300, verified = false },
    { key = "arcane_salvager", name = "Arcane Salvager", profession = "Enchanting", tier = 2, skill = 140, verified = false },
    { key = "arcane_forge", name = "Arcane Forge", profession = "Enchanting", tier = 3, skill = 300, verified = false },
    { key = "greenhouse", name = "Greenhouse", profession = "Herbalism", tier = 2, skill = 140, verified = false },
    { key = "seed_hybridizer", name = "Seed Hybridizer", profession = "Herbalism", tier = 3, skill = 300, verified = false },
    { key = "field_guide", name = "Field Guide", profession = "Skinning", tier = 2, skill = 140, verified = false },
    { key = "trappers_workbench", name = "Trapper's Workbench", profession = "Skinning", tier = 3, skill = 300, verified = false },
    { key = "tanning_rack", name = "Tanning Rack", profession = "Leatherworking", tier = 2, skill = 140, verified = false },
    { key = "sewing_machine", name = "Sewing Machine", profession = "Leatherworking", tier = 3, skill = 300, verified = false },
    { key = "repair_bot", name = "Repair Bot", profession = "Engineering", tier = 2, skill = 140, verified = false },
    { key = "anarchists_workbench", name = "Anarchist's Workbench", profession = "Engineering", tier = 3, skill = 300, verified = false },
    { key = "toxin_study", name = "Toxin Study", profession = "First Aid", tier = 2, skill = 140, verified = false },
    { key = "plague_doctors_laboratory", name = "Plague Doctor's Laboratory", profession = "First Aid", tier = 3, skill = 300, verified = false },
    { key = "fishing_rack", name = "Fishing Rack", profession = "Fishing", tier = 2, skill = 140, verified = false },
    { key = "fishing_hut", name = "Fishing Hut", profession = "Fishing", tier = 3, skill = 300, verified = false },
    { key = "journeyman_campfire", name = "Journeyman Campfire", profession = "Cooking", tier = 2, skill = 140, verified = false },
    { key = "expert_campfire", name = "Expert Campfire", profession = "Cooking", tier = 3, skill = 220, verified = false },
    { key = "iron_oven", name = "Iron Oven", profession = "Cooking", tier = 4, skill = 300, verified = false },
}

Data.byKey = {}

function Data:Initialize()
    for _, entry in ipairs(self.objects) do
        entry.reagents = entry.reagents or {}
        entry.icon = entry.icon or PROF_ICON[entry.profession]
        self.byKey[entry.key] = entry
    end
    self:MergeHarvested()
    self:ResolveIDs(true)
end

-- Harvested.lua is generated from a real client, so its IDs and reagents win
-- over the hand-written ones. Everything the client cannot tell us (effects,
-- exclusive-with, skill levels) stays in the table above.
function Data:MergeHarvested(source)
    source = source or self.harvested
    if not source then
        return
    end

    for _, entry in ipairs(self.objects) do
        local record = source[entry.name]
        if not record and entry.aliases then
            for _, alias in ipairs(entry.aliases) do
                record = record or source[alias]
            end
        end
        if record then
            entry.spellID = record.spellID or entry.spellID
            entry.itemID = record.itemID or entry.itemID
            entry.creates = record.creates or entry.creates
            if record.reagents and #record.reagents > 0 then
                entry.reagents = {}
                for _, r in ipairs(record.reagents) do
                    table.insert(entry.reagents, { itemID = r.itemID, name = r.name, count = r.count or 1 })
                end
            end
            entry.verified = true
        end
    end
end

-- Every name a recipe can go by: the trainer list shows "Name (Tier I)" and the
-- Cooking kit recipe is the fire, not the item it makes.
function Data:NamesFor(entry)
    local names = { entry.name }
    for _, alias in ipairs(entry.aliases or {}) do
        table.insert(names, alias)
    end
    return names
end

-- Everything the client can tell us about names, icons and IDs. Safe to call
-- repeatedly: item and spell data arrive asynchronously. Throttled because the
-- panel refreshes on every bag update.
function Data:ResolveIDs(force)
    local now = GetTime and GetTime() or 0
    if not force and self.lastResolve and (now - self.lastResolve) < 5 then
        return
    end
    self.lastResolve = now

    local API = ns.API

    for _, entry in ipairs(self.objects) do
        if not entry.spellID then
            for _, name in ipairs(self:NamesFor(entry)) do
                entry.spellID = entry.spellID or API.GetSpellIDByName(name)
            end
        end
        if entry.spellID and not entry.spellName then
            entry.spellName = API.GetSpellName(entry.spellID)
        end
        if entry.itemID then
            local icon = API.GetItemIcon(entry.itemID)
            if icon then
                entry.icon = icon
            end
        end
        for _, r in ipairs(entry.reagents) do
            if r.itemID then
                local name = API.GetItemName(r.itemID)
                if name and name ~= r.name then
                    -- The ID points at something else on this client: drop it
                    -- and let the bag scan find the right one by name.
                    ns.dprint(("reagent id %d resolved to %q, expected %q"):format(r.itemID, name, r.name))
                    r.itemID = nil
                end
            end
        end
    end

    self:ScanBagsForItemIDs()
end

-- Camping objects are consumables in your bags. Learning their item IDs from an
-- actual stack is the most reliable route while datamined IDs keep shifting.
function Data:ScanBagsForItemIDs()
    if not (C_Container and C_Container.GetContainerNumSlots) then
        return
    end

    local wanted = {}
    for _, entry in ipairs(self.objects) do
        if not entry.itemID then
            wanted[string.lower(entry.name)] = entry
        end
        for _, r in ipairs(entry.reagents) do
            if not r.itemID then
                wanted[string.lower(r.name)] = r
            end
        end
    end
    if not next(wanted) then
        return
    end

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local name = ns.API.GetItemName(itemID)
                local target = name and wanted[string.lower(name)]
                if target then
                    target.itemID = itemID
                    ns.dprint(("learned item id %d for %s"):format(itemID, name))
                    if ns.db then
                        ns.db.harvest.items = ns.db.harvest.items or {}
                        ns.db.harvest.items[name] = itemID
                    end
                end
            end
        end
    end
end
