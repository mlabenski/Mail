-- MailboxGrid.lua
local addonName, addon = ...
local MailboxGrid = CreateFrame("Frame", "MailboxGridFrame", UIParent)

-- Initialize variables
local ITEMS_PER_ROW = 8
local BUTTON_SIZE = 37
local BUTTON_SPACING = 4
local MAX_ITEMS = 18 -- Classic mailbox limit

-- Create the main frame
MailboxGrid:SetWidth((BUTTON_SIZE + BUTTON_SPACING) * ITEMS_PER_ROW)
MailboxGrid:SetHeight((BUTTON_SIZE + BUTTON_SPACING) * math.ceil(MAX_ITEMS / ITEMS_PER_ROW))
MailboxGrid:SetPoint("CENTER", UIParent, "CENTER")
MailboxGrid:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

-- Create title
local title = MailboxGrid:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", MailboxGrid, "TOPLEFT", 16, -16)
title:SetText("Mailbox Contents")

-- Create close button
local closeButton = CreateFrame("Button", nil, MailboxGrid, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", MailboxGrid, "TOPRIGHT", -5, -5)

-- Create item buttons
local buttons = {}
for i = 1, MAX_ITEMS do
    local button = CreateFrame("Button", "MailboxGridButton"..i, MailboxGrid)
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    
    local row = math.floor((i-1) / ITEMS_PER_ROW)
    local col = (i-1) % ITEMS_PER_ROW
    
    button:SetPoint("TOPLEFT", MailboxGrid, "TOPLEFT", 
        16 + col * (BUTTON_SIZE + BUTTON_SPACING),
        -40 - row * (BUTTON_SIZE + BUTTON_SPACING))
    
    -- Create button textures
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    
    -- Create count text
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    
    -- Add tooltip functionality
    button:SetScript("OnEnter", function(self)
        if self.mailIndex then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount = GetInboxHeaderInfo(self.mailIndex)
            if sender and subject then
                GameTooltip:AddLine(subject)
                GameTooltip:AddLine("From: " .. sender)
                if money > 0 then
                    GameTooltip:AddLine("Money: " .. GetCoinTextureString(money))
                end
                if itemCount and itemCount > 0 then
                    for j = 1, ATTACHMENTS_MAX_RECEIVE do
                        local name, itemID, texture, count = GetInboxItem(self.mailIndex, j)
                        if name then
                            GameTooltip:AddLine(name .. (count > 1 and " x"..count or ""))
                        end
                    end
                end
                GameTooltip:Show()
            end
        end
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    buttons[i] = button
end

-- Function to update the grid
local function UpdateGrid()
    for i = 1, MAX_ITEMS do
        local button = buttons[i]
        button.mailIndex = nil
        button.icon:SetTexture(nil)
        button.count:SetText("")
        
        local index = i
        if HasInboxItem(index) then
            button.mailIndex = index
            local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount = GetInboxHeaderInfo(index)
            if itemCount and itemCount > 0 then
                local name, itemID, texture, count = GetInboxItem(index, 1)
                if texture then
                    button.icon:SetTexture(texture)
                    if count > 1 then
                        button.count:SetText(count)
                    end
                end
            elseif money > 0 then
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            end
        end
    end
end

-- Event handling
MailboxGrid:RegisterEvent("MAIL_SHOW")
MailboxGrid:RegisterEvent("MAIL_INBOX_UPDATE")
MailboxGrid:RegisterEvent("MAIL_CLOSED")

MailboxGrid:SetScript("OnEvent", function(self, event, ...)
    if event == "MAIL_SHOW" then
        self:Show()
        UpdateGrid()
    elseif event == "MAIL_INBOX_UPDATE" then
        UpdateGrid()
    elseif event == "MAIL_CLOSED" then
        self:Hide()
    end
end)

-- Make frame movable
MailboxGrid:SetMovable(true)
MailboxGrid:EnableMouse(true)
MailboxGrid:RegisterForDrag("LeftButton")
MailboxGrid:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
MailboxGrid:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Hide by default
MailboxGrid:Hide()
