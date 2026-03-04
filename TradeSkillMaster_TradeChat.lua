-- ------------------------------------------------------------------------------ --
--                        TradeSkillMaster_TradeChat                              --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.   --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
TSM = LibStub("AceAddon-3.0"):NewAddon(TSM, "TSM_TradeChat", "AceEvent-3.0", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_TradeChat")

-- Price format constants
local PRICE_FORMAT_ROUND_GOLD = "roundgold"
local PRICE_FORMAT_GOLD_SILVER = "goldsilver"
local PRICE_FORMAT_NONE = "none"

-- Default saved variables
local savedDBDefaults = {
	profile = {
		cooldown = 60,
		mode = "messages", -- "messages" or "itemlist"
		batchSize = 1, -- 1-5: number of messages per cooldown
		batchDelay = 1, -- seconds between messages in same batch
		messages = {},
		messagesSent = 0,
		recurringMessage = {
			text = "",
			interval = 3,
			enabled = false,
		},
		itemListConfig = {
			prefix = "WTS:",
			suffix = "PST!",
			itemsPerMessage = 2,
			priceFormat = PRICE_FORMAT_GOLD_SILVER,
			channel = "/trade",
		},
		itemList = {},
	},
}

-- Runtime state (not saved)
TSM.isRunning = false
TSM.currentIndex = 1
TSM.timerFrame = nil
TSM.elapsed = 0
TSM.timeUntilNext = 0
TSM.recurringCounter = 0
TSM.batchQueue = {}
TSM.batchDelayCurrent = 0

-- ============================================================================
-- Initialization
-- ============================================================================

function TSM:OnInitialize()
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_TradeChatDB", savedDBDefaults, true)

	-- Migrate old mode system
	TSM:MigrateSettings()

	for moduleName, module in pairs(TSM.modules) do
		TSM[moduleName] = module
	end

	TSM:CreateTimerFrame()
	TSM:RegisterModule()

	TSM_TradeChat = TSM
end

function TSM:MigrateSettings()
	local p = TSM.db.profile
	if p.mode == "one" then
		p.mode = "messages"
	elseif p.mode == "all" then
		p.mode = "messages"
		-- Set batch size to number of enabled messages (capped at 5)
		local count = 0
		for _, m in ipairs(p.messages) do
			if m.enabled ~= false then count = count + 1 end
		end
		p.batchSize = math.min(math.max(count, 1), 5)
	end
	-- "itemlist" stays as-is, "messages" is already correct
end

function TSM:RegisterModule()
	TSM.icons = {
		{ side = "module", desc = "TradeChat", callback = "Config:Load", icon = "Interface\\Icons\\INV_Letter_15" },
	}

	TSM.slashCommands = {
		{ key = "tradechat", label = L["TradeChat"], callback = function(...) TSM:HandleSlashCommand(...) end },
	}

	TSMAPI:NewModule(TSM)
end

-- ============================================================================
-- Timer System
-- ============================================================================

function TSM:CreateTimerFrame()
	local frame = CreateFrame("Frame")
	frame:Hide()
	frame:SetScript("OnUpdate", function(self, elapsed)
		-- Process batch queue first (messages waiting to be sent with delay)
		if #TSM.batchQueue > 0 then
			TSM.batchDelayCurrent = TSM.batchDelayCurrent + elapsed
			if TSM.batchDelayCurrent >= TSM.db.profile.batchDelay then
				TSM.batchDelayCurrent = 0
				local msg = tremove(TSM.batchQueue, 1)
				TSM:SendChatMessage(msg)
				TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1
			end
			-- Update UI while draining batch
			if TSM.Config and TSM.Config.UpdateStatus then
				TSM.Config:UpdateStatus()
			end
			return
		end

		-- Normal cooldown
		TSM.elapsed = TSM.elapsed + elapsed
		TSM.timeUntilNext = TSM.db.profile.cooldown - TSM.elapsed

		if TSM.elapsed >= TSM.db.profile.cooldown then
			TSM.elapsed = 0
			TSM:SendNextMessage()
		end

		if TSM.Config and TSM.Config.UpdateStatus then
			TSM.Config:UpdateStatus()
		end
	end)
	TSM.timerFrame = frame
end

function TSM:Start()
	if TSM.isRunning then
		TSM:Print(L["Already running."])
		return false
	end

	-- Validate based on mode
	if TSM.db.profile.mode == "itemlist" then
		if #TSM.db.profile.itemList == 0 then
			TSM:Print(L["No items in the list. Add items first."])
			return false
		end
	else
		if #TSM.db.profile.messages == 0 then
			TSM:Print(L["No messages configured. Add messages first."])
			return false
		end
		local hasEnabled = false
		for _, m in ipairs(TSM.db.profile.messages) do
			if m.enabled ~= false then hasEnabled = true; break end
		end
		if not hasEnabled then
			TSM:Print(L["No enabled messages. Enable at least one."])
			return false
		end
	end

	TSM.isRunning = true
	TSM.elapsed = 0
	TSM.timeUntilNext = TSM.db.profile.cooldown
	TSM.recurringCounter = 0
	wipe(TSM.batchQueue)
	TSM.batchDelayCurrent = 0
	TSM.timerFrame:Show()

	TSM:SendNextMessage()

	TSM:Print(L["Message sending started."])
	return true
end

function TSM:Stop()
	if not TSM.isRunning then
		TSM:Print(L["Not running."])
		return false
	end

	TSM.isRunning = false
	TSM.timerFrame:Hide()
	TSM.elapsed = 0
	TSM.timeUntilNext = 0
	TSM.recurringCounter = 0
	wipe(TSM.batchQueue)
	TSM.batchDelayCurrent = 0

	TSM:Print(L["Message sending stopped."])
	return true
end

-- ============================================================================
-- Sending Logic
-- ============================================================================

function TSM:SendNextMessage()
	if TSM.db.profile.mode == "itemlist" then
		TSM:SendItemListMessage()
	else
		TSM:SendBatchMessages()
	end
end

function TSM:SendBatchMessages()
	local messages = TSM.db.profile.messages
	if #messages == 0 then
		TSM:Stop()
		return
	end

	local recurring = TSM.db.profile.recurringMessage
	local recurringActive = recurring and recurring.enabled and recurring.text and recurring.text ~= "" and recurring.interval and recurring.interval > 0

	-- Check if recurring message is due
	if recurringActive and TSM.recurringCounter >= recurring.interval then
		TSM:SendChatMessage(recurring.text)
		TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1
		TSM.recurringCounter = 0
		return -- Recurring takes the whole cooldown slot
	end

	-- Find next N enabled messages
	local batchSize = TSM.db.profile.batchSize
	local toSend = {}
	local checked = 0

	while #toSend < batchSize and checked < #messages do
		if TSM.currentIndex > #messages then
			TSM.currentIndex = 1
		end

		local msgData = messages[TSM.currentIndex]
		if msgData and msgData.text and msgData.enabled ~= false then
			tinsert(toSend, msgData.text)
		end

		TSM.currentIndex = TSM.currentIndex + 1
		checked = checked + 1
	end

	if #toSend == 0 then
		TSM:Print(L["No enabled messages. Enable at least one."])
		TSM:Stop()
		return
	end

	-- Send first message immediately
	TSM:SendChatMessage(toSend[1])
	TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1

	-- Queue remaining messages
	if #toSend > 1 then
		local batchDelay = TSM.db.profile.batchDelay
		if batchDelay > 0 then
			for i = 2, #toSend do
				tinsert(TSM.batchQueue, toSend[i])
			end
			TSM.batchDelayCurrent = 0
		else
			-- No delay, send all immediately
			for i = 2, #toSend do
				TSM:SendChatMessage(toSend[i])
				TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1
			end
		end
	end

	-- Increment recurring counter (once per batch, not per message)
	if recurringActive then
		TSM.recurringCounter = TSM.recurringCounter + 1
	end
end

-- Format price based on configured format
local function FormatItemPrice(copper, priceFormat)
	if not copper or copper == 0 or priceFormat == PRICE_FORMAT_NONE then
		return nil
	end

	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)

	if priceFormat == PRICE_FORMAT_ROUND_GOLD then
		if silver >= 50 then
			gold = gold + 1
		end
		return format("%dg", gold)
	else
		local copperRem = copper % 100
		if copperRem >= 50 then
			silver = silver + 1
			if silver >= 100 then
				gold = gold + 1
				silver = 0
			end
		end
		if gold > 0 then
			return format("%dg%ds", gold, silver)
		else
			return format("%ds", silver)
		end
	end
end

local function SelectRandomItems(items, count)
	if #items <= count then
		return items
	end

	local indices = {}
	for i = 1, #items do
		indices[i] = i
	end

	for i = 1, count do
		local j = math.random(i, #items)
		indices[i], indices[j] = indices[j], indices[i]
	end

	local selected = {}
	for i = 1, count do
		tinsert(selected, items[indices[i]])
	end
	return selected
end

function TSM:SendItemListMessage()
	local config = TSM.db.profile.itemListConfig
	local items = TSM.db.profile.itemList

	if #items == 0 then
		TSM:Print(L["No items in the list. Add items first."])
		TSM:Stop()
		return
	end

	local selected = SelectRandomItems(items, config.itemsPerMessage)

	local parts = {}
	for _, item in ipairs(selected) do
		local text = item.link or item.name or "Unknown"
		local priceStr = FormatItemPrice(item.price, config.priceFormat)
		if priceStr then
			text = text .. " " .. priceStr
		end
		tinsert(parts, text)
	end

	local itemsText = table.concat(parts, ", ")
	local prefix = config.prefix or ""
	local suffix = config.suffix or ""

	if prefix ~= "" and not prefix:match("%s$") then
		prefix = prefix .. " "
	end
	if suffix ~= "" and not suffix:match("^%s") then
		suffix = " " .. suffix
	end

	local fullMessage = prefix .. itemsText .. suffix
	TSM:SendChatMessage(config.channel .. " " .. fullMessage)
	TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1
end

function TSM:SendChatMessage(text)
	local channel, message = text:match("^/(%S+)%s+(.+)$")
	if not channel or not message then
		channel = "say"
		message = text
	end

	channel = channel:lower()

	if channel == "trade" then
		SendChatMessage(message, "CHANNEL", nil, GetChannelName("Trade"))
	elseif channel == "general" then
		SendChatMessage(message, "CHANNEL", nil, GetChannelName("General"))
	elseif channel == "lfg" or channel == "lookingforgroup" then
		SendChatMessage(message, "CHANNEL", nil, GetChannelName("LookingForGroup"))
	elseif channel == "say" or channel == "s" then
		SendChatMessage(message, "SAY")
	elseif channel == "yell" or channel == "y" then
		SendChatMessage(message, "YELL")
	elseif channel == "party" or channel == "p" then
		SendChatMessage(message, "PARTY")
	elseif channel == "raid" or channel == "ra" then
		SendChatMessage(message, "RAID")
	elseif channel == "guild" or channel == "g" then
		SendChatMessage(message, "GUILD")
	elseif channel == "officer" or channel == "o" then
		SendChatMessage(message, "OFFICER")
	elseif channel == "instance" or channel == "i" then
		SendChatMessage(message, "INSTANCE_CHAT")
	elseif channel == "whisper" or channel == "w" or channel == "tell" then
		local target, whisperMsg = message:match("^(%S+)%s+(.+)$")
		if target and whisperMsg then
			SendChatMessage(whisperMsg, "WHISPER", nil, target)
		end
	elseif tonumber(channel) then
		SendChatMessage(message, "CHANNEL", nil, tonumber(channel))
	else
		local channelNum = GetChannelName(channel)
		if channelNum and channelNum > 0 then
			SendChatMessage(message, "CHANNEL", nil, channelNum)
		else
			SendChatMessage(text, "SAY")
		end
	end
end

-- ============================================================================
-- Message Management
-- ============================================================================

function TSM:AddMessage(text)
	if not text or text == "" then
		return false
	end
	tinsert(TSM.db.profile.messages, { text = text, enabled = true })
	TSM:Print(format(L["Message added: %s"], text))
	return true
end

function TSM:ToggleMessage(index)
	if index > 0 and index <= #TSM.db.profile.messages then
		local msg = TSM.db.profile.messages[index]
		msg.enabled = not (msg.enabled ~= false)
		return true
	end
	return false
end

function TSM:DeleteMessage(index)
	if index > 0 and index <= #TSM.db.profile.messages then
		tremove(TSM.db.profile.messages, index)
		if TSM.currentIndex > #TSM.db.profile.messages then
			TSM.currentIndex = 1
		end
		TSM:Print(L["Message deleted."])
		return true
	end
	return false
end

function TSM:EditMessage(index, newText)
	if index > 0 and index <= #TSM.db.profile.messages then
		if newText and newText ~= "" then
			TSM.db.profile.messages[index].text = newText
			return true
		end
	end
	return false
end

function TSM:MoveMessageUp(index)
	if index > 1 and index <= #TSM.db.profile.messages then
		local messages = TSM.db.profile.messages
		messages[index], messages[index - 1] = messages[index - 1], messages[index]
		return true
	end
	return false
end

function TSM:MoveMessageDown(index)
	if index >= 1 and index < #TSM.db.profile.messages then
		local messages = TSM.db.profile.messages
		messages[index], messages[index + 1] = messages[index + 1], messages[index]
		return true
	end
	return false
end

function TSM:EnableAllMessages()
	for _, msg in ipairs(TSM.db.profile.messages) do
		msg.enabled = true
	end
end

function TSM:DisableAllMessages()
	for _, msg in ipairs(TSM.db.profile.messages) do
		msg.enabled = false
	end
end

function TSM:DuplicateMessage(index)
	if index > 0 and index <= #TSM.db.profile.messages then
		local orig = TSM.db.profile.messages[index]
		tinsert(TSM.db.profile.messages, { text = orig.text, enabled = true })
		TSM:Print(format(L["Message duplicated from #%d."], index))
		return true
	end
	return false
end

-- ============================================================================
-- Item List Public API
-- ============================================================================

local function ItemExistsInList(name)
	for _, item in ipairs(TSM.db.profile.itemList) do
		if item.name == name then
			return true
		end
	end
	return false
end

function TSM:AddItems(items)
	local added = 0
	for _, item in ipairs(items) do
		if item.name and not ItemExistsInList(item.name) then
			tinsert(TSM.db.profile.itemList, {
				link = item.link,
				price = item.price,
				name = item.name,
			})
			added = added + 1
		end
	end
	if TSM.Config and TSM.Config.RefreshSettingsTab then
		TSM.Config:RefreshSettingsTab()
	end
	return added
end

function TSM:ClearItems()
	wipe(TSM.db.profile.itemList)
	if TSM.Config and TSM.Config.RefreshSettingsTab then
		TSM.Config:RefreshSettingsTab()
	end
end

function TSM:GetItemCount()
	return #TSM.db.profile.itemList
end

function TSM:DeleteItem(index)
	if index > 0 and index <= #TSM.db.profile.itemList then
		tremove(TSM.db.profile.itemList, index)
		return true
	end
	return false
end

-- ============================================================================
-- Slash Command Handler
-- ============================================================================

function TSM:HandleSlashCommand(input)
	if not input or input == "" then
		TSM:ShowHelp()
		return
	end

	local command, args = input:match("^(%S+)%s*(.*)$")
	if not command then
		TSM:ShowHelp()
		return
	end

	command = command:lower()

	if command == "help" then
		TSM:ShowHelp()
	elseif command == "start" then
		TSM:Start()
	elseif command == "stop" then
		TSM:Stop()
	elseif command == "status" then
		if TSM.isRunning then
			TSM:Print(format("|cff00ff00%s|r - %s: %d - %s: %ds", L["Running"], L["Messages Sent"], TSM.db.profile.messagesSent, L["Next message in"], math.ceil(TSM.timeUntilNext)))
		else
			TSM:Print("|cffff0000" .. L["Stopped"] .. "|r")
		end
	elseif command == "add" then
		local message = args:match('^"(.+)"$') or args:match("^'(.+)'$") or args
		if message and message ~= "" then
			TSM:AddMessage(message)
		else
			TSM:Print(L["Usage: /tsm tradechat <command>"])
			TSM:Print('  add "message" - ' .. L["add \"message\" - Add a new message to the rotation"])
		end
	else
		TSM:ShowHelp()
	end
end

function TSM:ShowHelp()
	TSM:Print(L["Available commands:"])
	TSM:Print(L["Usage: /tsm tradechat <command>"])
	TSM:Print("  " .. L["add \"message\" - Add a new message to the rotation"])
	TSM:Print("  " .. L["start - Start sending messages"])
	TSM:Print("  " .. L["stop - Stop sending messages"])
	TSM:Print("  " .. L["status - Show current status"])
	TSM:Print("  " .. L["help - Show this help"])
end

-- ============================================================================
-- Config Module
-- ============================================================================

local Config = TSM:NewModule("Config", "AceEvent-3.0")

Config.statusLabels = {}
Config.currentTab = 1
Config.messagesContainer = nil
Config.settingsTabContainer = nil
Config.tabGroup = nil

function Config:Load(parent)
	Config.parent = parent

	local tg = AceGUI:Create("TSMTabGroup")
	tg:SetLayout("Fill")
	tg:SetFullHeight(true)
	tg:SetFullWidth(true)
	tg:SetTabs({
		{ value = 1, text = L["Messages"] },
		{ value = 2, text = L["Settings"] },
		{ value = 3, text = L["Help"] },
	})
	tg:SetCallback("OnGroupSelected", function(self, _, value)
		tg:ReleaseChildren()
		Config.currentTab = value
		Config.messagesContainer = nil
		Config.settingsTabContainer = nil
		if value == 1 then
			Config:DrawMessages(tg)
		elseif value == 2 then
			Config:DrawSettingsTab(tg)
		elseif value == 3 then
			Config:DrawHelp(tg)
		end
	end)
	parent:AddChild(tg)
	Config.tabGroup = tg
	tg:SelectTab(1)
end

-- ============================================================================
-- Messages Tab
-- ============================================================================

function Config:DrawMessages(container)
	Config.messagesContainer = container

	local children = {}

	-- Status bar (compact)
	tinsert(children, {
		type = "InlineGroup",
		layout = "flow",
		title = L["Status"],
		children = {
			{
				type = "Button",
				text = TSM.isRunning and L["Stop"] or L["Start"],
				relativeWidth = 0.15,
				callback = function()
					if TSM.isRunning then
						TSM:Stop()
					else
						TSM:Start()
					end
					Config:RefreshMessages()
				end,
			},
			{
				type = "Label",
				text = TSM.isRunning and "|cff00ff00" .. L["Running"] .. "|r" or "|cffff0000" .. L["Stopped"] .. "|r",
				relativeWidth = 0.17,
				callback = function(widget)
					Config.statusLabels.status = widget
				end,
			},
			{
				type = "Label",
				text = L["Messages Sent"] .. ": ",
				relativeWidth = 0.15,
			},
			{
				type = "Label",
				text = tostring(TSM.db.profile.messagesSent),
				relativeWidth = 0.13,
				callback = function(widget)
					Config.statusLabels.sent = widget
				end,
			},
			{
				type = "Label",
				text = TSM.isRunning and (L["Next message in"] .. ": " .. math.ceil(TSM.timeUntilNext) .. "s") or "",
				relativeWidth = 0.25,
				callback = function(widget)
					Config.statusLabels.next = widget
				end,
			},
		},
	})

	tinsert(children, { type = "Spacer" })

	-- Item list mode notice
	if TSM.db.profile.mode == "itemlist" then
		tinsert(children, {
			type = "InlineGroup",
			layout = "flow",
			title = L["Messages"],
			children = {
				{
					type = "Label",
					text = "|cffffd100" .. L["Item List mode is active. Configure items in the Settings tab."] .. "|r",
					relativeWidth = 1,
				},
			},
		})
	else
		-- Messages list
		local enabledCount = 0
		for _, m in ipairs(TSM.db.profile.messages) do
			if m.enabled ~= false then enabledCount = enabledCount + 1 end
		end
		local totalCount = #TSM.db.profile.messages
		local title = L["Messages"] .. " (" .. enabledCount .. "/" .. totalCount .. " " .. L["enabled"] .. ")"

		tinsert(children, {
			type = "InlineGroup",
			layout = "flow",
			title = title,
			children = Config:GetMessageWidgets(),
		})

		tinsert(children, { type = "Spacer" })

		-- Add Message section
		tinsert(children, {
			type = "InlineGroup",
			layout = "flow",
			title = L["Add Message"],
			children = {
				{
					type = "Label",
					text = L["Enter message to add, or #N to duplicate:"],
					relativeWidth = 1,
				},
				{
					type = "EditBox",
					label = "",
					relativeWidth = 0.97,
					value = "",
					callback = function(widget, _, value)
						if not value or value == "" then return end

						-- Check for duplicate syntax: #N
						local dupIndex = value:match("^#(%d+)$")
						if dupIndex then
							local idx = tonumber(dupIndex)
							if not TSM:DuplicateMessage(idx) then
								TSM:Print(format(L["Invalid message #: %d"], idx))
							end
						else
							TSM:AddMessage(value)
						end
						widget:SetText("")
						Config:RefreshMessages()
					end,
				},
			},
		})
	end

	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = children,
		},
	}
	TSMAPI:BuildPage(container, page)
end

function Config:GetMessageWidgets()
	local children = {}
	local messages = TSM.db.profile.messages

	-- Enable All / Disable All buttons
	tinsert(children, {
		type = "Button",
		text = L["Enable All"],
		relativeWidth = 0.15,
		callback = function()
			TSM:EnableAllMessages()
			Config:RefreshMessages()
		end,
	})
	tinsert(children, {
		type = "Button",
		text = L["Disable All"],
		relativeWidth = 0.15,
		callback = function()
			TSM:DisableAllMessages()
			Config:RefreshMessages()
		end,
	})

	tinsert(children, { type = "Spacer" })

	if #messages == 0 then
		tinsert(children, {
			type = "Label",
			text = L["No messages configured. Add messages first."],
			relativeWidth = 1,
		})
		return children
	end

	-- Message rows
	for i, msgData in ipairs(messages) do
		local isEnabled = msgData.enabled ~= false
		local isFirst = (i == 1)
		local isLast = (i == #messages)

		-- Checkbox
		tinsert(children, {
			type = "CheckBox",
			label = "",
			value = isEnabled,
			relativeWidth = 0.05,
			callback = function()
				TSM:ToggleMessage(i)
				Config:RefreshMessages()
			end,
		})

		-- Index number
		tinsert(children, {
			type = "Label",
			text = "|cff888888" .. i .. ".|r",
			relativeWidth = 0.04,
		})

		-- Message text (editable)
		tinsert(children, {
			type = "EditBox",
			label = "",
			value = msgData.text,
			relativeWidth = 0.71,
			callback = function(_, _, value)
				if value and value ~= "" then
					TSM:EditMessage(i, value)
				end
			end,
		})

		-- Move Up
		tinsert(children, {
			type = "Button",
			text = isFirst and " " or "\226\150\178", -- up arrow
			relativeWidth = 0.05,
			disabled = isFirst,
			callback = function()
				TSM:MoveMessageUp(i)
				Config:RefreshMessages()
			end,
		})

		-- Move Down
		tinsert(children, {
			type = "Button",
			text = isLast and " " or "\226\150\188", -- down arrow
			relativeWidth = 0.05,
			disabled = isLast,
			callback = function()
				TSM:MoveMessageDown(i)
				Config:RefreshMessages()
			end,
		})

		-- Delete
		tinsert(children, {
			type = "Button",
			text = "X",
			relativeWidth = 0.06,
			callback = function()
				TSM:DeleteMessage(i)
				Config:RefreshMessages()
			end,
		})
	end

	return children
end

-- ============================================================================
-- Settings Tab
-- ============================================================================

function Config:DrawSettingsTab(container)
	Config.settingsTabContainer = container

	local children = {}

	-- Sending configuration
	tinsert(children, {
		type = "InlineGroup",
		layout = "flow",
		title = L["Sending"],
		children = {
			{
				type = "EditBox",
				label = L["Cooldown (seconds)"],
				value = tostring(TSM.db.profile.cooldown),
				relativeWidth = 0.2,
				callback = function(widget, _, value)
					local num = tonumber(value)
					if num and num >= 1 then
						TSM.db.profile.cooldown = num
					else
						widget:SetText(tostring(TSM.db.profile.cooldown))
					end
				end,
				tooltip = L["Time between each message in seconds."],
			},
			{
				type = "Dropdown",
				label = L["Messages per cooldown"],
				list = {
					[1] = "1",
					[2] = "2",
					[3] = "3",
					[4] = "4",
					[5] = "5",
				},
				value = TSM.db.profile.batchSize,
				relativeWidth = 0.3,
				callback = function(_, _, value)
					TSM.db.profile.batchSize = value
				end,
				tooltip = L["Number of messages to send each cooldown."],
			},
			{
				type = "Dropdown",
				label = L["Delay between messages (s)"],
				list = {
					[0] = "0",
					[1] = "1",
					[2] = "2",
					[3] = "3",
				},
				value = TSM.db.profile.batchDelay,
				relativeWidth = 0.3,
				callback = function(_, _, value)
					TSM.db.profile.batchDelay = value
				end,
				tooltip = L["Seconds between each message in a batch."],
			},
		},
	})

	tinsert(children, { type = "Spacer" })

	-- Recurring Message
	local recurring = TSM.db.profile.recurringMessage
	tinsert(children, {
		type = "InlineGroup",
		layout = "flow",
		title = L["Recurring Message"],
		children = {
			{
				type = "Label",
				text = L["This message will be sent every X cooldowns, interleaved with your regular messages."],
				relativeWidth = 1,
			},
			{
				type = "CheckBox",
				label = L["Enable Recurring Message"],
				value = recurring.enabled,
				relativeWidth = 0.3,
				callback = function(_, _, value)
					recurring.enabled = value
				end,
				tooltip = L["Enable or disable the recurring message."],
			},
			{
				type = "EditBox",
				label = L["Every X cooldowns"],
				value = tostring(recurring.interval),
				relativeWidth = 0.15,
				callback = function(widget, _, value)
					local num = tonumber(value)
					if num and num >= 1 then
						recurring.interval = num
					else
						widget:SetText(tostring(recurring.interval))
					end
				end,
				tooltip = L["Send the recurring message after this many regular messages."],
			},
			{
				type = "EditBox",
				label = L["Recurring message text (with channel prefix like /trade, /say, /p):"],
				value = recurring.text,
				relativeWidth = 1,
				callback = function(_, _, value)
					recurring.text = value or ""
				end,
			},
		},
	})

	tinsert(children, { type = "Spacer" })

	-- Item List Mode section
	local itemListChildren = {
		{
			type = "CheckBox",
			label = L["Use item list mode"],
			value = TSM.db.profile.mode == "itemlist",
			relativeWidth = 0.5,
			callback = function(_, _, value)
				TSM.db.profile.mode = value and "itemlist" or "messages"
				Config:RefreshSettingsTab()
			end,
			tooltip = L["Send random items from a list instead of messages."],
		},
	}

	if TSM.db.profile.mode == "itemlist" then
		-- Show item list configuration when enabled
		local itemWidgets = Config:GetItemListWidgets()
		for _, w in ipairs(itemWidgets) do
			tinsert(itemListChildren, w)
		end
	end

	tinsert(children, {
		type = "InlineGroup",
		layout = "flow",
		title = L["Item List"],
		children = itemListChildren,
	})

	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = children,
		},
	}
	TSMAPI:BuildPage(container, page)
end

-- ============================================================================
-- Item List Widgets (for Settings tab)
-- ============================================================================

function Config:GetItemListWidgets()
	local config = TSM.db.profile.itemListConfig
	local items = TSM.db.profile.itemList

	local widgets = {}

	-- Item List Settings
	tinsert(widgets, { type = "Spacer" })
	tinsert(widgets, {
		type = "EditBox",
		label = L["Prefix"],
		value = config.prefix,
		relativeWidth = 0.3,
		callback = function(_, _, value)
			config.prefix = value or ""
		end,
		tooltip = L["Text before the item links (e.g., 'WTS:')"],
	})
	tinsert(widgets, {
		type = "EditBox",
		label = L["Suffix"],
		value = config.suffix,
		relativeWidth = 0.3,
		callback = function(_, _, value)
			config.suffix = value or ""
		end,
		tooltip = L["Text after the item links (e.g., 'PST!')"],
	})
	tinsert(widgets, {
		type = "EditBox",
		label = L["Channel"],
		value = config.channel,
		relativeWidth = 0.2,
		callback = function(_, _, value)
			config.channel = value or "/trade"
		end,
		tooltip = L["Channel to send messages (e.g., /trade, /say, /yell)"],
	})
	tinsert(widgets, {
		type = "Dropdown",
		label = L["Items per message"],
		list = {
			[1] = "1",
			[2] = "2",
			[3] = "3",
		},
		value = config.itemsPerMessage,
		relativeWidth = 0.15,
		callback = function(_, _, value)
			config.itemsPerMessage = value
		end,
	})
	tinsert(widgets, {
		type = "Dropdown",
		label = L["Price format"],
		list = {
			[PRICE_FORMAT_ROUND_GOLD] = L["Round to gold"],
			[PRICE_FORMAT_GOLD_SILVER] = L["Gold and silver"],
			[PRICE_FORMAT_NONE] = L["No price"],
		},
		value = config.priceFormat,
		relativeWidth = 0.25,
		callback = function(_, _, value)
			config.priceFormat = value
		end,
	})

	-- Item List Table header
	tinsert(widgets, { type = "Spacer" })

	if #items == 0 then
		tinsert(widgets, {
			type = "Label",
			text = L["No items in the list. Add items manually or use the 'Add to TradeChat' button in the AuctionsTab."],
			relativeWidth = 1,
		})
	else
		-- Header
		tinsert(widgets, {
			type = "Label",
			text = "|cffffd100" .. L["Item"] .. "|r",
			relativeWidth = 0.5,
		})
		tinsert(widgets, {
			type = "Label",
			text = "|cffffd100" .. L["Price"] .. "|r",
			relativeWidth = 0.35,
		})
		tinsert(widgets, {
			type = "Label",
			text = "",
			relativeWidth = 0.15,
		})

		-- Item rows
		for i, item in ipairs(items) do
			tinsert(widgets, {
				type = "Label",
				text = item.link or item.name or "Unknown",
				relativeWidth = 0.5,
			})
			tinsert(widgets, {
				type = "Label",
				text = item.price and Config:FormatPriceDisplay(item.price) or L["No price"],
				relativeWidth = 0.35,
			})
			tinsert(widgets, {
				type = "Button",
				text = L["Delete"],
				relativeWidth = 0.15,
				callback = function()
					TSM:DeleteItem(i)
					Config:RefreshSettingsTab()
				end,
			})
		end
	end

	-- Add Item section
	tinsert(widgets, { type = "Spacer" })
	tinsert(widgets, {
		type = "EditBox",
		label = L["Item link (Shift+Click item)"],
		relativeWidth = 0.5,
		value = Config.pendingItemLink or "",
		callback = function(_, _, value)
			Config.pendingItemLink = value
		end,
	})
	tinsert(widgets, {
		type = "EditBox",
		label = L["Price (copper, optional)"],
		relativeWidth = 0.25,
		value = Config.pendingItemPrice or "",
		callback = function(_, _, value)
			Config.pendingItemPrice = value
		end,
	})
	tinsert(widgets, {
		type = "Button",
		text = L["Add"],
		relativeWidth = 0.12,
		callback = function()
			Config:AddItemFromInput()
		end,
	})
	tinsert(widgets, {
		type = "Button",
		text = L["Clear All"],
		relativeWidth = 0.12,
		callback = function()
			TSM:ClearItems()
			Config:RefreshSettingsTab()
		end,
	})

	return widgets
end

function Config:FormatPriceDisplay(copper)
	if not copper or copper == 0 then return L["No price"] end
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local copperRem = copper % 100
	if gold > 0 then
		return format("%dg %ds %dc", gold, silver, copperRem)
	elseif silver > 0 then
		return format("%ds %dc", silver, copperRem)
	else
		return format("%dc", copperRem)
	end
end

function Config:AddItemFromInput()
	local link = Config.pendingItemLink
	local priceStr = Config.pendingItemPrice

	if not link or link == "" then
		TSM:Print(L["Please enter an item link."])
		return
	end

	local name = link:match("%[(.+)%]")
	if not name then
		name = link
	end

	local price = tonumber(priceStr) or nil

	TSM:AddItems({{
		link = link,
		price = price,
		name = name,
	}})

	Config.pendingItemLink = nil
	Config.pendingItemPrice = nil
	Config:RefreshSettingsTab()
end

-- ============================================================================
-- Help Tab
-- ============================================================================

function Config:DrawHelp(container)
	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = {
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["TradeChat"],
					children = {
						{
							type = "Label",
							text = L["TradeChat allows you to send periodic messages to chat channels."],
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = L["Add messages to the list, set the cooldown, and click Start."],
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = L["Messages are sent in rotation, one at a time."],
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = L["Use channel prefixes like /trade, /say, /yell, /p, /g, /1, /2, etc."],
							relativeWidth = 1,
						},
					},
				},
				{
					type = "Spacer",
				},
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["Available commands:"],
					children = {
						{
							type = "Label",
							text = "/tsm tradechat add \"message\"",
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = "/tsm tradechat start",
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = "/tsm tradechat stop",
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = "/tsm tradechat status",
							relativeWidth = 1,
						},
						{
							type = "Label",
							text = "/tsm tradechat help",
							relativeWidth = 1,
						},
					},
				},
			},
		},
	}
	TSMAPI:BuildPage(container, page)
end

-- ============================================================================
-- Refresh & Update
-- ============================================================================

function Config:RefreshMessages()
	if Config.messagesContainer then
		Config.messagesContainer:ReleaseChildren()
		Config:DrawMessages(Config.messagesContainer)
	end
end

function Config:RefreshSettingsTab()
	if Config.settingsTabContainer then
		Config.settingsTabContainer:ReleaseChildren()
		Config:DrawSettingsTab(Config.settingsTabContainer)
	end
end

function Config:UpdateStatus()
	if not Config.statusLabels then return end

	if Config.statusLabels.status then
		Config.statusLabels.status:SetText(TSM.isRunning and "|cff00ff00" .. L["Running"] .. "|r" or "|cffff0000" .. L["Stopped"] .. "|r")
	end

	if Config.statusLabels.sent then
		Config.statusLabels.sent:SetText(tostring(TSM.db.profile.messagesSent))
	end

	if Config.statusLabels.next then
		if TSM.isRunning then
			Config.statusLabels.next:SetText(L["Next message in"] .. ": " .. math.ceil(TSM.timeUntilNext) .. "s")
		else
			Config.statusLabels.next:SetText("")
		end
	end
end
