local _, ns = ...

ns.Minimap = ns.Minimap or {}
local MinimapButton = ns.Minimap

-- Same placement model as WarbankValue: Forever's Classic-style minimap draws
-- decorative border art beyond the Minimap frame, so a fixed radius can land
-- on top of it. Dragging sets both the angle and the distance from the centre.
-- Angles are maths-style: 0 is three o'clock and they grow anticlockwise, so
-- the default of 180 puts the button at nine o'clock, on the ring.
local DEFAULT_ANGLE = 180
local ICON = "Interface/Icons/Spell_Fire_Fire" -- the campfire

local function GetMinimapFrameRadius()
    local width = (Minimap and Minimap:GetWidth()) or 140
    if width <= 0 then
        width = 140
    end
    return width / 2
end

local function GetDefaultRadius()
    return GetMinimapFrameRadius() + 10
end

function MinimapButton:Initialize()
    if self.button or not Minimap then
        return
    end

    local settings = ns.db.settings
    settings.minimap = settings.minimap or {}
    if settings.minimap.show == nil then
        settings.minimap.show = true
    end
    settings.minimap.angle = settings.minimap.angle or DEFAULT_ANGLE

    local btn = CreateFrame("Button", "FiresideMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", 0, 1)
    btn.icon = icon

    -- Fire-coloured halo that pulses while a campsite is in range. The round
    -- minimap highlight follows the ring; the action-button border is square
    -- and looked wrong around a round button.
    local glow = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.55, 0.1)
    glow:SetSize(44, 44)
    glow:SetPoint("CENTER", 0, 1)
    glow:Hide()
    btn.glow = glow

    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.15)
    fade:SetDuration(0.6)
    btn.pulse = pulse

    local function UpdatePosition()
        local angle = math.rad(settings.minimap.angle or DEFAULT_ANGLE)
        local radius = settings.minimap.radius or GetDefaultRadius()
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
    self.UpdatePosition = UpdatePosition

    -- Another addon may resize the minimap after us (Leatrix Plus does).
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", UpdatePosition)
    end

    local Atan2 = math.atan2 or math.atan
    local function OnDragUpdate()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local dx, dy = cx - mx, cy - my

        settings.minimap.angle = math.deg(Atan2(dy, dx))

        -- Follow the cursor outwards too, so the button clears the border art,
        -- but keep it close enough to still read as part of the minimap.
        local frameRadius = GetMinimapFrameRadius()
        local radius = math.sqrt(dx * dx + dy * dy)
        settings.minimap.radius = math.max(frameRadius * 0.6, math.min(radius, frameRadius + 60))

        UpdatePosition()
    end

    btn:SetScript("OnDragStart", function(button)
        button:SetScript("OnUpdate", OnDragUpdate)
    end)
    btn:SetScript("OnDragStop", function(button)
        button:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function()
        ns.UI:Toggle()
    end)

    btn:SetScript("OnEnter", function(button)
        MinimapButton:ShowTooltip(button)
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.button = btn
    UpdatePosition()
    self:SetShown(settings.minimap.show)
    self:SetCampfire(ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA) == true)
end

-- Pulse while a campsite is in range, yours or anybody else's.
function MinimapButton:SetCampfire(nearby)
    local btn = self.button
    if not btn then
        return
    end
    if nearby then
        btn.glow:Show()
        if not btn.pulse:IsPlaying() then
            btn.pulse:Play()
        end
    else
        btn.pulse:Stop()
        btn.glow:Hide()
    end
end

-- A double chime when you walk into a campsite's range. Only on the way in,
-- never while you stay, and not again for a minute: walking along the edge of
-- the radius would otherwise flip the buff on and off and ring every time.
-- The gap is wide enough to hear two sounds; at 0.35 s they blurred into one.
local CHIME_COOLDOWN = 60
local CHIME_REPEATS = 2
local CHIME_GAP = 0.8

-- Picked with /fire sound <n>. SOUNDKIT names rather than numbers, so a preset
-- this client lacks is reported instead of playing something random.
MinimapButton.SOUND_PRESETS = {
    { kit = "ALARM_CLOCK_WARNING_3", label = "bell" },
    { kit = "MAP_PING", label = "map ping (quiet)" },
    { kit = "IG_PLAYER_INVITE", label = "invite chime" },
    { kit = "READY_CHECK", label = "ready check (loud)" },
}

function MinimapButton:ResolveSound(index)
    local preset = self.SOUND_PRESETS[index or 1]
    local kit = preset and SOUNDKIT and SOUNDKIT[preset.kit]
    return kit, preset
end

function MinimapButton:PlayChime(force)
    if not ns.db then
        return
    end
    if not force then
        if not ns.db.settings.sound then
            return
        end
        local now = GetTime()
        if self.lastChime and (now - self.lastChime) < CHIME_COOLDOWN then
            return
        end
        self.lastChime = now
    end

    local kit = self:ResolveSound(ns.db.settings.soundPreset)
    kit = kit or (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175
    for index = 1, CHIME_REPEATS do
        C_Timer.After((index - 1) * CHIME_GAP, function()
            pcall(PlaySound, kit, "Master")
        end)
    end
end

function MinimapButton:Chime()
    self:PlayChime(false)
end

function MinimapButton:ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("Fireside", 1, 0.82, 0)

    local fire = ns.API.HasCampfireNearby(ns.Data.CAMPFIRE_AURA)
    if fire == true then
        GameTooltip:AddLine("Campfire nearby", 0.3, 1, 0.3)
    elseif fire == false then
        GameTooltip:AddLine("No campfire nearby", 0.6, 0.6, 0.6)
    end
    local waiting = ns.Auras:WelcomingSecondsLeft()
    if waiting then
        GameTooltip:AddLine("Camp benefits in " .. waiting .. " s", 1, 0.82, 0)
    end

    -- Same counts the panel works from, so the two never disagree.
    local ready, craftable = 0, 0
    for _, info in ipairs(ns.State:GetVisibleObjects()) do
        if info.status == "place" or info.status == "carry" then
            ready = ready + 1
        elseif info.status == "craft" then
            craftable = craftable + 1
        end
    end
    local missing = #ns.State:GetShoppingList()

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("In your bags", tostring(ready), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Craftable now", tostring(craftable), 1, 1, 1, 1, 1, 1)
    if missing > 0 then
        GameTooltip:AddDoubleLine("Materials missing", tostring(missing), 1, 1, 1, 1, 0.5, 0.1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to toggle the panel, drag to move", 0, 1, 0)
    GameTooltip:Show()
end

function MinimapButton:SetShown(show)
    if ns.db and ns.db.settings then
        ns.db.settings.minimap = ns.db.settings.minimap or {}
        ns.db.settings.minimap.show = show and true or false
    end
    if self.button then
        if show then
            self.button:Show()
        else
            self.button:Hide()
        end
    end
end

function MinimapButton:ResetPosition()
    if ns.db and ns.db.settings and ns.db.settings.minimap then
        ns.db.settings.minimap.angle = DEFAULT_ANGLE
        ns.db.settings.minimap.radius = nil
    end
    if self.UpdatePosition then
        self.UpdatePosition()
    end
end
