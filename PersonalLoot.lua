PersonalLoot = LibStub("AceAddon-3.0"):NewAddon("PersonalLoot", "AceConsole-3.0", "AceEvent-3.0")

local INSPECT_DIST = 285*285
local RED = "cffff0000"
local PLAYER = "player"
local ITEM_QUALITY_RARE = 3
local ITEM_QUALITY_EPIC = 4
local FURY_WARRIOR_SPEC_ID = 72

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

function PersonalLoot:Vtrace(message)
  if self.isVerbose then
    self:Trace(message)
  end
end

function PersonalLoot:Error(message)
  self:ColouredPrint(message, RED)
end

function PersonalLoot:ColouredPrint(message, colour)
  self:Print("|"..colour..message)
end

function table.isEmpty(table)
  return next(table) == nil
end

function table.getIndex(table, val)
    for index, value in ipairs(table) do
        if value == val then
            return index
        end
    end

    return -1
end

function PersonalLoot:PLAYER_TARGET_CHANGED(cause)
    local playerName = GetUnitName("playertarget")
    self:InspectEquipment(playerName)
end

function PersonalLoot:InspectEquipment(playerName)
    if playerName and CanInspect(playerName) then
      self:RegisterEvent("INSPECT_READY")
      self:Vtrace("Starting equipment inspection for "..playerName.."...")
      table.insert(self.currentPlayers, playerName)
      NotifyInspect(playerName)
    end
end

function PersonalLoot:INSPECT_READY(fnName, playerGuid)
  local _, _, _, _, _, playerName, _ = GetPlayerInfoByGUID(playerGuid)
  if table.getIndex(self.currentPlayers, playerName) < 0 then
    return
  end

  -- Cache all of the equipment slots
  for id=0,19,1 do
    link = GetInventoryItemLink(playerName, id)
    if not link then
      distanceSquared, valid = UnitDistanceSquared(playerName)
      if not valid or distanceSquared >= INSPECT_DIST then
        ClearInspectPlayer()
        self:Error(playerName.." is too far to inspect!")
        return
      end
    end
  end

  -- getIndex again to make sure we don't have an outdated value
  table.remove(self.currentPlayers, table.getIndex(self.currentPlayers, playerName))
  self:Vtrace("Finished inspecting "..playerName)
  if table.isEmpty(self.currentPlayers) then
    self:UnregisterEvent("INSPECT_READY")
    if self.isLootInspect then
      self:LootInspection(playerName, self.currentLoot)
    end
  end
end

function PersonalLoot:CHAT_MSG_LOOT(id, message)
  local owner, itemLink = PLAYER, nil

  _, _, itemLink = string.find(message, "You receive.+loot: (|.+|r)")
  if not itemLink then
    _, _, owner, itemLink = string.find(message, "(.+) receives.+loot: (|.+|r)")
  end

  if not (owner and itemLink) then
    self:Vtrace("Owner or itemLink is empty in CHAT_MSG_LOOT. Owner: "..tostring(owner==nil).." Item:"..tostring(itemLink==nil))
    return
  end

  if not self:IsEquipment(owner, itemLink) then
    self:Vtrace(itemLink.." is not an equippable item so ignoring...")
    return
  end

  if owner ~= PLAYER then
    self.currentLoot = itemLink
    self.isLootInspect = true
    self:InspectEquipment(owner)
  else
    self:LootInspection(owner, itemLink)
  end
end

function PersonalLoot:LootInspection(owner, itemLink)
  self.isLootInspect = false

  if owner and itemLink then
    if self:IsTradable(owner, itemLink) then
      self:Trace(itemLink.." owned by "..owner.." is tradable.")
      self:EnumerateTradees(owner, itemLink)
    else
      self:Trace(itemLink.." owned by "..owner.." is not tradable.")
    end
  else
    self:Error("Owner or itemLink is empty in LootInspection. Owner: "..tostring(owner==nil).." Item:"..tostring(itemLink==nil))
  end
end

function PersonalLoot:PARTY_LOOT_METHOD_CHANGED()
  local method = GetLootMethod()
  self:Trace("PARTY_LOOT_METHOD_CHANGED: "..method)
  self.isPersonalLoot = method == "personalloot"
  self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:ZONE_CHANGED_NEW_AREA()
  self.instanceType = select(2, IsInInstance())
  self:Vtrace("ZONE_CHANGED_NEW_AREA: "..self.instanceType)
  self:UpdateChatMsgLootRegistration()
end

function PersonalLoot:UpdateChatMsgLootRegistration()
  if (self.isDebugging or self.instanceType == "raid") and self.isPersonalLoot then
    self:RegisterEvent("CHAT_MSG_LOOT")
  else
    self:UnregisterEvent("CHAT_MSG_LOOT")
  end
end


function PersonalLoot:InvTypeToEquipSlotName(name)
  -- FingerSlot is for Finger0Slot / Finger1Slot
  -- TrinketSlot is for Trinket0Slot / Trinket1Slot
  -- WeaponSlot is for any weapon which isn't specifically main or off hand
  -- TODO: Handle relics
  local map = {
    [ "INVTYPE_2HWEAPON" ] = "WeaponSlot",
    [ "INVTYPE_FEET" ] = "FeetSlot",
    [ "INVTYPE_FINGER" ] = "FingerSlot",
    [ "INVTYPE_CHEST" ] = "ChestSlot",
    [ "INVTYPE_CLOAK" ] = "BackSlot",
    [ "INVTYPE_HAND" ] = "HandsSlot",
    [ "INVTYPE_HOLDABLE" ] = "SecondaryHandSlot",
    [ "INVTYPE_HEAD" ] = "HeadSlot",
    [ "INVTYPE_LEGS" ] = "LegsSlot",
    [ "INVTYPE_NECK" ] = "NeckSlot",
    [ "INVTYPE_RANGED" ] = "WeaponSlot",
    [ "INVTYPE_RANGEDRIGHT" ] = "WeaponSlot",
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
    self:Vtrace("Converted "..name.." to "..out)
  end

  return out
end

local upgradeTable = {
  ["529"] = 0,
  ["530"] = 5,
  ["531"] = 10,
}

-- itemLink must be valid
function PersonalLoot:GetRealItemLevel(itemLink)
  local itemLevel = select(4, GetItemInfo(itemLink))
  local numBonuses = select(14, strsplit(":", link, 15))
  local affixes = select(15, strsplit(":", link, 15))

  -- loop over item bonuses in search for upgrade
  for i = 1, numBonuses+1 do
      local bonusID = select(i, strsplit(":", affixes))
      if upgradeTable[bonusID] ~= nil then
          itemLevel = itemLevel + upgradeTable[bonusID]
      end
  end

  self:Trace(itemLink.." has item level "..itemLevel)
  return itemLevel
end

function PersonalLoot:GetRealItemLevelBySlotName(owner, slotName)
  local slotId = GetInventorySlotInfo(slotName)
  return self:GetRealItemLevel(GetInventoryItemLink(owner, slotId))
end

function PersonalLoot:IsEquipment(owner, itemLink)
  if not owner or not itemLink then
    self:Error("IsEquipment received nil owner or itemLink")
    return false
  end

  local _, _, quality, _, _, _, _, _, invType = GetItemInfo(itemLink)

  if invType == "" then
    -- It's not an equippable item
    self:Vtrace(itemLink.." has no slotName")
    return false
  end

  if not self.allItemTypes then
    if self.instanceType == "raid" and quality < ITEM_QUALITY_EPIC then
      self:Trace("Quality is "..quality.." so ignoring...")
      return false
    elseif self.instanceType == "party" and quality < ITEM_QUALITY_RARE then
      self:Vtrace("Quality is "..quality.." so ignoring...")
      return false
    end
  end

  slotName = self:InvTypeToEquipSlotName(invType)
  if not slotName then
    return false
  end

  return true
end

-- Inspect data must be ready before calling this
-- TODO:
-- might have to call ClearInspectPlayer() when we're done using
-- the inspected info
function PersonalLoot:IsTradable(owner, itemLink)
  local itemLevel = self:GetRealItemLevel(itemLink)

  if slotName == "FingerSlot" then
    return self:GetRealItemLevelBySlotName(owner, "Finger0Slot") >= itemLevel
           and self:GetRealItemLevelBySlotName(owner, "Finger1Slot") >= itemLevel
  elseif slotName == "TrinketSlot" then
    return self:GetRealItemLevelBySlotName(owner, "Trinket0Slot") >= itemLevel
           and self:GetRealItemLevelBySlotName(owner, "Trinket1Slot") >= itemLevel
  elseif slotName == "WeaponSlot" then
    if UnitClass(owner) == "Warrior" and GetInspectSpecialization() == FURY_WARRIOR_SPEC_ID then
      -- TODO: implement
      self:Vtrace(owner.." is a Fury Warrior, handle 2H in each hand.")
      return false
    end
    -- TODO:
    -- Only Hunters care about ranged weapons (what about wands?)
    -- Handle main hand, off hand, shield
    return false
  end

  local slotId = GetInventorySlotInfo(slotName)
  self:Vtrace("slot id "..slotId)

  local equippedItemLink = GetInventoryItemLink(owner, slotId)
  if equippedItemLink == "" then
    self:Trace("No item is equipped in "..slotName)
    return true
  end

  return self:GetRealItemLevel(equippedItemLink) > itemLevel
end

-- owner and itemLink must be valid
function PersonalLoot:EnumerateTradees(owner, itemLink)
  names = GetHomePartyInfo()
  if not names then
    self:Error("Can not get party members!")
    return
  end

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
  self.isVerbose = false
  self.allItemTypes = true
  self.isLootInspect = false
  self.currentPlayers = {}
  self.currentLoot = nil
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
