--[[----------------------------------------------------------------------------

    TabToNextTab

    A World of Warcraft AddOn to allow cycling through user interface tabs
    using the TAB and SHIFT-TAB keyboard keys.

    Copyright 2024 Mike "Xodiv" Battersby <mib@post.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

----------------------------------------------------------------------------]]--

local AutoTabFrames = {
    {
        frame =                 "AchievementFrame",
        loadFunc =              "AchievementFrame_LoadUI",
    },
    {
        frame =                 "CollectionsJournal",
    },
    {
        frame =                 "CharacterFrame",
    },
    {
        frame =                 "InspectFrame",
        loadFunc =              "InspectFrame_LoadUI",
    },
    {
        frame =                 "SpellBookFrame",
    },
    {
        frame =                 "ClassTalentFrame",
        loadFunc =              "ClassTalentFrame_LoadUI"
    },
    {
        frame =                 "PVEFrame",
    },
    {
        frame =                 "FriendsFrame",
    },
    {
        frame =                 "CommunitiesFrame",
        loadFunc =              "Communities_LoadUI",
        tabKeys =               { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" },
    },
    {
        frame =                 "EncounterJournal",
        loadFunc =              "EncounterJournal_LoadUI",
    },
    {
        frame =                 "AuctionHouseFrame",
        loadFunc =              "AuctionHouseFrame_LoadUI",
    },
    {
        frame =                 "MerchantFrame",
    },
    {
        frame =                 "MailFrame",
    },
    {
        frame =                 "GuildBankFrame",
        loadInteractionType =   Enum.PlayerInteractionType.GuildBanker,
    },
    {
        frame =                 "ProfessionsFrame",
        loadFunc =              "ProfessionsFrame_LoadUI",
    },
    {
        frame =                 "BankFrame",
    },
    {
        frame =                 "LiteBagBank",
        loadAddOn =             "LiteBag",
    },
    {
        frame =                 "ProfessionsCustomerOrdersFrame",
        loadFunc =              "ProfessionsCustomerOrders_LoadUI",
    },
}

CreateFrame("Button", "TabToNextTab", nil, "SecureActionButtonTemplate")

-- modulus increment/decrement with 1-based numbers
local function rotateN(currentVal, numVals, increment)
    return  ( currentVal - 1 + increment ) % numVals + 1
end

local function GetNextTabButton(info, direction)
    local frame = _G[info.frame]
    local tabButtons, currentTab, numTabs

    -- Try to handle all the different tabbing mechanisms

    if frame.Tabs and frame.selectedTab then
        currentTab = frame.selectedTab
        tabButtons = frame.Tabs
        numTabs = frame.numTabs
    elseif frame.numTabs and frame.selectedTab then
        currentTab = frame.selectedTab
        tabButtons = { }
        for i = 1, frame.numTabs do
            table.insert(tabButtons, _G[frame:GetName().."Tab"..i])
        end
        numTabs = #tabButtons
    elseif frame.Tabs and frame.currentTab then
        for i, tabButton in ipairs(frame.Tabs) do
            if tabButton == frame.currentTab then
                currentTab = i
                break
            end
        end
        tabButtons = frame.Tabs
        numTabs = frame.numTabs
    elseif frame.TabSystem then
        currentTab = frame.TabSystem.selectedTabID
        tabButtons = {}
        for _, tab in ipairs(frame.TabSystem.tabs) do
            table.insert(tabButtons, tab)
        end
        numTabs = #tabButtons
    elseif info.tabKeys then
        tabButtons = {}
        local tab = 0
        for i, tabKey in ipairs(info.tabKeys) do
            table.insert(tabButtons, frame[tabKey])
            if frame[tabKey]:GetChecked() then
                currentTab = i
            end
        end
        numTabs = #tabButtons
    end

    if currentTab then
        newTab = currentTab
        while true do
            newTab = rotateN(newTab, numTabs, direction)
            if newTab == currentTab then break end
            local tabButton = tabButtons[newTab]
            -- This should probably be moved to the info struct
            if tabButton:IsShown() and not tabButton.forceDisabled and tabButton:IsEnabled() then
                return tabButton
            end
        end
    end
end

-- Tab through the frame we are moused over, or the last one tabbed/opened

function TabToNextTab:GetActiveFrameInfo()
    for i, info in ipairs(self.activeFrameInfoList) do
        if MouseIsOver(_G[info.frame]) then
            if i > 1 then
                table.remove(self.activeFrameInfoList, i)
                table.insert(self.activeFrameInfoList, 1, info)
            end
            return info
        end
    end
    return self.activeFrameInfoList[1]
end

function TabToNextTab:PreClick(key)
    if InCombatLockdown() then return end
    local info = self:GetActiveFrameInfo()
    if not info then return end
    local direction = key == 'TAB' and 1 or -1
    local tabButton = GetNextTabButton(info, direction)
    self:SetAttribute("clickbutton", tabButton)
end

function TabToNextTab:PostClick()
    self:SetAttribute("clickbutton", nil)
end

function TabToNextTab:HookTabKeys()
    SetOverrideBindingClick(self, true, 'TAB', self:GetName(), 'TAB')
    SetOverrideBindingClick(self, true, 'SHIFT-TAB', self:GetName(), 'SHIFT-TAB')
end

function TabToNextTab:UnhookTabKeys()
    ClearOverrideBindings(self)
end

function TabToNextTab:SetUpFrame(info)
    if info.hooked then return end
    local frame = _G[info.frame]

    local function OnShow(f)
        if f:IsVisible() then
            tDeleteItem(self.activeFrameInfoList, info)
            table.insert(self.activeFrameInfoList, 1, info)
            if InCombatLockdown() then return end
            self:HookTabKeys()
        end
    end

    local function OnHide()
        tDeleteItem(self.activeFrameInfoList, info)
        if InCombatLockdown() then return end
        if not next(self.activeFrameInfoList) then
            self:UnhookTabKeys()
        end
    end

    frame:HookScript("OnShow", OnShow)
    frame:HookScript("OnHide", OnHide)
    if frame:IsShown() then OnShow() end
        
    info.hooked = true
end

function TabToNextTab:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:Initialize()
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:UnhookTabKeys()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if next(self.activeFrameInfoList) then
            self:HookTabKeys()
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        for _, info in ipairs(AutoTabFrames) do
            if info.loadInteractionType and info.loadInteractionType == interactionType then
                self:SetUpFrame(info)
            end
        end
    end
end

function TabToNextTab:Initialize()
    self.activeFrameInfoList = {}
    for _, info in ipairs(AutoTabFrames) do
        local loader = function () self:SetUpFrame(info) end
        if info.loadFunc then
            hooksecurefunc(info.loadFunc, loader)
        elseif info.loadAddOn then
            EventUtil.ContinueOnAddOnLoaded(info.loadAddOn, loader)
        elseif _G[info.frame] then
            loader()
        end
    end
    self:SetAttribute("type", "click")
    self:RegisterForClicks("AnyUp", "AnyDown")
    self:SetScript("PreClick", self.PreClick)
    self:SetScript("PostClick", self.PostClick)
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
end

TabToNextTab:SetScript("OnEvent", TabToNextTab.OnEvent)
TabToNextTab:RegisterEvent("PLAYER_LOGIN")