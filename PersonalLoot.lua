PersonalLoot = LibStub("AceAddon-3.0"):NewAddon("PersonalLoot", "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0")

local INSPECT_DIST = 285*285
local RED = "cffff0000"
local PLAYER = "player"
local ITEM_QUALITY_RARE = 3
local ITEM_QUALITY_EPIC = 4
local FURY_WARRIOR_SPEC_ID = 72
local MISCELLANEOUS = 1
local CLOTH = 2
local LEATHER = 3
local MAIL = 4
local PLATE = 5
local RESTORATION_DRUID = 105
local BALANCE_DRUID = 102
local MISTWEAVER_MONK = 270
local HOLY_PALADIN = 65
local ENHANCEMENT_SHAMAN = 263

local ANNOUNCER_NEGOTIATION_CHANNEL = "PLAnnNeg"

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
          desc = "Turn debug messages on/off",
          type = "toggle",
          order = 2,
          set = function(info, val) PersonalLoot.isDebugging = val end,
          get = function(info) return PersonalLoot.isDebugging end,
        },
        debug = {
          name = "Verbose",
          desc = "Turn verbose debug messages on/off",
          type = "toggle",
          order = 2,
          set = function(info, val) PersonalLoot.isVerbose = val end,
          get = function(info) return PersonalLoot.isVerbose end,
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

function PersonalLoot:Announce(message)
  if not message then
    self:Error("Announce called with a nil message")
    return
  end

  if not self.isAnnouncer then
    return
  end

  SendChatMessage(message, INSTANCE_CHAT, "COMMON", nil)
end

function PersonalLoot:PLAYER_TARGET_CHANGED(cause)
    local playerName = GetUnitName("playertarget")
    self:InspectEquipment(playerName)
end

function PersonalLoot:GROUP_JOINED()
  self:Trace("GROUP_JOINED")
  self:TryToBecomeAnnouncer()
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

  _, _, itemLink = string.find(message, "You receive loot: (|.+|r)")
  if not itemLink then
    _, _, owner, itemLink = string.find(message, "(.+) receives loot: (|.+|r)")
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
      self:Announce(itemLink.." owned by "..owner.." is tradable.")
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
  self:Vtrace("PARTY_LOOT_METHOD_CHANGED: "..method)
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

function PersonalLoot:WeaponIsTwoHanded(itemLink)
  return select(9, GetItemInfo(itemLink)) == "INVTYPE_2HWEAPON"
end

-- unit must be being inspected
function PersonalLoot:UnitIsFuryWarrior(unit)
  return UnitClass(unit) == "Warrior" and GetInspectSpecialization() == FURY_WARRIOR_SPEC_ID
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
    -- WeaponSlot means it's either a 2H or 1H weapon without main hand or off
    -- hand restriction.
    -- Fury warriors can dual wield two handed weapons
    if not self:WeaponIsTwoHanded() or self:UnitIsFuryWarrior(owner) then
      return self:GetRealItemLevelBySlotName(owner, "MainHandSlot") >= itemLevel
             and self:GetRealItemLevelBySlotName(owner, "SecondaryHandSlot") >= itemLevel
    end
    return self:GetRealItemLevelBySlotName(owner, "MainHandSlot") >= itemLevel
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

-- Return MISCELLANEOUS, CLOTH, LEATHER, MAIL or PLATE
function PersonalLoot:GetArmorTypeIndex(itemLink)
  local _, _, _, _, _, class, subClass = GetItemInfo(itemLink)
  local classIndex, subClassIndex = GetAuctionInvTypes(class, subClass)
  return subClassIndex
end

-- Returns a player class index or nil
function PersonalLoot:GetArmorClassRestriction(itemLink)
  return nil
end

function PersonalLoot:UnitCanUseArmorType(unit, armorTypeId)
  if armorTypeId == MISCELLANEOUS then
    return true
  end

  local unitClass = UnitClass(unit)

  if unitClass == "Death Knight" then
    return armorTypeId == PLATE
  elseif unitClass == "Demon Hunter" then
    return armorTypeId == LEATHER
  elseif unitClass == "Druid" then
    return armorTypeId == LEATHER
  elseif unitClass == "Hunter" then
    return armorTypeId == MAIL
  elseif unitClass == "Mage" then
    return armorTypeId == CLOTH
  elseif unitClass == "Monk" then
    return armorTypeId == LEATHER
  elseif unitClass == "Paladin" then
    return armorTypeId == PLATE
  elseif unitClass == "Priest" then
    return armorTypeId == CLOTH
  elseif unitClass == "Rogue" then
    return armorTypeId == LEATHER
  elseif unitClass == "Shaman" then
    return armorTypeId == MAIL
  elseif unitClass == "Warlock" then
    return armorTypeId == CLOTH
  elseif unitClass == "Warrior" then
    return armorTypeId == PLATE
  end

  self:Error("Unknown unit class "..unitClass)
  return false
end

function PersonalLoot:ItemHasPrimaryStat(itemLink, statId)
  -- TODO: implement
  -- if statId is nil then check whether the item has no primary stat
end

-- The unit must be being inspected and have inspect data available
-- Returns INTELLECT, STRENGTH, AGILITY or nil
function PersonalLoot:GetUnitPrimaryStat(unit)
  local unitClass = UnitClass(unit)
  local unitSpec = GetInspectSpecialization()

  if unitClass == "Death Knight" then
    return STRENGTH
  else if unitClass == "Demon Hunter" then
    return AGILITY
  else if unitClass == "Druid" then
    if unitSpec == RESTORATION_DRUID or unitSpec == BALANCE_DRUID then
      return INTELLECT
    else
      return AGILITY
    end
  else if unitClass == "Hunter" then
    return AGILITY
  else if unitClass == "Mage" then
    return INTELLECT
  else if unitClass == "Monk" then
    if unitSpec == MISTWEAVER_MONK then
      return INTELLECT
    else
      return AGILITY
    end
  else if unitClass == "Paladin" then
    if unitSpec == HOLY_PALADIN then
      return INTELLECT
    else
      return AGILITY
    end
  else if unitClass == "Priest" then
    return INTELLECT
  else if unitClass == "Rogue" then
    return AGILITY
  else if unitClass == "Shaman" then
    if unitSpec == ENHANCEMENT_SHAMAN then
      return AGILITY
    else
      return INTELLECT
    end
  else if unitClass == "Warlock" then
    return INTELLECT
  else if unitClass == "Warrior" then
    return STRENGTH
  end

  self:Error("Unknown primary stat for "..unit)
  return nil
end

function PersonalLoot:UnitCanUse(unit, itemLink)
  local classRestriction = self:GetArmorClassRestriction(itemLink)

  if classRestriction and classRestriction ~= unitClass then
    self:Vtrace(unit.." can't use items restricted to class "..tostring(classRestriction))
    return false
  end

  local armorTypeId = self:GetArmorTypeIndex(itemLink)

  if not UnitCanUseArmorType(unit, armorTypeId) then
    self:Vtrace(unit.." can't use armor type "..tostring(armorTypeId))
    return false
  end

  if armorTypeId == MISCELLANEOUS then
    -- Legion accessories can have no primary stat, making it usable by all
    if not self:ItemHasPrimaryStat(itemLink, nil) and not self:ItemHasPrimaryStat(itemLink, self:GetUnitPrimaryStat(unit)) then
      return false
    end
  end

  -- TODO: Handle relics

  return true
end

function PersonalLoot:StopAnnouncing()
  if self.isAnnouncer then
    self:Trace("I'm no longer the announcer.")
    self:SendCommMessage(ANNOUNCER_NEGOTIATION_CHANNEL, "LEAVING", "RAID")
  end
end

function PersonalLoot:TryToBecomeAnnouncer()
  self.isAnnouncer = true
  self:SendCommMessage(ANNOUNCER_NEGOTIATION_CHANNEL, "ME?", "RAID")
end

function PersonalLoot:GetRaidLeader()
  -- TODO: implement
  return nil
end

function PersonalLoot:OnCommReceived(prefix, message, distribution, sender)
  self:Trace("OnCommReceived: "..prefix..", "..message..", "..distribution..", "..sender)
  if message == "LEAVING" then
    self:TryToBecomeAnnouncer()
    return
  end

  if not message == "ME?" then
    return
  end

  if not self.isAnnouncer then
    self:Vtrace("I'm not the announcer, so ignore it")
    return
  end

  -- Priority for becoming the announcer is:
  -- 1. Raid leader
  -- 2. Raid leader's highest ranked guildy with the lowest alphabetical name
  -- 3. Raid member with the lowest alphabetical name

  -- 1.
  if IsGroupLeader(sender) then
    self:Vtrace("I'm not the announcer because I'm not the raid leader.")
    self.isAnnouncer = false
    return
  end

  local leader = self:GetRaidLeader()
  local leaderGuild = GetGuildInfo(leader)
  local senderGuild, _, senderGuildRank = GetGuildInfo(sender)
  local guild, _, guildRank = GetGuildInfo("player")

  -- 2.
  if senderGuild == leaderGuild then
    if not guild == leaderGuild then
      self:Vtrace("I'm not the announcer because I'm not the raid leader's guildy.")
      self.isAnnouncer = false
      return
    end

    if senderGuildRank < guildRank then
      self:Vtrace("I'm not the announcer because I have a worse guild rank.")
      self.isAnnouncer = false
      return
    elseif senderGuildRank == guildRank then
      if sender < UnitName("player") then
        self:Vtrace("I'm not the announcer because I'm an alphabetically challenged guildy.")
        self.isAnnouncer = false
        return
      end
    end
  -- 3.
  elseif not guild == leaderGuild then
    if sender < UnitName("player") then
      self:Vtrace("I'm not the announcer I'm an alphabetically challenged random.")
      self.isAnnouncer = false
      return
    end
  end

  self:Vtrace("I'm pretty important, I should remain the announcer...")
  self:TryToBecomeAnnouncer()
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
  self:RegisterEvent("GROUP_JOINED")
  self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  -- self:RegisterEvent("PLAYER_TARGET_CHANGED")

  self:RegisterComm(ANNOUNCER_NEGOTIATION_CHANNEL, self:OnCommReceived)

  self:TryToBecomeAnnouncer()
end

function PersonalLoot:OnDisable()
  self:Trace("OnDisable")
  self:StopAnnouncing()
  self:UnregisterAllEvents()
end
