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

-- Constants
local MODE_ONE_MESSAGE = "one"
local MODE_ALL_MESSAGES = "all"
local MAX_MESSAGES_ALL_MODE = 10

-- Default saved variables
local savedDBDefaults = {
	profile = {
		cooldown = 60, -- seconds between messages
		mode = MODE_ONE_MESSAGE, -- "one" or "all"
		messages = {}, -- list of messages { text = "/trade message" }
		messagesSent = 0,
	},
}

-- Runtime state (not saved)
TSM.isRunning = false
TSM.currentIndex = 1
TSM.timerFrame = nil
TSM.elapsed = 0
TSM.timeUntilNext = 0

-- ============================================================================
-- Initialization
-- ============================================================================

function TSM:OnInitialize()
	-- Load saved variables
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_TradeChatDB", savedDBDefaults, true)

	-- Make module references accessible on TSM object
	for moduleName, module in pairs(TSM.modules) do
		TSM[moduleName] = module
	end

	-- Create timer frame
	TSM:CreateTimerFrame()

	-- Register module with TSM
	TSM:RegisterModule()
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
		TSM.elapsed = TSM.elapsed + elapsed
		TSM.timeUntilNext = TSM.db.profile.cooldown - TSM.elapsed

		if TSM.elapsed >= TSM.db.profile.cooldown then
			TSM.elapsed = 0
			TSM:SendNextMessage()
		end

		-- Update UI if visible
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

	if #TSM.db.profile.messages == 0 then
		TSM:Print(L["No messages configured. Add messages first."])
		return false
	end

	TSM.isRunning = true
	TSM.elapsed = 0
	TSM.timeUntilNext = TSM.db.profile.cooldown
	TSM.timerFrame:Show()

	-- Send first message immediately
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

	TSM:Print(L["Message sending stopped."])
	return true
end

function TSM:SendNextMessage()
	local messages = TSM.db.profile.messages
	if #messages == 0 then
		TSM:Stop()
		return
	end

	if TSM.db.profile.mode == MODE_ALL_MESSAGES then
		TSM:SendAllMessages()
	else
		TSM:SendOneMessage()
	end
end

function TSM:SendOneMessage()
	local messages = TSM.db.profile.messages

	-- Find next enabled message
	local startIndex = TSM.currentIndex
	local found = false
	repeat
		-- Wrap around if needed
		if TSM.currentIndex > #messages then
			TSM.currentIndex = 1
		end

		local messageData = messages[TSM.currentIndex]
		if messageData and messageData.text and messageData.enabled ~= false then
			TSM:SendChatMessage(messageData.text)
			TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1
			found = true
		end

		TSM.currentIndex = TSM.currentIndex + 1

		-- Prevent infinite loop if all messages are disabled
		if TSM.currentIndex > #messages then
			TSM.currentIndex = 1
		end
		if TSM.currentIndex == startIndex and not found then
			TSM:Print(L["No messages configured. Add messages first."])
			TSM:Stop()
			return
		end
	until found
end

function TSM:SendAllMessages()
	local messages = TSM.db.profile.messages

	-- Count enabled messages
	local enabledCount = 0
	for _, msgData in ipairs(messages) do
		if msgData.enabled ~= false then
			enabledCount = enabledCount + 1
		end
	end

	if enabledCount == 0 then
		TSM:Print(L["No messages configured. Add messages first."])
		TSM:Stop()
		return
	end

	-- Check max limit
	if enabledCount > MAX_MESSAGES_ALL_MODE then
		TSM:Print(format(L["Warning: Too many messages (%d). Maximum is 10 for 'All messages at once' mode."], enabledCount))
		TSM:Stop()
		return
	end

	-- Send all enabled messages
	for _, msgData in ipairs(messages) do
		if msgData.text and msgData.enabled ~= false then
			TSM:SendChatMessage(msgData.text)
			TSM.db.profile.messagesSent = TSM.db.profile.messagesSent + 1
		end
	end
end

function TSM:SendChatMessage(text)
	-- Parse the message to extract channel and message content
	-- Format: /channel message or /N message (for numbered channels)

	local channel, message = text:match("^/(%S+)%s+(.+)$")
	if not channel or not message then
		-- No channel prefix, default to say
		channel = "say"
		message = text
	end

	channel = channel:lower()

	-- Map common channel names
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
		-- Format: /w PlayerName message
		local target, whisperMsg = message:match("^(%S+)%s+(.+)$")
		if target and whisperMsg then
			SendChatMessage(whisperMsg, "WHISPER", nil, target)
		end
	elseif tonumber(channel) then
		-- Numbered channel like /1, /2, etc.
		SendChatMessage(message, "CHANNEL", nil, tonumber(channel))
	else
		-- Try to find channel by name
		local channelNum = GetChannelName(channel)
		if channelNum and channelNum > 0 then
			SendChatMessage(message, "CHANNEL", nil, channelNum)
		else
			-- Fallback to say
			SendChatMessage(text, "SAY")
		end
	end
end

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
		-- Adjust current index if needed
		if TSM.currentIndex > #TSM.db.profile.messages then
			TSM.currentIndex = 1
		end
		TSM:Print(L["Message deleted."])
		return true
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

-- ============================================================================
-- Slash Command Handler
-- ============================================================================

function TSM:HandleSlashCommand(input)
	if not input or input == "" then
		TSM:ShowHelp()
		return
	end

	-- Parse command
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
	elseif command == "add" then
		-- Extract message from quotes or use rest of string
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
	TSM:Print("  " .. L["help - Show this help"])
end

-- ============================================================================
-- Config Module
-- ============================================================================

local Config = TSM:NewModule("Config", "AceEvent-3.0")

Config.statusLabels = {}

function Config:Load(parent)
	Config.parent = parent

	local tg = AceGUI:Create("TSMTabGroup")
	tg:SetLayout("Fill")
	tg:SetFullHeight(true)
	tg:SetFullWidth(true)
	tg:SetTabs({
		{ value = 1, text = L["Help"] },
		{ value = 2, text = L["Settings"] },
	})
	tg:SetCallback("OnGroupSelected", function(self, _, value)
		tg:ReleaseChildren()
		if value == 1 then
			Config:DrawHelp(tg)
		elseif value == 2 then
			Config:DrawSettings(tg)
		end
	end)
	parent:AddChild(tg)
	tg:SelectTab(2) -- Default to Settings tab
end

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

function Config:DrawSettings(container)
	Config.settingsContainer = container

	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = {
				-- Status and Controls
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["Status"],
					children = {
						{
							type = "Label",
							text = L["Status"] .. ": ",
							relativeWidth = 0.15,
						},
						{
							type = "Label",
							text = TSM.isRunning and "|cff00ff00" .. L["Running"] .. "|r" or "|cffff0000" .. L["Stopped"] .. "|r",
							relativeWidth = 0.25,
							callback = function(widget)
								Config.statusLabels.status = widget
							end,
						},
						{
							type = "Label",
							text = L["Messages Sent"] .. ": ",
							relativeWidth = 0.2,
						},
						{
							type = "Label",
							text = tostring(TSM.db.profile.messagesSent),
							relativeWidth = 0.15,
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
						{
							type = "Button",
							text = TSM.isRunning and L["Stop"] or L["Start"],
							relativeWidth = 0.3,
							callback = function(widget)
								if TSM.isRunning then
									TSM:Stop()
								else
									TSM:Start()
								end
								Config:RefreshSettings()
							end,
						},
					},
				},
				{
					type = "Spacer",
				},
				-- Cooldown and Mode Settings
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["Cooldown (seconds)"],
					children = {
						{
							type = "EditBox",
							label = L["Cooldown (seconds)"],
							value = tostring(TSM.db.profile.cooldown),
							relativeWidth = 0.15,
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
							label = L["Mode"],
							list = {
								[MODE_ONE_MESSAGE] = L["One message per cooldown"],
								[MODE_ALL_MESSAGES] = L["All messages at once"],
							},
							value = TSM.db.profile.mode,
							relativeWidth = 0.35,
							callback = function(_, _, value)
								TSM.db.profile.mode = value
								Config:RefreshSettings()
							end,
						},
					},
				},
				{
					type = "Spacer",
				},
				-- Messages List
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["Messages"],
					children = Config:GetMessageWidgets(),
				},
				{
					type = "Spacer",
				},
				-- Add Message
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["Add Message"],
					children = {
						{
							type = "EditBox",
							label = L["Enter your message (with channel prefix like /trade, /say, /p):"],
							relativeWidth = 1,
							value = Config.pendingCopyText or "",
							callback = function(widget, _, value)
								if value and value ~= "" then
									TSM:AddMessage(value)
									widget:SetText("")
									Config.pendingCopyText = nil
									Config:RefreshSettings()
								end
							end,
						},
					},
				},
			},
		},
	}
	TSMAPI:BuildPage(container, page)
end

function Config:GetMessageWidgets()
	local children = {}
	local messages = TSM.db.profile.messages

	if #messages == 0 then
		tinsert(children, {
			type = "Label",
			text = L["No messages configured. Add messages first."],
			relativeWidth = 1,
		})
		return children
	end

	-- Count enabled messages and show warning if too many for "all" mode
	if TSM.db.profile.mode == MODE_ALL_MESSAGES then
		local enabledCount = 0
		for _, msgData in ipairs(messages) do
			if msgData.enabled ~= false then
				enabledCount = enabledCount + 1
			end
		end
		if enabledCount > MAX_MESSAGES_ALL_MODE then
			tinsert(children, {
				type = "Label",
				text = "|cffff0000" .. format(L["Warning: Too many messages (%d). Maximum is 10 for 'All messages at once' mode."], enabledCount) .. "|r",
				relativeWidth = 1,
			})
		end
	end

	for i, msgData in ipairs(messages) do
		local isEnabled = msgData.enabled ~= false
		-- Enabled checkbox
		tinsert(children, {
			type = "CheckBox",
			label = "",
			value = isEnabled,
			relativeWidth = 0.06,
			callback = function()
				TSM:ToggleMessage(i)
				Config:RefreshSettings()
			end,
		})
		-- Message text (grayed out if disabled)
		local textColor = isEnabled and "|cffffffff" or "|cff666666"
		tinsert(children, {
			type = "Label",
			text = format("%s%d. %s|r", textColor, i, msgData.text),
			relativeWidth = 0.78,
		})
		-- Copy button
		tinsert(children, {
			type = "Button",
			text = L["Copy"],
			relativeWidth = 0.08,
			callback = function()
				Config.pendingCopyText = msgData.text
				Config:RefreshSettings()
			end,
		})
		-- Delete button
		tinsert(children, {
			type = "Button",
			text = L["Delete"],
			relativeWidth = 0.08,
			callback = function()
				TSM:DeleteMessage(i)
				Config:RefreshSettings()
			end,
		})
	end

	return children
end

function Config:RefreshSettings()
	if Config.settingsContainer then
		Config.settingsContainer:ReleaseChildren()
		Config:DrawSettings(Config.settingsContainer)
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
