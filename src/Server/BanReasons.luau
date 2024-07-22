local ReplicatedFirst = game:GetService("ReplicatedFirst")
local tabletobuffer = require(ReplicatedFirst.Actor.__dependencies.tabletobuffer)

return tabletobuffer.TableAsBuffer({
	SuspectedTampering = {
		DisplayReason = "You have been banned due to unexpected client behaviour",
		PrivateReason = "This player has been suspected to be tampering with zoop. This may be by modifying remote buffers or by garbage data being fed into the buffer.",
		Duration = -1,
	},
	SuspectedCheating = {
		DisplayReason = "You have been banned from due to suspected cheating.",
		PrivateReason = "This player has been suspected to be cheating by zoop.",
		Duration = -1,
	},
	DataValidationError = {
		DisplayReason = "You have been banned due to unexpected client behaviour",
		PrivateReason = "This client has sent invalid data to a zoop remote. This only occurs when the client has been tampered with, or when you, the developer, plays with the remotes when they should not.",
		Duration = -1,
	},
	Honeypotted = {
		DisplayReason = "You have been banned due to unexpected client behaviour",
		PrivateReason = "The client has attempted to call an event with unintended behaviour and bit the bullet",
		Duration = -1,
	},
})
