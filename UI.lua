local _, ns = ...

ns.UI = ns.UI or {}
local UI = ns.UI

local MAX_TIERS = 5        -- Cooking has five objects, everyone else three
local LABEL_WIDTH = 96
local ICON_SIZE = 40
local PADDING = 8
local SPACING = 9  -- room for the glow around clickable icons
local HEADER = 26
local FOOTER = 20
local PANEL_WIDTH = PADDING * 2 + LABEL_WIDTH + MAX_TIERS * ICON_SIZE + (MAX_TIERS - 1) * SPACING

local STATUS_HINT = {
    place    = "Click to place it at the campfire",
    carry    = "In your bags - find a campfire to place it",
    craft    = "Click to craft",
    mats     = "Materials missing",
    cooldown = "Camping cooldown running",
    unknown  = "Not learned yet",
}

local function Desaturate(texture, on)
    if texture.SetDesaturated then
        texture:SetDesaturated(on and true or false)
    end
end

function UI:Initialize()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "FiresidePanel", UIParent, "BackdropTemplate")
    f:SetSize(PANEL_WIDTH, 120)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not ns.db.settings.locked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.settings.point = { point, relPoint, x, y }
    end)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PADDING, -PADDING)
    title:SetText("|cffffd100Fireside|r")
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        UI:Hide()
    end)

    local footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING - 2)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING - 2)
    footer:SetJustifyH("LEFT")
    f.footer = footer

    self.frame = f
    self.buttons = {}
    self.labels = {}
    self:ApplyPosition()
    self:Refresh()
end

function UI:ApplyPosition()
    if not self.frame then
        return
    end
    local p = ns.db.settings.point or { "CENTER", "CENTER", 0, 120 }
    self.frame:ClearAllPoints()
    self.frame:SetPoint(p[1] or "CENTER", UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 120)
end

-- The panel holds secure buttons, so the game refuses to show or hide it in
-- combat. Say so instead of failing silently.
local function BlockedByCombat()
    if InCombatLockdown() then
        ns.Print("The panel cannot open or close during combat.")
        return true
    end
    return false
end

function UI:Show()
    if self.frame and not BlockedByCombat() then
        self.frame:Show()
        self:Refresh()
    end
end

function UI:Hide()
    if self.frame and not BlockedByCombat() then
        self.frame:Hide()
    end
end

-- Follow the campfire: open when you walk into one (yours or anybody else's),
-- close again when you leave - but only if the panel opened itself, so a panel
-- you opened by hand stays where you put it.
function UI:SyncWithCampfire()
    local nearby = ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA)

    -- The minimap button pulses whatever the auto-show setting says.
    if ns.Minimap and ns.Minimap.SetCampfire then
        ns.Minimap:SetCampfire(nearby == true)
    end

    -- Chime on the way in only. The first reading after login just records
    -- where you are: reloading next to a fire should not ring.
    if nearby == true and self.lastNearby == false and ns.Minimap.Chime then
        ns.Minimap:Chime()
    end
    if nearby ~= nil then
        self.lastNearby = nearby
    end

    if not (self.frame and ns.db and ns.db.settings.autoShow) then
        return
    end

    if nearby == true then
        if not self.frame:IsShown() then
            self.autoShown = true
            self:Show()
        end
    elseif nearby == false and self.autoShown and self.frame:IsShown() then
        self.autoShown = nil
        self:Hide()
    end
end

function UI:Toggle()
    self.autoShown = nil -- opened or closed by hand: stop following the fire
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

local function BuildTooltip(button)
    local info = button.info
    if not info then
        return
    end
    local entry = info.entry

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(entry.itemName or entry.name, 1, 0.82, 0)
    GameTooltip:AddLine(("%s - Tier %d (skill %d)"):format(entry.profession, entry.tier or 1, entry.skill or 0), 0.6, 0.6, 0.6)

    if entry.effect then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(entry.effect, 0.4, 0.9, 0.4, true)
    end
    if entry.exclusive then
        GameTooltip:AddLine("Does not stack with " .. entry.exclusive, 1, 0.5, 0.2, true)
    end

    if #entry.reagents > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Materials:", 1, 1, 1)
        for _, r in ipairs(entry.reagents) do
            local have = r.have or 0
            local need = r.count or 1
            local enough = have >= need
            GameTooltip:AddDoubleLine(
                "  " .. (r.localName or r.name),
                ("%d / %d"):format(have, need),
                1, 1, 1,
                enough and 0.4 or 1, enough and 0.9 or 0.3, enough and 0.4 or 0.3
            )
        end
        if entry.creates and entry.creates > 1 then
            GameTooltip:AddLine(("Creates %d"):format(entry.creates), 0.6, 0.6, 0.6)
        end
    end

    if entry.tools and #entry.tools > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Tool needed:", 1, 1, 1)
        for _, tool in ipairs(entry.tools) do
            local has = (tool.have or 0) >= 1
            GameTooltip:AddDoubleLine(
                "  " .. tool.name,
                has and "carried" or "missing",
                1, 1, 1,
                has and 0.4 or 1, has and 0.9 or 0.3, has and 0.4 or 0.3
            )
        end
    end

    if entry.unconfirmed then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Announced, but not in the game data yet.", 0.6, 0.6, 0.6, true)
    elseif not entry.spellID then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Recipe not identified yet: open your " .. entry.profession
            .. " window once and Fireside reads it from there.", 0.6, 0.6, 0.6, true)
    end

    if info.count > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("In your bags: %d"):format(info.count), 1, 1, 1)
    end

    local covered = UI.coveredBuffs and UI.coveredBuffs[entry.key]
    local benefit = UI.campBenefits and UI.campBenefits[entry.key]
    if covered then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("You already have " .. covered.name .. ": this adds nothing for you.", 1, 0.5, 0.2, true)
    elseif benefit then
        GameTooltip:AddLine(" ")
        local left = benefit.minutesLeft and (" (" .. benefit.minutesLeft .. " min left)") or ""
        GameTooltip:AddLine("Already in your Camp Benefits" .. left .. ".", 1, 0.5, 0.2, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(info.hint or STATUS_HINT[info.status] or "", 0.6, 0.8, 1)
    if info.status == "place" and info.fireNearby == nil then
        GameTooltip:AddLine("(cannot read the Campfire Nearby buff on this client)", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

-- Crafting, as measured on the Forever beta: the recipe cannot be cast from a
-- secure button, not even with /cast, and C_TradeSkillUI.OpenRecipe is
-- protected. What works is C_TradeSkillUI.CraftRecipe called inside a real
-- click while the profession window is open - so that is the only route.

function UI:NoteCastStarted()
    self.lastCastAt = GetTime()
end

-- Placing is a plain item use, as an action bar button does it, addressed by
-- the item name ("item:12345" is a link fragment that neither the secure item
-- attribute nor /use resolves). Many camp objects then ask for a spot on the
-- ground, so the item only leaves the bags after a second click in the world.
-- The check below therefore waits a while and only records what happened.
local PLACE_CHECK_DELAY = 15

function UI:VerifyPlacement(entry, before)
    C_Timer.After(PLACE_CHECK_DELAY, function()
        local after = entry.itemID and ns.API.GetItemCount(entry.itemID) or before
        ns.Probe:LogCraftAttempt(entry, after < before and "placed" or "not-placed",
            ("%d in bags before, %d after %d s"):format(before, after, PLACE_CHECK_DELAY))
        self:Refresh()
    end)
end

-- C_TradeSkillUI.OpenRecipe is protected on this client: calling it only earns
-- an ADDON_ACTION_BLOCKED. So the profession route never opens anything - it
-- crafts when the window is already open, and asks for it when it is not.
--
-- GetAllRecipeIDs keeps answering after the window closes, so it says "open"
-- when nothing is open and the craft then goes nowhere. Blizzard's own frame is
-- the ground truth, with the show/close events as a fallback.
UI.TRADE_SKILL_FRAMES = { "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }

function UI:IsTradeSkillOpen()
    local sawFrame = false
    for _, name in ipairs(self.TRADE_SKILL_FRAMES) do
        local frame = _G[name]
        if frame and frame.IsShown then
            sawFrame = true
            if frame:IsShown() then
                return true
            end
        end
    end
    if sawFrame then
        return false
    end
    return self.tradeSkillOpen == true
end

-- CraftRecipe needs a hardware event: it only works inside the call stack of a
-- real click, which is why every craft goes through here, straight from
-- PostClick, and never from a timer or an event handler.
function UI:CraftNow(entry, source)
    if not entry.spellID then
        ns.Probe:LogCraftAttempt(entry, "no-recipe-id", "nothing harvested for this object yet")
        ns.PrintWarn(entry.name .. ": no recipe id yet - open the profession window once so it can be harvested.")
        return
    end
    if not (C_TradeSkillUI and C_TradeSkillUI.CraftRecipe) then
        ns.Probe:LogCraftAttempt(entry, "craftrecipe-missing", "no CraftRecipe on this client")
        return
    end

    local clickedAt = GetTime()
    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, entry.spellID, 1)
    if not ok then
        ns.Probe:LogCraftAttempt(entry, "craftrecipe-failed", tostring(err))
        ns.PrintWarn("CraftRecipe refused: " .. tostring(err))
        return
    end

    ns.Probe:LogCraftAttempt(entry, "craftrecipe-called", source)
    -- Did anything actually happen? The call returns nothing either way.
    C_Timer.After(1.2, function()
        local started = self.lastCastAt and self.lastCastAt >= clickedAt
        ns.Probe:LogCraftAttempt(entry, started and "craft-started" or "craft-silent", source)
        if not started then
            ns.PrintWarn("Nothing started - is the " .. entry.profession .. " window the one that is open?")
        end
    end)
end

-- Down and up of one click land well inside this; two deliberate clicks don't.
local CLICK_TWIN_WINDOW = 0.6

function UI:GetButton(index)
    local button = self.buttons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", "FiresideButton" .. index, self.frame, "SecureActionButtonTemplate")
    button:SetSize(ICON_SIZE, ICON_SIZE)
    -- Both edges: the secure action only runs on the edge ActionButtonUseKeyDown
    -- picks (key down by default), so an up-only button never places anything.
    -- PostClick filters to that same edge, so a click still acts once.
    button:RegisterForClicks("AnyUp", "AnyDown")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Glow around the icons you can actually click. Gold means "craft this",
    -- green means "place it at the fire", and green pulses because it is the
    -- one action that expires when you walk away from the campsite.
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetPoint("TOPLEFT", -12, 12)
    button.glow:SetPoint("BOTTOMRIGHT", 12, -12)
    button.glow:Hide()

    button.pulse = button.glow:CreateAnimationGroup()
    button.pulse:SetLooping("BOUNCE")
    local fade = button.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.9)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()

    button:SetScript("OnEnter", BuildTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("PostClick", function(self, mouseButton, down)
        -- A click arrives twice (down and up). Act on whichever comes first and
        -- skip its twin: filtering on the "down" argument against the
        -- ActionButtonUseKeyDown CVar dropped both on this client.
        local now = GetTime()
        if self.lastPostClick and (now - self.lastPostClick) < CLICK_TWIN_WINDOW then
            return
        end
        self.lastPostClick = now

        local info = self.info
        if not info then
            return
        end
        ns.Probe:LogCraftAttempt(info.entry, "click", ("status=%s down=%s keydown=%s button=%s"):format(
            tostring(info.status), tostring(down), tostring(ns.API.UseKeyDown()), tostring(mouseButton)))

        if info.status == "place" then
            UI:VerifyPlacement(info.entry, info.count)
            return
        end

        if info.status == "carry" then
            ns.Print(info.hint or "No campfire nearby - light one or find one first.")
            return
        end

        if info.status ~= "craft" then
            return
        end

        local entry = info.entry
        if UI:IsTradeSkillOpen() then
            -- Still inside the click: this is the hardware event CraftRecipe wants.
            UI:CraftNow(entry, "postclick, window open")
        else
            -- The secure action has just tried to open the profession; say
            -- what happened rather than what should have.
            ns.Probe:LogCraftAttempt(entry, "open-profession", entry.profession)
            C_Timer.After(1, function()
                if UI:IsTradeSkillOpen() then
                    ns.Probe:LogCraftAttempt(entry, "profession-opened", entry.profession)
                    ns.Print(ns.Accent(entry.profession) .. " is open - click "
                        .. ns.Accent(entry.itemName or entry.name) .. " again to craft it.")
                else
                    ns.Probe:LogCraftAttempt(entry, "profession-not-opened", entry.profession)
                    ns.Print("Open your " .. ns.Accent(entry.profession) .. " window, then click "
                        .. ns.Accent(entry.itemName or entry.name) .. " again to craft it.")
                end
            end)
        end
    end)

    self.buttons[index] = button
    return button
end

local function ApplySecureAction(button, info)
    if InCombatLockdown() then
        button.pendingUpdate = true
        return
    end
    button.pendingUpdate = nil

    local entry = info.entry
    -- Only "place" gets an item action. "carry" means we know there is no fire
    -- (or, for a kit, that one is too close): using the item would only start
    -- a placement the game then drops without a word, so PostClick explains.
    if info.status == "place" then
        if entry.itemID then
            local name = entry.itemName or ns.API.GetItemName(entry.itemID) or entry.name
            entry.itemName = name
            button:SetAttribute("type", "item")
            button:SetAttribute("item", name)
            button:SetAttribute("spell", nil)
            button:SetAttribute("macrotext", nil)
            return
        end
    elseif info.status == "craft" and not UI:IsTradeSkillOpen() then
        -- Window closed: the click opens the profession, as a "/cast First Aid"
        -- macro would, using the client's own name for it. The craft is the
        -- next click, once the window is up. (An earlier test said this did
        -- not work, but it ran while the button ignored every click.)
        local opener = ns.API.GetProfessionSpells()[string.lower(entry.profession)]
        local localName = ns.API.GetProfessionNameBySkillLine(entry.skillLine)
        if opener and opener.spellID then
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", opener.spellID)
            button:SetAttribute("item", nil)
            button:SetAttribute("macrotext", nil)
            return
        elseif localName then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", "/cast " .. localName)
            button:SetAttribute("item", nil)
            button:SetAttribute("spell", nil)
            return
        end
    end
    -- Craft with the window open: PostClick calls CraftRecipe inside the
    -- click, so the secure action itself does nothing.

    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("macrotext", nil)
end

function UI:GetLabel(index)
    local label = self.labels[index]
    if label then
        return label
    end

    label = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetWidth(LABEL_WIDTH - 6)
    label:SetJustifyH("LEFT")
    self.labels[index] = label
    return label
end

function UI:Refresh()
    if not self.frame or not ns.db then
        return
    end

    ns.Data:ResolveIDs()
    -- No API tells us what is planted at a campsite; the buffs on you do.
    self.campBenefits, self.coveredBuffs, self.campMinutesLeft = ns.Auras:CampBuffState()
    local groups = ns.State:GetGroupedObjects()

    local shown, rows = 0, 0
    for _, group in ipairs(groups) do
        rows = rows + 1
        local rowTop = HEADER + (rows - 1) * (ICON_SIZE + SPACING)

        local label = self:GetLabel(rows)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADDING, -(rowTop + ICON_SIZE / 2 - 8))
        label:SetText(group.profession)
        if group.mine then
            label:SetTextColor(1, 0.82, 0)
        else
            label:SetTextColor(0.5, 0.5, 0.5)
        end
        label:Show()

        for column, info in ipairs(group.items) do
            shown = shown + 1
            local button = self:GetButton(shown)
            button.info = info

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
                PADDING + LABEL_WIDTH + (column - 1) * (ICON_SIZE + SPACING),
                -rowTop)

            button.icon:SetTexture(info.entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            Desaturate(button.icon, info.status == "unknown" or info.status == "mats" or info.status == "cooldown")

            if info.status == "mats" then
                button.icon:SetVertexColor(1, 0.45, 0.45)
                button:SetAlpha(0.95)
            elseif info.status == "unknown" then
                button.icon:SetVertexColor(0.7, 0.7, 0.7)
                button:SetAlpha(0.35)
            elseif info.status == "carry" then
                button.icon:SetVertexColor(0.85, 0.85, 0.85)
                button:SetAlpha(1)
            else
                button.icon:SetVertexColor(1, 1, 1)
                button:SetAlpha(1)
            end

            if info.status == "place" and info.entry.isFire then
                -- A campfire kit can be lit almost anywhere: steady green, so
                -- it does not pulse for the whole journey.
                button.pulse:Stop()
                button.glow:SetVertexColor(0.3, 1, 0.35)
                button.glow:SetAlpha(0.85)
                button.glow:Show()
            elseif info.status == "place" then
                button.glow:SetVertexColor(0.3, 1, 0.35)
                button.glow:SetAlpha(1)
                button.glow:Show()
                if not button.pulse:IsPlaying() then
                    button.pulse:Play()
                end
            elseif info.status == "carry" then
                -- You own it, but there is no fire to place it at: same green,
                -- dimmed and still, so the panel never looks broken.
                button.pulse:Stop()
                button.glow:SetVertexColor(0.3, 1, 0.35)
                button.glow:SetAlpha(0.4)
                button.glow:Show()
            elseif info.status == "craft" then
                button.pulse:Stop()
                button.glow:SetVertexColor(1, 0.82, 0.2)
                button.glow:SetAlpha(1)
                button.glow:Show()
            else
                button.pulse:Stop()
                button.glow:Hide()
            end

            button.count:SetText(info.count > 0 and info.count or "")

            if info.cooldownStart then
                button.cooldown:SetCooldown(info.cooldownStart, info.cooldownDuration)
            else
                button.cooldown:Clear()
            end

            ApplySecureAction(button, info)
            button:Show()
        end
    end

    for index = shown + 1, #self.buttons do
        self.buttons[index]:Hide()
        self.buttons[index].info = nil
    end
    for index = rows + 1, #self.labels do
        self.labels[index]:Hide()
    end

    self.rowsShown = math.max(1, rows)
    self:UpdateFooter()
end

-- Status line under the grid: fire, benefit countdown, what you carry, what is
-- missing. While the Welcoming Campfire wait runs it ticks once a second.
function UI:UpdateFooter()
    if not self.frame then
        return
    end

    local fire = ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA)
    local footer
    if fire == true then
        footer = "|cff40ff40Campfire nearby|r"
    elseif fire == false then
        footer = "No campfire nearby"
    else
        footer = "Campfire state unknown"
    end

    local waiting = ns.Auras:WelcomingSecondsLeft()
    if waiting then
        footer = footer .. "  |cffffd100benefits in " .. waiting .. " s|r"
    end

    -- What your Camp Benefits aura carries. Worded as "yours", not "here":
    -- it lasts an hour after you leave the camp that gave it.
    local carried = {}
    for key in pairs(self.campBenefits or {}) do
        local entry = ns.Data.byKey[key]
        table.insert(carried, entry and (entry.itemName or entry.name) or key)
    end
    if #carried > 0 then
        table.sort(carried)
        local left = self.campMinutesLeft and (" (" .. self.campMinutesLeft .. "m)") or ""
        footer = footer .. "  |cff69ccf0benefits: " .. table.concat(carried, ", ") .. left .. "|r"
    end

    local missing = #ns.State:GetShoppingList()
    if missing > 0 then
        footer = footer .. "  |cffff8000" .. missing .. " material(s) missing|r"
    end

    self.frame.footer:SetText(footer)
    -- The footer wraps once it names objects, so size the panel to the text.
    local rows = self.rowsShown or 1
    local footerHeight = math.max(FOOTER, (self.frame.footer:GetStringHeight() or 0) + 8)
    self.frame:SetHeight(HEADER + rows * ICON_SIZE + (rows - 1) * SPACING + PADDING + footerHeight)

    self:SyncCountdown(waiting)
end

function UI:SyncCountdown(waiting)
    if waiting and not self.countdown then
        self.countdown = C_Timer.NewTicker(1, function()
            if not ns.Auras:WelcomingSecondsLeft() then
                -- The wait is over: the benefits have just landed, so redraw
                -- everything once and stop ticking.
                self.countdown:Cancel()
                self.countdown = nil
                self:Refresh()
            elseif self.frame:IsShown() then
                self:UpdateFooter()
            end
        end)
    elseif not waiting and self.countdown then
        self.countdown:Cancel()
        self.countdown = nil
    end
end

function UI:OnEvent(event, ...)
    if not self.frame then
        return
    end

    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        self.tradeSkillOpen = true
    elseif event == "TRADE_SKILL_CLOSE" then
        self.tradeSkillOpen = false
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" then
            self:NoteCastStarted()
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            self:SyncWithCampfire()
            ns.Auras:Snapshot("unit_aura")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The buff can already be on you when you log in or reload, and no
        -- UNIT_AURA follows for it, so check once the aura data is there.
        C_Timer.After(6, function()
            self:SyncWithCampfire()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.Minimap and ns.Minimap.OnCombatEnd then
            ns.Minimap:OnCombatEnd()
        end
        -- Secure attributes could not be written during combat: redo them now.
        for _, button in ipairs(self.buttons) do
            if button.pendingUpdate and button.info then
                ApplySecureAction(button, button.info)
            end
        end
    end

    if self.frame:IsShown() then
        if self.refreshPending then
            return
        end
        self.refreshPending = true
        C_Timer.After(0.2, function()
            self.refreshPending = nil
            self:Refresh()
        end)
    end
end
