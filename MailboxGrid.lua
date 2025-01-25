-- MailboxGrid.lua
local addonName, addon = ...

-- Constants for UI layout and styling
local ITEMS_PER_ROW = 12
local BUTTON_SIZE = 37
local BUTTON_SPACING = 2
local SCROLLBAR_WIDTH = 16
local PADDING = 12
local MAX_VISIBLE_ROWS = 5  -- Keep frame height reasonable
local FRAME_WIDTH = (BUTTON_SIZE + BUTTON_SPACING) * ITEMS_PER_ROW + PADDING * 2 + SCROLLBAR_WIDTH

-- Create main frame with proper strata and parent
local MailboxGrid = CreateFrame("Frame", "MailboxGridFrame", UIParent, "BackdropTemplate")
MailboxGrid:SetFrameStrata("HIGH")
MailboxGrid:SetWidth(FRAME_WIDTH)
MailboxGrid:SetHeight((BUTTON_SIZE + BUTTON_SPACING) * MAX_VISIBLE_ROWS + 45)
MailboxGrid:SetPoint("CENTER")

-- Apply professional backdrop styling
MailboxGrid:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileEdge = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
MailboxGrid:SetBackdropColor(0, 0, 0, 0.9)

-- Create header container
local headerContainer = CreateFrame("Frame", nil, MailboxGrid)
headerContainer:SetPoint("TOPLEFT", 12, -12)
headerContainer:SetPoint("TOPRIGHT", -12, -12)
headerContainer:SetHeight(24)

-- Create title with proper WoW styling
local title = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT")
title:SetText("Mailbox Contents")
title:SetTextColor(1, 0.82, 0)

-- Create search box
local searchBox = CreateFrame("EditBox", nil, headerContainer, "SearchBoxTemplate")
searchBox:SetSize(150, 20)
searchBox:SetPoint("TOPRIGHT")
searchBox:SetAutoFocus(false)
searchBox:SetScript("OnTextChanged", function(self)
    -- We'll implement search functionality later
    local searchText = self:GetText():lower()
    MailboxGrid:UpdateGrid(searchText)
end)

-- Create scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, MailboxGrid, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 12, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 12)

-- Create scroll child
local scrollChild = CreateFrame("Frame")
scrollFrame:SetScrollChild(scrollChild)

-- Close button
local closeButton = CreateFrame("Button", nil, MailboxGrid, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)

-- Initialize button storage
local buttons = {}

-- Utility function to format money text
local function FormatMoney(money)
    if not money or money == 0 then return "" end
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, copper)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper)
    else
        return string.format("%dc", copper)
    end
end

-- Function to create or get an item button
local function GetOrCreateButton(index)
    if buttons[index] then return buttons[index] end
    
    local button = CreateFrame("Button", "MailboxGridButton"..index, scrollChild, "ItemButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    
    -- Create cooldown frame for expiration timer
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    
    -- Enhance default ItemButtonTemplate elements
    button.icon = _G[button:GetName().."IconTexture"]
    button.count = _G[button:GetName().."Count"]
    button.border = _G[button:GetName().."NormalTexture"]
    
    -- Enhanced tooltip handling
    button:SetScript("OnEnter", function(self)
        if self.mailData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.mailData.subject, 1, 1, 1)
            GameTooltip:AddLine("From: " .. self.mailData.sender, 0.5, 0.5, 0.5)
            
            if self.mailData.money > 0 then
                GameTooltip:AddLine("Money: " .. FormatMoney(self.mailData.money), 1, 1, 1)
            end
            
            if self.mailData.daysLeft then
                local timeColor = self.mailData.daysLeft < 3 and "|cffff0000" or "|cffffd100"
                GameTooltip:AddLine(timeColor.."Expires in: "..string.format("%.1f days|r", self.mailData.daysLeft))
            end
            
            if self.mailData.itemCount > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Items:", 0.5, 0.5, 0.5)
                for i = 1, ATTACHMENTS_MAX_RECEIVE do
                    local name, _, _, count = GetInboxItem(self.mailData.index, i)
                    if name then
                        GameTooltip:AddLine(string.format("  %s%s", name, count > 1 and " x"..count or ""))
                    end
                end
            end
            
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Add click handling
    button:SetScript("OnClick", function(self, mouseButton)
        if not self.mailData then return end
        
        if mouseButton == "RightButton" then
            -- Show context menu (to be implemented)
        end
    end)
    
    buttons[index] = button
    return button
end

-- Function to update grid layout
function MailboxGrid:UpdateGrid(searchText)
    local numItems = GetInboxNumItems()
    local visibleCount = 0
    local buttonIndex = 1
    
    -- Reset scroll child size
    scrollChild:SetSize(FRAME_WIDTH - SCROLLBAR_WIDTH - PADDING * 2, 
        (BUTTON_SIZE + BUTTON_SPACING) * math.ceil(numItems / ITEMS_PER_ROW))
    
    -- Update all buttons
    for i = 1, numItems do
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, 
              daysLeft, itemCount, wasRead, wasReturned, textCreated, 
              canReply, isGM = GetInboxHeaderInfo(i)
              
        -- Apply search filter if text exists
        local matchesSearch = not searchText or searchText == "" or 
            (subject and subject:lower():find(searchText, 1, true)) or
            (sender and sender:lower():find(searchText, 1, true))
            
        if matchesSearch then
            local button = GetOrCreateButton(buttonIndex)
            visibleCount = visibleCount + 1
            
            -- Calculate position
            local row = math.floor((visibleCount-1) / ITEMS_PER_ROW)
            local col = (visibleCount-1) % ITEMS_PER_ROW
            button:SetPoint("TOPLEFT", col * (BUTTON_SIZE + BUTTON_SPACING),
                -row * (BUTTON_SIZE + BUTTON_SPACING))
            
            -- Store mail data for tooltip and click handling
            button.mailData = {
                index = i,
                subject = subject,
                sender = sender,
                money = money,
                itemCount = itemCount,
                daysLeft = daysLeft
            }
            
            -- Update button appearance
            button:Show()
            button:Enable()
            
            if itemCount and itemCount > 0 then
                local name, _, texture, count = GetInboxItem(i, 1)
                button.icon:SetTexture(texture)
                button.count:SetText(count > 1 and count or "")
            elseif money > 0 then
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
                button.count:SetText("")
            else
                button.icon:SetTexture(packageIcon or "Interface\\Icons\\INV_Misc_Note_01")
                button.count:SetText("")
            end
            
            -- Update cooldown timer if mail has expiration
            if daysLeft then
                button.cooldown:SetCooldown(GetTime(), daysLeft * 24 * 3600)
            else
                button.cooldown:Hide()
            end
            
            -- Color border based on mail status
            local r, g, b = 0.5, 0.5, 0.5
            if not wasRead then r, g, b = 1, 0.82, 0 end  -- Unread mail is gold
            if daysLeft and daysLeft < 3 then r, g, b = 1, 0, 0 end  -- Near expiration is red
            button.border:SetVertexColor(r, g, b)
            
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- Hide unused buttons
    for i = buttonIndex, #buttons do
        if buttons[i] then
            buttons[i]:Hide()
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
        self:UpdateGrid()
    elseif event == "MAIL_INBOX_UPDATE" then
        self:UpdateGrid()
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