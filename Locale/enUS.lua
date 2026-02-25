-- Locale for enUS
local L = LibStub("AceLocale-3.0"):NewLocale("TradeSkillMaster_TradeChat", "enUS", true)
if not L then return end

-- General
L["TradeChat"] = "TradeChat"
L["Help"] = "Help"
L["Settings"] = "Settings"
L["Messages"] = "Messages"
L["enabled"] = "enabled"

-- Help texts
L["TradeChat allows you to send periodic messages to chat channels."] = "TradeChat allows you to send periodic messages to chat channels."
L["Add messages to the list, set the cooldown, and click Start."] = "Add messages to the list, set the cooldown, and click Start."
L["Messages are sent in rotation, one at a time."] = "Messages are sent in rotation, one at a time."
L["Use channel prefixes like /trade, /say, /yell, /p, /g, /1, /2, etc."] = "Use channel prefixes like /trade, /say, /yell, /p, /g, /1, /2, etc."

-- Sending settings
L["Sending"] = "Sending"
L["Cooldown (seconds)"] = "Cooldown (seconds)"
L["Time between each message in seconds."] = "Time between each message in seconds."
L["Messages per cooldown"] = "Messages per cooldown"
L["Number of messages to send each cooldown."] = "Number of messages to send each cooldown."
L["Delay between messages (s)"] = "Delay between messages (s)"
L["Seconds between each message in a batch."] = "Seconds between each message in a batch."

-- Message management
L["Add Message"] = "Add Message"
L["Enter message to add, or #N to duplicate:"] = "Enter message to add, or #N to duplicate:"
L["Enable All"] = "Enable All"
L["Disable All"] = "Disable All"
L["Add"] = "Add"
L["Delete"] = "Delete"
L["Message added: %s"] = "Message added: %s"
L["Message deleted."] = "Message deleted."
L["Message duplicated from #%d."] = "Message duplicated from #%d."
L["Invalid message #: %d"] = "Invalid message #: %d"
L["No messages configured. Add messages first."] = "No messages configured. Add messages first."
L["No enabled messages. Enable at least one."] = "No enabled messages. Enable at least one."

-- Controls
L["Start"] = "Start"
L["Stop"] = "Stop"
L["Status"] = "Status"
L["Running"] = "Running"
L["Stopped"] = "Stopped"
L["Messages Sent"] = "Messages Sent"
L["Next message in"] = "Next message in"
L["Message sending started."] = "Message sending started."
L["Message sending stopped."] = "Message sending stopped."
L["Already running."] = "Already running."
L["Not running."] = "Not running."
L["Sent: %s"] = "Sent: %s"

-- Slash commands
L["Available commands:"] = "Available commands:"
L["Usage: /tsm tradechat <command>"] = "Usage: /tsm tradechat <command>"
L["add \"message\" - Add a new message to the rotation"] = "add \"message\" - Add a new message to the rotation"
L["start - Start sending messages"] = "start - Start sending messages"
L["stop - Stop sending messages"] = "stop - Stop sending messages"
L["status - Show current status"] = "status - Show current status"
L["help - Show this help"] = "help - Show this help"

-- Recurring Message
L["Recurring Message"] = "Recurring Message"
L["Enable Recurring Message"] = "Enable Recurring Message"
L["Enable or disable the recurring message."] = "Enable or disable the recurring message."
L["Every X cooldowns"] = "Every X cooldowns"
L["Send the recurring message after this many regular messages."] = "Send the recurring message after this many regular messages."
L["This message will be sent every X cooldowns, interleaved with your regular messages."] = "This message will be sent every X cooldowns, interleaved with your regular messages."
L["Recurring message text (with channel prefix like /trade, /say, /p):"] = "Recurring message text (with channel prefix like /trade, /say, /p):"

-- Item List Mode
L["Item List"] = "Item List"
L["Use item list mode"] = "Use item list mode"
L["Send random items from a list instead of messages."] = "Send random items from a list instead of messages."
L["Item List mode is active. Configure items in the Settings tab."] = "Item List mode is active. Configure items in the Settings tab."
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
