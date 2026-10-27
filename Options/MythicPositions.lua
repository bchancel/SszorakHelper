local SH = _G.SszorakHelper
if not SH then return end
local M = SH.MythicPositions
local UI = {buttons = {}, candidates = {}}
SH.MythicPositionsUI = UI
local WIDTH, HEIGHT = 500, 500 * 1380 / 1456
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local roles = {DAMAGER = "Damage soak", TANK = "Tank soak", HEALER = "Healer - does not soak"}
local function positionRole(slot)
    return slot == M.BAIT_SLOT and "Serpent's Fury bait" or roles[M:Role(slot)]
end

local function text(parent, value, x, y)
    local label = SH.Widgets:Label(parent, value)
    label:SetPoint("TOPLEFT", x, y)
    return label
end
local function circle(parent, size, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(CIRCLE)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    return texture
end
local function enable(button, enabled)
    button._shEnabledStyle = button._shEnabledStyle or button._shStyle or "secondary"
    SH.Widgets:SetEnabled(button, enabled)
end
local function abbreviation(name)
    local result, count = "", 0
    for char in (name:match("^[^-]+") or name):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        result, count = result .. char, count + 1
        if count == 4 then break end
    end
    return result
end

function UI:Create(options)
    self.options = options
    local page = CreateFrame("Frame", nil, options.frame)
    page:SetPoint("TOPLEFT", options.header, "BOTTOMLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", -28, 16)
    page:Hide()
    self.page = page
    text(page, "Position profile", 18, -10)
    self.selector = SH.Widgets:Button(page, "", 500, 30, function() UI.profileMenu:SetShown(not UI.profileMenu:IsShown()) end, "secondary")
    self.selector:SetPoint("TOPLEFT", 18, -31)
    self.selector.text:ClearAllPoints()
    self.selector.text:SetPoint("LEFT", 12, 0)
    local new = SH.Widgets:Button(page, "New", 68, 30, function()
        if not M:CanEdit() then return end
        options:ShowProfileNameDialog("New position profile", "", function(name)
            local id, reason = M:NewProfile(name, UI.draft and UI.draft.slots)
            if id then UI:LoadDraft(); return true end
            return false, reason
        end)
    end, "success")
    new:SetPoint("LEFT", self.selector, "RIGHT", 8, 0)
    local rename = SH.Widgets:Button(page, "Rename", 88, 30, function()
        if not M:CanEdit() then return end
        options:ShowProfileNameDialog("Rename position profile", M:GetProfile().name, function(name)
            local ok, reason = M:RenameProfile(name)
            if ok then UI:Refresh() end
            return ok, reason
        end)
    end, "secondary")
    rename:SetPoint("LEFT", new, "RIGHT", 6, 0)
    self.profileControls = {self.selector, new, rename}
    local menu = CreateFrame("Frame", nil, page, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", self.selector, "BOTTOMLEFT", 0, -3)
    menu:SetSize(500, 310)
    menu:SetFrameLevel(page:GetFrameLevel() + 30)
    menu:EnableMouse(true)
    SH.Widgets:ApplyBackdrop(menu, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    menu:Hide()
    self.profileMenu, self.profileButtons = menu, {}
    for i = 1, 10 do
        local index = i
        local button = SH.Widgets:Button(menu, "", 488, 28, function()
            local profile = M.db.profiles[index]
            if profile and M:SelectProfile(profile.id) then UI:LoadDraft() end
            menu:Hide()
        end, "secondary")
        button:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 30)
        self.profileButtons[i] = button
    end

    self.hint = text(page, "Click a circle to assign a player.", 18, -75)
    self.move = SH.Widgets:Button(page, "Move Circles", 112, 26, function()
        if not M:CanEdit() then return end
        UI.moving = not UI.moving
        UI.picker:Hide()
        UI:Refresh()
    end, "secondary")
    self.move:SetPoint("TOPRIGHT", -12, -68)
    local board = SH.Widgets:Section(page, "Mythic positions", 530)
    board:SetPoint("TOPLEFT", 18, -100)
    board:SetPoint("TOPRIGHT", -8, -100)
    SH.Widgets:ApplyBackdrop(board, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.border)
    self.count = text(board, "", 210, -8)
    text(board, "14 damage / 2 tanks / 4 healers", 410, -8)
    local room = CreateFrame("Frame", nil, board)
    room:SetSize(WIDTH, HEIGHT)
    room:SetPoint("TOP", 0, -34)
    room.texture = room:CreateTexture(nil, "BACKGROUND")
    room.texture:SetAllPoints(room)
    room.texture:SetTexture("Interface\\AddOns\\SszorakHelper_Options\\Media\\MarkerLayoutRoom.tga")
    room.texture:SetTexCoord(0, 1456 / 2048, 0, 1380 / 2048)
    self.room = room
    local exit = SH.Widgets:Label(room, "EXIT")
    exit:SetPoint("TOP", 0, -7)
    local entrance = SH.Widgets:Label(room, "ENTRANCE")
    entrance:SetPoint("BOTTOM", 0, 1)
    text(board, "Healers: positioning only. Shield: tank soak. Class color: assigned player.", 10, -512)

    local boss = room:CreateTexture(nil, "ARTWORK")
    boss:SetSize(30, 30)
    boss:SetPoint("CENTER", room, "TOPLEFT", WIDTH * 0.5, -HEIGHT * 0.825)
    boss:SetTexture(7966619)
    local mask = room:CreateMaskTexture()
    mask:SetAllPoints(boss)
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    boss:AddMaskTexture(mask)
    self.boss = boss
    for i = 1, 20 do
        local slot = i
        local button = CreateFrame("Button", nil, room)
        button:SetSize(32, 32)
        button:RegisterForDrag("LeftButton")
        button.outline = circle(button, 36)
        button.fill = circle(button, 32)
        button.label = SH.Widgets:Text(button, "")
        button.label:SetPoint("CENTER")
        button.label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        button.number = SH.Widgets:Text(button, M:DisplayNumber(i) and tostring(M:DisplayNumber(i)) or "")
        button.number:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        button.number:SetPoint("TOPLEFT", -5, 5)
        if slot == M.BAIT_SLOT then
            button.bait = SH.Widgets:Text(button, M:DisplayNumber(slot) .. " - FURY BAIT")
            button.bait:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
            button.bait:SetPoint("BOTTOM", button, "TOP", 0, 4)
            button.bait:SetTextColor(1, 0.82, 0.3, 1)
        end
        button.role = button:CreateTexture(nil, "OVERLAY")
        button.role:SetSize(14, 14)
        button.role:SetPoint("BOTTOMRIGHT", 4, -3)
        button:SetScript("OnClick", function()
            if UI.dragged == slot then UI.dragged = nil; return end
            if not M:CanEdit() or not UI.draft then return end
            UI.selected = slot
            if not UI.moving then UI.picker:Show() end
            UI:Refresh()
        end)
        button:SetScript("OnEnter", function(owner)
            local member = UI.draft and UI.draft.slots[slot].member
            local message = positionRole(slot) .. (slot == M.BAIT_SLOT and " (next cast)" or "") .. "\n" .. (member and member.name or "Unassigned")
            if UI.draft and UI.draft.previous[slot] and not member then message = message .. "\nPreviously: " .. UI.draft.previous[slot] end
            SH.Widgets:ShowTooltip(owner, message, M:PositionLabel(slot))
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnDragStart", function(owner)
            if not UI.moving or not M:CanEdit() or not UI.draft then return end
            UI.dragged, UI.dragging = slot, slot
            UI.picker:Hide()
            GameTooltip:Hide()
            owner:SetScript("OnUpdate", function()
                if not M:CanEdit() then UI:StopDrag(); return end
                local x, y = GetCursorPosition()
                local scale = room:GetEffectiveScale()
                local left, top = room:GetLeft(), room:GetTop()
                if not left or not top then return end
                UI:SetPosition(slot, (x / scale - left) / WIDTH, (top - y / scale) / HEIGHT)
            end)
        end)
        button:SetScript("OnDragStop", function() UI:StopDrag() end)
        self.buttons[i] = button
    end

    local preview = CreateFrame("Frame", nil, page)
    preview:SetSize(54, 54)
    preview:SetPoint("TOPLEFT", 22, -638)
    preview.edges = {}
    for i = 1, 8 do
        local a, b = (i - 1) * math.pi / 4, i * math.pi / 4
        local line = preview:CreateLine(nil, "BACKGROUND")
        line:SetThickness(1)
        line:SetColorTexture(unpack(SH.Widgets.colors.borderStrong))
        line:SetStartPoint("CENTER", preview, "CENTER", math.sin(a) * 25, math.cos(a) * 25)
        line:SetEndPoint("CENTER", preview, "CENTER", math.sin(b) * 25, math.cos(b) * 25)
        preview.edges[i] = line
    end
    preview.markers = {}
    for i = 1, 8 do
        local marker = preview:CreateTexture(nil, "ARTWORK")
        marker:SetSize(10, 10)
        local angle = (i - 1) * math.pi / 4
        marker:SetPoint("CENTER", math.sin(angle) * 23, math.cos(angle) * 23)
        preview.markers[i] = marker
    end
    preview.dot = circle(preview, 7, "OVERLAY")
    preview.dot:SetVertexColor(0.1, 1, 0.25, 1)
    self.preview = preview
    text(page, "Room mini map preview", 94, -645)
    text(page, "Display settings: Configuration > Room Mini Map gear", 94, -660)
    self.status = text(page, "", 94, -674)
    self.status:SetWidth(600)
    self.status:SetFont(STANDARD_TEXT_FONT, 11)
    self.save = SH.Widgets:Button(page, "Save Positions", 146, 30, function()
        local ok, reason = M:Save(UI.draft)
        UI.message = ok and "Names and circle positions saved." or reason
        if ok then UI.dirty = false end
        UI:Refresh()
    end, "success")
    self.save:SetPoint("BOTTOMLEFT", 22, 0)
    self.revert = SH.Widgets:Button(page, "Revert", 90, 30, function() if M:CanEdit() then UI:LoadDraft() end end, "secondary")
    self.revert:SetPoint("LEFT", self.save, "RIGHT", 8, 0)
    self.publish = SH.Widgets:Button(page, "Publish Positions", 156, 30, function()
        local ok, reason = M:Publish(UI.draft)
        UI.message = ok and "Publishing positions to the raid..." or reason
        if ok then UI.dirty = false end
        UI:Refresh()
    end, "success")
    self.publish:SetPoint("BOTTOMRIGHT", -12, 0)
    self.publish.tooltip = "Raid leader only. Saves and publishes names and circle locations before combat."
    self:CreatePicker()
    page:SetScript("OnHide", function() UI:StopDrag(); UI.picker:Hide(); menu:Hide(); UI.moving = false end)
    return page
end

function UI:CreatePicker()
    local picker = CreateFrame("Frame", nil, self.page, "BackdropTemplate")
    picker:SetSize(250, 320)
    picker:SetPoint("TOPRIGHT", self.room, "TOPRIGHT", -8, -24)
    picker:SetFrameLevel(self.page:GetFrameLevel() + 20)
    picker:EnableMouse(true)
    SH.Widgets:ApplyBackdrop(picker, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    picker:Hide()
    self.picker = picker
    self.pickerTitle = text(picker, "", 12, -12)
    self.pickerPrevious = text(picker, "", 12, -36)
    self.pickerPrevious:SetWidth(226)
    self.pickerPrevious:SetFont(STANDARD_TEXT_FONT, 11)
    local close = SH.Widgets:Button(picker, "x", 22, 22, function() picker:Hide() end, "secondary")
    close:SetPoint("TOPRIGHT", -6, -6)
    local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -74)
    scroll:SetPoint("BOTTOMRIGHT", -28, 48)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(210, 1)
    scroll:SetScrollChild(content)
    self.candidateContent = content
    self.clear = SH.Widgets:Button(picker, "Clear Position", 140, 28, function()
        if M:Assign(UI.draft, UI.selected, nil) then UI.dirty = true; UI:Refresh() end
    end, "secondary")
    self.clear:SetPoint("BOTTOMLEFT", 10, 10)
    self.noCandidates = text(content, "No unassigned players for this role.", 0, 0)
    self.noCandidates:SetWidth(205)
end

function UI:Open()
    local draft, reason = M:OpenDraft()
    if not draft then self.message = reason; self:Refresh(); return end
    self.draft, self.dirty, self.selected, self.moving, self.message = draft, false, nil, false, nil
    self.picker:Hide()
    self.profileMenu:Hide()
    M:RefreshPersonal()
    self:Refresh()
end
function UI:LoadDraft()
    self:StopDrag()
    self.draft, self.dirty, self.selected, self.message = M:DraftFromSnapshot(), false, nil, nil
    self.picker:Hide()
    self:Refresh()
end
function UI:SetPosition(slot, x, y)
    if not M:CanEdit() or not self.draft then return false end
    local point = self.draft.slots[slot]
    if not point then return false end
    point.x, point.y = math.max(0.04, math.min(0.96, x)), math.max(0.04, math.min(0.96, y))
    self.dirty = true
    self:PositionButton(slot)
    return true
end
function UI:PositionButton(slot)
    local point = self.draft.slots[slot]
    self.buttons[slot]:ClearAllPoints()
    self.buttons[slot]:SetPoint("CENTER", self.room, "TOPLEFT", point.x * WIDTH, -point.y * HEIGHT)
end
function UI:StopDrag()
    local slot = self.dragging
    if slot then
        self.buttons[slot]:SetScript("OnUpdate", nil)
        -- Swallow only the click belonging to this drag, not the next real click.
        C_Timer.After(0, function() if UI.dragged == slot then UI.dragged = nil end end)
    end
    self.dragging = nil
end
function UI:LockForCombat()
    self:StopDrag()
    self.moving = false
    if self.picker then self.picker:Hide(); self.profileMenu:Hide(); self:Refresh() end
end
function UI:Received()
    if self.page and self.page:IsShown() then
        if self.dirty then
            self.message = "Raid positions received; your unsaved edits are kept. Revert to view the raid plan."
        else
            self:LoadDraft()
            self.message = "Raid positions received from " .. M.received.sender .. "."
        end
        self:Refresh()
    end
end
function UI:PublicationFinished(ok, reason)
    self.message = reason or (ok and "Positions received by another addon user." or "Publication cancelled.")
    self:Refresh()
end
function UI:Refresh()
    if not self.page then return end
    local editable = M:CanEdit()
    local profile = M:GetProfile()
    self.selector.text:SetText(profile.name)
    for i, button in ipairs(self.profileButtons) do
        local p = M.db.profiles[i]
        button:SetShown(p ~= nil)
        if p then button.text:SetText(p.name); enable(button, editable) end
    end
    self.profileMenu:SetHeight(12 + #M.db.profiles * 30)
    for _, button in ipairs(self.profileControls) do enable(button, editable) end
    enable(self.profileControls[2], editable and #M.db.profiles < 10)
    for _, button in ipairs({self.move, self.save, self.revert}) do enable(button, editable and self.draft ~= nil) end
    enable(self.publish, editable and self.draft ~= nil and IsInRaid() and UnitIsGroupLeader("player") and not M.publishing)
    self.move.text:SetText(self.moving and "Lock Circles" or "Move Circles")
    self.hint:SetText(self.moving and "Drag circles to adjust their floor positions." or "Click a circle to assign a player.")
    local layout = SH.Store:GetLayout()
    for i, marker in ipairs(self.preview.markers) do marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. layout[i]) end
    local personal = M.personal
    self.preview.dot:SetShown(SH.Store:Options().showMythicPosition and personal ~= nil)
    if personal then
        local x, y = SH.RoomMap:GetSpreadPoint(personal)
        self.preview.dot:ClearAllPoints()
        self.preview.dot:SetPoint("CENTER", self.preview, "CENTER", (x - 0.5) * 50, (0.5 - y) * 50)
    end
    if not self.draft then self.status:SetText(self.message or "Reopen this tab outside combat."); return end
    local count = 0
    for i, button in ipairs(self.buttons) do
        local member, role = self.draft.slots[i].member, M:Role(i)
        if member then count = count + 1 end
        local color = member and RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
        button.fill:SetVertexColor(color and color.r or 0.05, color and color.g or 0.1, color and color.b or 0.14, 1)
        button.outline:SetVertexColor(unpack(self.selected == i and SH.Widgets.colors.accentBright or member and SH.Widgets.colors.textSecondary or SH.Widgets.colors.navigation))
        button.label:SetText(member and abbreviation(member.name) or role == "TANK" and "" or "+")
        button.label:SetTextColor(member and 0 or 1, member and 0 or 1, member and 0 or 1)
        button.number:SetShown(M:DisplayNumber(i) ~= nil and i ~= M.BAIT_SLOT)
        button.role:SetShown(role ~= "DAMAGER")
        if role ~= "DAMAGER" then
            button.role:SetAtlas(role == "TANK" and "roleicon-tiny-tank" or "roleicon-tiny-healer")
            button.role:ClearAllPoints()
            if role == "TANK" and not member then button.role:SetSize(22, 22); button.role:SetPoint("CENTER")
            else button.role:SetSize(14, 14); button.role:SetPoint("BOTTOMRIGHT", 4, -3) end
        end
        self:PositionButton(i)
    end
    self.count:SetText(count .. " / 20 assigned")
    local source = M.received and ("Received from " .. M.received.sender) or ("Static position: " .. (personal and M:PositionLabel(personal.slot) or "unassigned"))
    self.status:SetText(not editable and "Combat: editing locked. Reopen the tab after combat to refresh the raid."
        or self.message or (self.dirty and "Unsaved changes." or (source .. " - " .. (20 - count) .. " empty")))
    if not self.selected or not self.picker:IsShown() then return end
    local number = M:DisplayNumber(self.selected)
    self.pickerTitle:SetText((number and ("Position " .. number .. " - ") or "") .. positionRole(self.selected))
    self.pickerTitle:SetWidth(205)
    local point = self.draft.slots[self.selected]
    self.pickerPrevious:SetText(point.member and point.member.name or self.draft.previous[self.selected] and ("Absent: " .. self.draft.previous[self.selected]) or "Unassigned raid members only")
    local candidates = M:Candidates(self.draft, self.selected)
    for i, member in ipairs(candidates) do
        local button = self.candidates[i]
        if not button then
            button = SH.Widgets:Button(self.candidateContent, "", 208, 34, function(owner)
                if M:Assign(UI.draft, UI.selected, owner.memberName) then UI.dirty = true; UI.message = nil; UI.picker:Hide(); UI:Refresh() end
            end, "secondary")
            button:SetPoint("TOPLEFT", 0, -(i - 1) * 38)
            button.text:SetWidth(194)
            button.text:SetFont(STANDARD_TEXT_FONT, 11)
            button:SetScript("OnLeave", function(owner)
                SH.Widgets:StyleButton(owner, owner:IsEnabled() and "secondary" or "disabled")
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[owner.memberClass]
                owner.text:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
                GameTooltip:Hide()
            end)
            self.candidates[i] = button
        end
        button.memberName = member.name
        button.memberClass = member.class
        button.text:SetText(member.name)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
        button:Show()
        enable(button, editable)
        button.text:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
    end
    for i = #candidates + 1, #self.candidates do self.candidates[i]:Hide() end
    self.noCandidates:SetShown(#candidates == 0)
    self.candidateContent:SetHeight(math.max(38, #candidates * 38))
    enable(self.clear, editable and point.member ~= nil)
end
