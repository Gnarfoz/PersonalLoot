PersonalLoot = LibStub("AceAddon-3.0"):NewAddon("PersonalLoot", "AceConsole-3.0", "AceEvent-3.0")

function PersonalLoot:trace(message)
	if self.debugging then
		self:Print(message)
	end
end

function PersonalLoot:CHAT_MSG_LOOT(id, message)
	local owner, item_link

	_, _, item_link = string.find(message, "You receive loot: (|.+|r)")
	if item_link then
		owner = "player"
	else
		_, _, owner, item_link = string.find(message, "(.+) receives loot: (|.+|r)")
		if not(owner and item_link) then
			return
		end
	end

	if self:IsTradable(owner, item_link) then
		self:trace("item is tradable")
		self:EnumerateTradees(owner, item_link)
	end
end

function PersonalLoot:PARTY_LOOT_METHOD_CHANGED()
	local method = GetLootMethod()
	self:trace("PARTY_LOOT_METHOD_CHANGED: "..method)
	self.is_personal_loot = method == "personalloot"
	self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:ZONE_CHANGED_NEW_AREA()
	self.in_raid = select(2, IsInInstance()) == "raid"
	self:trace("ZONE_CHANGED_NEW_AREA")
	self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:UpdateChatMsgLootRegistration()
	if (self.debugging or self.in_raid) and self.is_personal_loot then
		self:RegisterEvent("CHAT_MSG_LOOT")
	else
		self:UnregisterEvent("CHAT_MSG_LOOT")
	end
end

function PersonalLoot:IsTradable(owner, item)
	local _, _, _, level, _, _, _, _, slot_name = GetItemInfo(item)
	-- TODO: exit early on < epic
	if slot_name == "" then
		return
	end

	self:trace("slot name "..slot_name)

	local slot_id = GetInventorySlotInfo(slot_name)
	self:trace("slot id "..slot_id)

	local equipped_item = GetInventoryItemID(owner, slot_id)
	-- TODO:
	-- What if no item is equipped?
	-- How about 2 trinkets, 2 rings, 2 weapons, one with a higher ilvl, one with lower?

	local equipped_item_level = select(4, GetItemInfo(equipped_item))
	self:trace("equipped "..equipped_item_level..", "..level..", slot="..slot)
	return equipped_item_level > level
end

function PersonalLoot:EnumerateTradees(owner, item_id)

end

function PersonalLoot:OnEnable()
	self:trace("OnEnable")
	self.debugging = false
	-- Reloading the UI doesn't result in these events being fired, so force them
	self:PARTY_LOOT_METHOD_CHANGED()
	self:ZONE_CHANGED_NEW_AREA()
	self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function PersonalLoot:OnDisable()
	self:trace("OnDisable")
	self:UnregisterAllEvents()
end
