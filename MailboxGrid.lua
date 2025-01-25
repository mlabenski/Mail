-- MailboxGrid.lua
local addonName, addon = ...

-- Logging system
local DEBUG_MODE = true
local LogLevel = {
    DEBUG = 1,
    INFO = 2,
    ERROR = 3
}

local function Logger(level, message, ...)
    if not DEBUG_MODE and level == LogLevel.DEBUG then return end
    
    local timestamp = date("%H:%M:%S")
    local levelString = level == LogLevel.DEBUG and "DEBUG" or level == LogLevel.INFO and "INFO" or "ERROR"
    local color = level == LogLevel.DEBUG and "999999" or level == LogLevel.INFO and "00ff00" or "ff0000"
    
    -- Format the message with any additional parameters
    local formattedMessage = string.format(message, ...)
    
    -- Create the log entry
    local logEntry = string.format("|cff%s[MailboxGrid][%s][%s]: %s|r", 
        color, timestamp, levelString, formattedMessage)
    
    -- Print to chat frame and store in our log history
    DEFAULT_CHAT_FRAME:AddMessage(logEntry)
    
    -- Store logs in SavedVariables for persistent logging
    if not MailboxGridLogs then
        MailboxGridLogs = {}
    end
    table.insert(MailboxGridLogs, string.format("[%s][%s]: %s", timestamp, levelString, formattedMessage))
    
    -- Keep only the last 100 log entries
    while #MailboxGridLogs > 100 do
        table.remove(MailboxGridLogs, 1)
    end
end

local function Debug(message, ...) Logger(LogLevel.DEBUG, message, ...) end
local function Info(message, ...) Logger(LogLevel.INFO, message, ...) end
local function Error(message, ...) Logger(LogLevel.ERROR, message, ...) end

-- Version checking with logging
local _, _, _, tocversion = GetBuildInfo()
if tocversion < 11400 then
    Error("MailboxGrid requires WoW Classic client (found version: %s)", tocversion)
    return
end

Debug("Initializing MailboxGrid addon...")

local MailboxGrid = CreateFrame("Frame", "MailboxGridFrame", UIParent)

-- Initialize variables
local ITEMS_PER_ROW = 8
local BUTTON_SIZE = 37
local BUTTON_SPACING = 4
local MAX_ITEMS = 18
local buttons = {}

-- Utility function for safer API calls with logging
local function SafeGetInboxItem(index, attachIndex)
    Debug("Attempting to get inbox item - Index: %d, AttachIndex: %d", index, attachIndex)
    
    if not index or not attachIndex then
        Error("Invalid parameters for SafeGetInboxItem - Index: %s, AttachIndex: %s", 
            tostring(index), tostring(attachIndex))
        return
    end
    
    local success, name, itemID, texture, count = pcall(function()
        return GetInboxItem(index, attachIndex)
    end)
    
    if success then
        Debug("Successfully retrieved item - Name: %s, ID: %s, Count: %d", 
            tostring(name), tostring(itemID), count or 0)
        return name, itemID, texture, count
    else
        Error("Failed to get inbox item - Error: %s", tostring(name))
        return nil, nil, nil, 0
    end
end

-- Create main frame with logging
Debug("Creating main frame...")
MailboxGrid:SetWidth((BUTTON_SIZE + BUTTON_SPACING) * ITEMS_PER_ROW)
MailboxGrid:SetHeight((BUTTON_SIZE + BUTTON_SPACING) * math.ceil(MAX_ITEMS / ITEMS_PER_ROW))
MailboxGrid:SetPoint("CENTER", UIParent, "CENTER")

-- Check if SetBackdrop is available (API changed in some versions)
if MailboxGrid.SetBackdrop then
    MailboxGrid:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    Debug("SetBackdrop succeeded")
else
    Error("SetBackdrop not available - might need to use BackdropTemplate")
    local backdrop = CreateFrame("Frame", nil, MailboxGrid, "BackdropTemplate")
    backdrop:SetAllPoints()
    backdrop:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
end

-- Create title
local title = MailboxGrid:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", MailboxGrid, "TOPLEFT", 16, -16)
title:SetText("Mailbox Contents")

-- Create close button
local closeButton = CreateFrame("Button", nil, MailboxGrid, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", MailboxGrid, "TOPRIGHT", -5, -5)

-- Create item buttons with logging
Debug("Creating item buttons...")
for i = 1, MAX_ITEMS do
    local button = CreateFrame("Button", "MailboxGridButton"..i, MailboxGrid)
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    
    local row = math.floor((i-1) / ITEMS_PER_ROW)
    local col = (i-1) % ITEMS_PER_ROW
    
    button:SetPoint("TOPLEFT", MailboxGrid, "TOPLEFT", 
        16 + col * (BUTTON_SIZE + BUTTON_SPACING),
        -40 - row * (BUTTON_SIZE + BUTTON_SPACING))
    
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    
    button:SetScript("OnEnter", function(self)
        if self.mailIndex then
            Debug("Showing tooltip for mail index: %d", self.mailIndex)
            local success, packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount = pcall(function()
                return GetInboxHeaderInfo(self.mailIndex)
            end)
            
            if success and sender and subject then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(subject)
                GameTooltip:AddLine("From: " .. sender)
                if money and money > 0 then
                    GameTooltip:AddLine("Money: " .. GetCoinTextureString(money))
                end
                if itemCount and itemCount > 0 then
                    for j = 1, ATTACHMENTS_MAX_RECEIVE do
                        local name, _, _, count = SafeGetInboxItem(self.mailIndex, j)
                        if name then
                            GameTooltip:AddLine(name .. (count > 1 and " x"..count or ""))
                        end
                    end
                end
                GameTooltip:Show()
            else
                Error("Failed to get mail info - Index: %d", self.mailIndex)
            end
        end
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    buttons[i] = button
    Debug("Created button %d", i)
end

-- Function to update the grid with logging
local function UpdateGrid()
    Debug("UpdateGrid called")
    for i = 1, MAX_ITEMS do
        local button = buttons[i]
        button.mailIndex = nil
        button.icon:SetTexture(nil)
        button.count:SetText("")
        
        local index = i
        local success, hasItem = pcall(function()
            return HasInboxItem(index)
        end)
        
        if success and hasItem then
            Debug("Mail item found at index: %d", index)
            button.mailIndex = index
            local headerSuccess, packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount = pcall(function()
                return GetInboxHeaderInfo(index)
            end)
            
            if headerSuccess then
                if itemCount and itemCount > 0 then
                    local name, itemID, texture, count = SafeGetInboxItem(index, 1)
                    if texture then
                        button.icon:SetTexture(texture)
                        if count and count > 1 then
                            button.count:SetText(count)
                        end
                        Debug("Updated button %d with item: %s (x%d)", i, name or "unknown", count or 1)
                    end
                elseif money and money > 0 then
                    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
                    Debug("Updated button %d with money: %d copper", i, money)
                end
            else
                Error("Failed to get mail header info for index: %d", index)
            end
        end
    end
end

-- Event handling with logging
MailboxGrid:RegisterEvent("MAIL_SHOW")
MailboxGrid:RegisterEvent("MAIL_INBOX_UPDATE")
MailboxGrid:RegisterEvent("MAIL_CLOSED")
MailboxGrid:RegisterEvent("ADDON_LOADED")

MailboxGrid:SetScript("OnEvent", function(self, event, ...)
    Debug("Event fired: %s", event)
    if event == "ADDON_LOADED" and ... == addonName then
        Info("MailboxGrid addon loaded successfully")
    elseif event == "MAIL_SHOW" then
        self:Show()
        Info("Mailbox opened - updating grid")
        UpdateGrid()
    elseif event == "MAIL_INBOX_UPDATE" then
        Info("Mail inbox updated - refreshing grid")
        UpdateGrid()
    elseif event == "MAIL_CLOSED" then
        Info("Mailbox closed - hiding grid")
        self:Hide()
    end
end)

-- Make frame movable
MailboxGrid:SetMovable(true)
MailboxGrid:EnableMouse(true)
MailboxGrid:RegisterForDrag("LeftButton")
MailboxGrid:SetScript("OnDragStart", function(self)
    Debug("Started moving frame")
    self:StartMoving()
end)
MailboxGrid:SetScript("OnDragStop", function(self)
    Debug("Stopped moving frame")
    self:StopMovingOrSizing()
end)

-- Slash command for debugging
SLASH_MAILBOXGRID1 = "/mbg"
SLASH_MAILBOXGRID2 = "/mailboxgrid"
SlashCmdList["MAILBOXGRID"] = function(msg)
    if msg == "debug" then
        DEBUG_MODE = not DEBUG_MODE
        Info("Debug mode: " .. (DEBUG_MODE and "enabled" or "disabled"))
    elseif msg == "logs" then
        Info("Recent logs:")
        for i, log in ipairs(MailboxGridLogs or {}) do
            print(log)
        end
    elseif msg == "clear" then
        MailboxGridLogs = {}
        Info("Logs cleared")
    else
        Info("MailboxGrid commands:")
        Info("/mbg debug - Toggle debug mode")
        Info("/mbg logs - Show recent logs")
        Info("/mbg clear - Clear logs")
    end
end

-- Hide by default
MailboxGrid:Hide()

Debug("MailboxGrid initialization complete")