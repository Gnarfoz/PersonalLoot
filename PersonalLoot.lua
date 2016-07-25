PersonalLoot = LibStub("AceAddon-3.0"):NewAddon("PersonalLoot", "AceConsole-3.0", "AceEvent-3.0")
INSPECT_DIST = 285*285

local options = {
  name = "Personal Loot",
  type = "group",
  args = {
    debug = {
      name = "Debug",
      desc = "Turn debugging options on/off",
      type = "toggle",
      set = function(info, val) PersonalLoot.debugging = val end,
      get = function(info) return PersonalLoot.debugging end
    },
    itemType = {
      name = "Item Type",
      desc = "Minimal item type to work with",
      type = "select",
      style = "dropdown",
      values = {
        GREY="grey",
        WHITE="white",
        GREEN="green",
        RARE="rare",
        EPIC="epic",
      },
      set = function(info, val) PersonalLoot.itemType = val end,
      get = function(info) return PersonalLoot.itemType end
    }
  }
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("PersonalLoot", options, "pl")
--PersonalLoot.configPanel:AssignOptions(PersonalLoot)
--LibStub("AceConfigDialog-3.0"):Open("PersonalLoot")

function PersonalLoot:Trace(message)
  if self.debugging then
    self:Print(message)
  end
end

function PersonalLoot:PLAYER_TARGET_CHANGED(cause)
  local playerName = GetUnitName("playertarget")
  if playerName then
    self:RegisterEvent("INSPECT_READY")
    NotifyInspect(playerName)
  end
end

function PersonalLoot:INSPECT_READY()
  self:UnregisterEvent("INSPECT_READY")
  local playerName, realm = UnitName("target")
  id = GetInventorySlotInfo("LegsSlot")
  link = GetInventoryItemLink("target", id)
  if not link then
    distanceSquared, valid = UnitDistanceSquared(playerName)
    if not valid or distanceSquared >= INSPECT_DIST then
      self:Trace(playerName.." is too far to inspect!")
      return
    end
  end
  self:Trace(playerName.." "..link)
  self:RegisterEvent("INSPECT_READY")
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
    self:Trace("item is tradable")
    self:EnumerateTradees(owner, item_link)
  end
end

function PersonalLoot:PARTY_LOOT_METHOD_CHANGED()
  local method = GetLootMethod()
  self:Trace("PARTY_LOOT_METHOD_CHANGED: "..method)
  self.is_personal_loot = method == "personalloot"
  self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:ZONE_CHANGED_NEW_AREA()
  self.in_raid = select(2, IsInInstance()) == "raid"
  self:Trace("ZONE_CHANGED_NEW_AREA")
  self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:UpdateChatMsgLootRegistration()
  if (self.debugging or self.in_raid) and self.is_personal_loot then
    self:RegisterEvent("CHAT_MSG_LOOT")
  else
    self:UnregisterEvent("CHAT_MSG_LOOT")
  end
end


function PersonalLoot:EquipSlotNameToInventoryName(name)
  -- FingerSlot is for Finger0Slot / Finger1Slot
  -- TrinketSlot is for Trinket0Slot / Trinket1Slot
  -- WeaponSlot is for any weapon which isn't specifically main or off hand
  -- TODO: Handle ranged weapons and relics
  local map = {
    -- Fury warrior's can wield a 2H in each hand
    [ "INVTYPE_2HWEAPON" ] = "WeaponSlot",
    [ "INVTYPE_FEET" ] = "FeetSlot",
    [ "INVTYPE_FINGER" ] = "FingerSlot",
    [ "INVTYPE_CHEST" ] = "ChestSlot",
    [ "INVTYPE_CLOAK" ] = "BackSlot",
    [ "INVTYPE_HAND" ] = "HandsSlot",
    [ "INVTYPE_HEAD" ] = "HeadSlot",
    [ "INVTYPE_LEGS" ] = "LegsSlot",
    [ "INVTYPE_NECK" ] = "NeckSlot",
    [ "INVTYPE_RANGEDRIGHT" ] = "WeaponSlot",
    [ "INVTYPE_ROBE" ] = "ChestSlot",
    [ "INVTYPE_SHIRT" ] = "ShirtSlot",
    [ "INVTYPE_SHOULDER" ] = "ShoulderSlot",
    [ "INVTYPE_TABARD" ] = "TabardSlot",
    [ "INVTYPE_TRINKET" ] = "TrinketSlot",
    [ "INVTYPE_WAIST" ] = "WaistSlot",
    [ "INVTYPE_WEAPONMAINHAND" ] = "MainHandSlot",
    [ "INVTYPE_WEAPON" ] = "WeaponSlot",
    [ "INVTYPE_WRIST" ] = "WristSlot",
  }

  local out = map[name]

  if not out then
    self:Print("Unable to convert "..name)
    return nil
  else
    self:Trace("Converted "..name.." to "..out)
  end

  return out
end

function PersonalLoot:IsTradable(owner, item)
  local _, _, _, level, _, _, _, _, slot_name = GetItemInfo(item)
  -- TODO: exit early on < epic
  if slot_name == "" then
    return
  end

  slot_name = self:EquipSlotNameToInventoryName(slot_name)
  if not slot_name then
    return
  end

  if slot_name == "FingerSlot" then
    -- TODO: handle it
    return
  elseif slot_name == "TrinketSlot" then
    -- TODO: handle it
    return
  elseif slot_name == "WeaponSlot" then
    -- TODO: handle it
    return
  end

  local slot_id = GetInventorySlotInfo(slot_name)
  self:Trace("slot id "..slot_id)

  local equipped_item_link = GetInventoryItemLink(owner, slot_id)
  if not equipped_item_link then
    -- No item is equipped
    return true
  end

  local equipped_item_level = select(4, GetItemInfo(equipped_item_link))
  self:Trace("Equipped item level: "..equipped_item_level)

  return equipped_item_level > level
end

function PersonalLoot:EnumerateTradees(owner, item_id)

end

function PersonalLoot:OnEnable()
  self:Trace("OnEnable")
  self.debugging = true
  self.itemType = "epic"
  -- Reloading the UI doesn't result in these events being fired, so force them
  self:PARTY_LOOT_METHOD_CHANGED()
  self:ZONE_CHANGED_NEW_AREA()
  self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function PersonalLoot:OnDisable()
  self:Trace("OnDisable")
  self:UnregisterAllEvents()
end
