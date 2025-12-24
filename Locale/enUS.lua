-- Locale for enUS
local L = LibStub("AceLocale-3.0"):NewLocale("TradeSkillMaster_TradeChat", "enUS", true)
if not L then return end

-- General
L["TradeChat"] = "TradeChat"
L["Help"] = "Help"
L["Settings"] = "Settings"

-- Help texts
L["TradeChat allows you to send periodic messages to chat channels."] = "TradeChat allows you to send periodic messages to chat channels."
L["Add messages to the list, set the cooldown, and click Start."] = "Add messages to the list, set the cooldown, and click Start."
L["Messages are sent in rotation, one at a time."] = "Messages are sent in rotation, one at a time."
L["Use channel prefixes like /trade, /say, /yell, /p, /g, /1, /2, etc."] = "Use channel prefixes like /trade, /say, /yell, /p, /g, /1, /2, etc."

-- Settings
L["Cooldown (seconds)"] = "Cooldown (seconds)"
L["Time between each message in seconds."] = "Time between each message in seconds."
L["Mode"] = "Mode"
L["One message per cooldown"] = "One message per cooldown"
L["All messages at once"] = "All messages at once"
L["Warning: Too many messages (%d). Maximum is 10 for 'All messages at once' mode."] = "Warning: Too many messages (%d). Maximum is 10 for 'All messages at once' mode."
L["Messages"] = "Messages"
L["Add Message"] = "Add Message"
L["Enter your message (with channel prefix like /trade, /say, /p):"] = "Enter your message (with channel prefix like /trade, /say, /p):"
L["Add"] = "Add"
L["Cancel"] = "Cancel"
L["Delete"] = "Delete"
L["Copy"] = "Copy"
L["Move Up"] = "Move Up"
L["Move Down"] = "Move Down"

-- Controls
L["Start"] = "Start"
L["Stop"] = "Stop"
L["Status"] = "Status"
L["Running"] = "Running"
L["Stopped"] = "Stopped"
L["Messages Sent"] = "Messages Sent"
L["Next message in"] = "Next message in"

-- Slash commands
L["Available commands:"] = "Available commands:"
L["Usage: /tsm tradechat <command>"] = "Usage: /tsm tradechat <command>"
L["add \"message\" - Add a new message to the rotation"] = "add \"message\" - Add a new message to the rotation"
L["start - Start sending messages"] = "start - Start sending messages"
L["stop - Stop sending messages"] = "stop - Stop sending messages"
L["help - Show this help"] = "help - Show this help"

-- Messages
L["Message added: %s"] = "Message added: %s"
L["Message sending started."] = "Message sending started."
L["Message sending stopped."] = "Message sending stopped."
L["No messages configured. Add messages first."] = "No messages configured. Add messages first."
L["Already running."] = "Already running."
L["Not running."] = "Not running."
L["Message deleted."] = "Message deleted."
L["Sent: %s"] = "Sent: %s"

-- Item List Mode
L["Item list"] = "Item list"
L["Item List Settings"] = "Item List Settings"
L["Item List"] = "Item List"
L["Prefix"] = "Prefix"
L["Suffix"] = "Suffix"
L["Text before the item links (e.g., 'WTS:')"] = "Text before the item links (e.g., 'WTS:')"
L["Text after the item links (e.g., 'PST!')"] = "Text after the item links (e.g., 'PST!')"
L["Channel"] = "Channel"
L["Channel to send messages (e.g., /trade, /say, /yell)"] = "Channel to send messages (e.g., /trade, /say, /yell)"
L["Items per message"] = "Items per message"
L["Price format"] = "Price format"
L["Round to gold"] = "Round to gold"
L["Gold and silver"] = "Gold and silver"
L["No price"] = "No price"
L["items"] = "items"
L["Item"] = "Item"
L["Price"] = "Price"
L["Add Item"] = "Add Item"
L["Item link (Shift+Click item)"] = "Item link (Shift+Click item)"
L["Price (copper, optional)"] = "Price (copper, optional)"
L["Clear All"] = "Clear All"
L["No items in the list. Add items manually or use the 'Add to TradeChat' button in the AuctionsTab."] = "No items in the list. Add items manually or use the 'Add to TradeChat' button in the AuctionsTab."
L["No items in the list. Add items first."] = "No items in the list. Add items first."
L["Please enter an item link."] = "Please enter an item link."
