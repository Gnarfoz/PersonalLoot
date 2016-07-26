PersonalLoot = LibStub("AceAddon-3.0"):NewAddon("PersonalLoot", "AceConsole-3.0", "AceEvent-3.0")
INSPECT_DIST = 285*285
RED = "cffff0000"

-- Options table
local options = {
  name = "PersonalLoot",
  handler = PersonalLoot,
  type = "group",
  args = {
    general = {
      type = "group",
      name = "General",
      order = 1,
      inline = true,
      args = {
        enable = {
          name = "Enable",
          desc = "Turn PersonalLoot on/off",
          type = "toggle",
          order = 1,
          get = "IsEnabled",
          set = function(_, newVal)
            if (not newVal) then
              PersonalLoot:Disable();
            else
              PersonalLoot:Enable();
            end
          end,
        },
        debug = {
          name = "Debug",
          desc = "Turn isDebugging options on/off",
          type = "toggle",
          order = 2,
          set = function(info, val) PersonalLoot.isDebugging = val end,
          get = function(info) return PersonalLoot.isDebugging end,
        },
        allItemTypes = {
          name = "All Item Types",
          desc = "Allows all item types to trigger PersonalLoot",
          type = "toggle",
          order = 3,
          set = function(info, val) PersonalLoot.allItemTypes = val end,
          get = function(info) return PersonalLoot.allItemTypes end,
        }
      }
    }
  }
}
-- Add options table as slash command and add it to the Bliiz interface
LibStub("AceConfig-3.0"):RegisterOptionsTable("PersonalLoot", options, "pl")
LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("PersonalLoot", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("PersonalLoot", "PersonalLoot")

function PersonalLoot:Trace(message)
  if self.isDebugging then
    self:Print(message)
  end
end

function PersonalLoot:Error(message)
  self:Print("|"..RED..message)
end

function PersonalLoot:PLAYER_TARGET_CHANGED(cause)
    local playerName = GetUnitName("playertarget")
    self:InspectEquipment(playerName)
end

function PersonalLoot:InspectEquipment(playerName)
    if playerName and CanInspect(playerName, false) then
      self:RegisterEvent("INSPECT_READY")
      NotifyInspect(playerName)
    end
end

function PersonalLoot:INSPECT_READY()
  self:UnregisterEvent("INSPECT_READY")
  local playerName, realm = UnitName("target")
  if self.currentLoot then
    id = GetInventorySlotInfo(select(9, GetItemInfo(itemLink)))
  else
    self:Error("No loot selected")
    return
  end
  link = GetInventoryItemLink(playerName, id)
  ClearInspectPlayer()
  if not link then
    distanceSquared, valid = UnitDistanceSquared(playerName)
    if not valid or distanceSquared >= INSPECT_DIST then
      self:Error(playerName.." is too far to inspect!")
      return
    end
  end
  self:Trace(playerName.." "..link)
  self:RegisterEvent("INSPECT_READY")
end

function PersonalLoot:CHAT_MSG_LOOT(id, message)
  local owner, itemLink

  _, _, itemLink = string.find(message, "You receive loot: (|.+|r)")
  if itemLink then
    owner = "player"
  else
    _, _, owner, itemLink = string.find(message, "(.+) receives loot: (|.+|r)")
    if not(owner and itemLink) then
      self:Error(itemLink.." has been left behind!")
      return
    end
  end

  if self:IsTradable(owner, itemLink) then
    self:Trace(itemLink.." owned by "..owner.." is tradable.")
    self:EnumerateTradees(owner, itemLink)
  end
end

function PersonalLoot:PARTY_LOOT_METHOD_CHANGED()
  local method = GetLootMethod()
  self:Trace("PARTY_LOOT_METHOD_CHANGED: "..method)
  self.isPersonalLoot = method == "personalloot"
  self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:ZONE_CHANGED_NEW_AREA()
  self.isInRaid = select(2, IsInInstance()) == "raid"
  self:Trace("ZONE_CHANGED_NEW_AREA")
  self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:UpdateChatMsgLootRegistration()
  if (self.isDebugging or self.isInRaid) and self.isPersonalLoot then
    self:RegisterEvent("CHAT_MSG_LOOT")
  else
    self:UnregisterEvent("CHAT_MSG_LOOT")
  end
end


function PersonalLoot:EquipSlotNameToInventoryName(name)
  -- FingerSlot is for Finger0Slot / Finger1Slot
  -- TrinketSlot is for Trinket0Slot / Trinket1Slot
  -- WeaponSlot is for any weapon which isn't specifically main or off hand
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
    [ "INVTYPE_RANGED" ] = "WeaponSlot",
    [ "INVTYPE_RANGEDRIGHT" ] = "WeaponSlot",
    -- TODO: INVTYPE_RELIC?
    [ "INVTYPE_ROBE" ] = "ChestSlot",
    [ "INVTYPE_SHIELD" ] = "SecondaryHandSlot",
    [ "INVTYPE_SHIRT" ] = "ShirtSlot",
    [ "INVTYPE_SHOULDER" ] = "ShoulderSlot",
    [ "INVTYPE_TABARD" ] = "TabardSlot",
    [ "INVTYPE_TRINKET" ] = "TrinketSlot",
    [ "INVTYPE_WAIST" ] = "WaistSlot",
    [ "INVTYPE_WEAPONMAINHAND" ] = "MainHandSlot",
    [ "INVTYPE_WEAPONOFFHAND" ] = "SecondaryHandSlot",
    [ "INVTYPE_WEAPON" ] = "WeaponSlot",
    [ "INVTYPE_WRIST" ] = "WristSlot",
  }

  local out = map[name]

  if not out then
    self:Error("Unable to convert "..name)
    return nil
  else
    self:Trace("Converted "..name.." to "..out)
  end

  return out
end

function PersonalLoot:GetRealItemLevel(owner, itemLink)
  local equippedItemLevel = select(4, GetItemInfo(equippedItemLink))
  self:Trace("Equipped item level: "..equippedItemLevel)
end

function PersonalLoot:IsTradable(owner, itemLink)
  local slotName = select(9, GetItemInfo(itemLink))
  -- TODO: exit early on < epic
  if slotName == "" then
    return
  end

  slotName = self:EquipSlotNameToInventoryName(slotName)
  if not slotName then
    return
  end

  if slotName == "FingerSlot" then
    -- TODO: handle it
    return
  elseif slotName == "TrinketSlot" then
    -- TODO: handle it
    return
  elseif slotName == "WeaponSlot" then
    -- TODO: handle it
    return
  end

  local slotId = GetInventorySlotInfo(slotName)
  self:Trace("slot id "..slotId)

  local equippedItemLink = GetInventoryItemLink(owner, slotId)
  if not equippedItemLink then
    -- No item is equipped
    return true
  end

  return self:GetRealItemLevel(equippedItemLink) > self:GetRealItemLevel(itemLink)
end

function PersonalLoot:EnumerateTradees(owner, itemLink)
  names = GetHomePartyInfo()
  if not names then
    self:Error("Can not get party members!")
    return
  end

  self.currentLoot = itemLink
  for index, name in pairs(names) do
    if self:UnitCanUse(name, itemLink) then
      self:InspectEquipment(name)
    end
  end
end

function PersonalLoot:UnitCanUse(unit, itemLink)
  -- TODO: Implement this
  return true
end

function PersonalLoot:OnEnable()
  self:Trace("OnEnable")
  self.isDebugging = true
  self.allItemTypes = false
  -- Reloading the UI doesn't result in these events being fired, so force them
  self:PARTY_LOOT_METHOD_CHANGED()
  self:ZONE_CHANGED_NEW_AREA()
  self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  -- self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function PersonalLoot:OnDisable()
  self:Trace("OnDisable")
  self:UnregisterAllEvents()
end
