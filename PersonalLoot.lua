-- TODO: make sure all checks which don't require an inspect are done first.
-- So check whether there are any potential tradees before inspecting the
-- owner if the owner isn't the player.
-- Remove playerItems cache on group roster update

PersonalLoot = LibStub("AceAddon-3.0"):NewAddon("PersonalLoot", "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0")
LBI = LibStub:GetLibrary("LibBabble-Inventory-3.0"):GetLookupTable()

local ANNOUNCER_NEGOTIATION_CHANNEL = "PLAnnNeg"
-- Duration is in seconds. TODO: Reduce on release
local CACHE_DURATION = 3000

local INSPECT_DIST = 285*285
local RED = "cffff0000"
local ITEM_QUALITY_RARE = 3
local ITEM_QUALITY_EPIC = 4
local FURY_WARRIOR_SPEC_ID = 72
local MISCELLANEOUS = 1
local STRENGTH = 1
local AGILITY = 2
local INTELLECT = 4
local RAID_LEADER_RANK = 2

-- Relic type mapping
local BLOOD_DEATH_KNIGHT = 250
local FROST_DEATH_KNIGHT = 251
local UNHOLY_DEATH_KNIGHT = 252
local HAVOC_DEMON_HUNTER = 577
local VENGEANCE_DEMON_HUNTER = 581
local BALANCE_DRUID = 102
local FERAL_DRUID = 103
local GUARDIAN_DRUID = 104
local RESTORATION_DRUID = 105
local BEAST_MASTERY_HUNTER = 253
local MARKSMANSHIP_HUNTER = 254
local SURVIVAL_HUNTER = 255
local ARCANE_MAGE = 62
local FIRE_MAGE = 63
local FROST_MAGE = 64
local BREWMASTER_MONK = 268
local WINDWALKER_MONK = 269
local MISTWEAVER_MONK = 270
local HOLY_PALADIN = 65
local PROTECTION_PALADIN = 66
local RETRIBUTION_PALADIN = 70
local DISCIPLINE_PRIEST = 256
local HOLY_PRIEST = 257
local SHADOW_PRIEST = 258
local ASSASSINATION_ROGUE = 259
local OUTLAW_ROGUE = 260
local SUBTLETY_ROGUE = 261
local ELEMENTAL_SHAMAN = 262
local ENHANCEMENT_SHAMAN = 263
local RESTORATION_SHAMAN = 264
local AFFLICATION_WARLOCK = 265
local DEMONOLOGY_WARLOCK = 266
local DESTRUCTION_WARLOCK = 267
local ARMS_WARRIOR = 71
local FURY_WARRIOR = 72
local PROTECTION_WARRIOR = 73

PersonalLoot.options = {
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
        announce = {
          name = "Publicly Announce",
          desc = "Turn raid/group announcements on/off",
          type = "toggle",
          order = 2,
          set = function(info, val)
            PersonalLoot.db.char.enablePublicAnnouncing = val
            if val then
              PersonalLoot:TryToBecomeAnnouncer()
            else
              PersonalLoot:StopAnnouncing()
            end
          end,
          get = function(info)
            return PersonalLoot.db.char.enablePublicAnnouncing
          end,
        },
       debug = {
          name = "Debug",
          desc = "Turn debug messages on/off",
          type = "toggle",
          order = 3,
          set = function(info, val) PersonalLoot.db.char.isDebugging = val end,
          get = function(info) return PersonalLoot.db.char.isDebugging end,
        },
        verbose = {
          name = "Verbose",
          desc = "Turn verbose debug messages on/off",
          type = "toggle",
          order = 4,
          set = function(info, val) PersonalLoot.db.char.isVerbose = val end,
          get = function(info) return PersonalLoot.db.char.isVerbose end,
        },
        allItemTypes = {
          name = "All Item Types",
          desc = "Allows all item types to trigger PersonalLoot",
          type = "toggle",
          order = 5,
          set = function(info, val) PersonalLoot.db.char.allItemTypes = val end,
          get = function(info) return PersonalLoot.db.char.allItemTypes end,
        }
      }
    }
  }
}

PersonalLoot.defaultOptions = {
  char = {
    enablePublicAnnouncing = false,
    isDebugging = false,
    isVerbose = false,
    allItemTypes = false,
  }
}

PersonalLoot.relicTypes = {
  [ "ARCANE" ] = {VENGEANCE_DEMON_HUNTER, BALANCE_DRUID, BEAST_MASTERY_HUNTER,
                ARCANE_MAGE, FIRE_MAGE, FROST_MAGE, PROTECTION_PALADIN},
  [ "BLOOD" ] = {BLOOD_DEATH_KNIGHT, UNHOLY_DEATH_KNIGHT, FERAL_DRUID, GUARDIAN_DRUID,
               MARKSMANSHIP_HUNTER, SURVIVAL_HUNTER, SHADOW_PRIEST, ASSASSINATION_ROGUE,
               OUTLAW_ROGUE, AFFLICATION_WARLOCK, ARMS_WARRIOR, PROTECTION_WARRIOR},
  [ "FEL" ] = {HAVOC_DEMON_HUNTER, VENGEANCE_DEMON_HUNTER, SUBTLETY_ROGUE, DEMONOLOGY_WARLOCK,
             DESTRUCTION_WARLOCK},
  [ "FIRE" ] = {UNHOLY_DEATH_KNIGHT, GUARDIAN_DRUID, FIRE_MAGE, RETRIBUTION_PALADIN,
              ENHANCEMENT_SHAMAN, DEMONOLOGY_WARLOCK, DESTRUCTION_WARLOCK,
              FURY_WARRIOR, PROTECTION_WARRIOR},
  [ "FROST" ] = {FROST_DEATH_KNIGHT, FERAL_DRUID, RESTORATION_DRUID, ARCANE_MAGE,
               FROST_MAGE, MISTWEAVER_MONK, ELEMENTAL_SHAMAN, RESTORATION_SHAMAN},
  [ "HOLY" ] = {HOLY_PALADIN, PROTECTION_PALADIN, RETRIBUTION_PALADIN, DISCIPLINE_PRIEST,
              HOLY_PRIEST},
  [ "IRON" ] = {BLOOD_DEATH_KNIGHT, VENGEANCE_DEMON_HUNTER, BEAST_MASTERY_HUNTER,
              SURVIVAL_HUNTER, BREWMASTER_MONK, WINDWALKER_MONK, PROTECTION_PALADIN,
              ASSASSINATION_ROGUE, OUTLAW_ROGUE, ENHANCEMENT_SHAMAN, ARMS_WARRIOR,
              FURY_WARRIOR, PROTECTION_WARRIOR},
  [ "LIFE" ] = {BALANCE_DRUID, FERAL_DRUID, GUARDIAN_DRUID, RESTORATION_DRUID,
              MARKSMANSHIP_HUNTER, BREWMASTER_MONK, MISTWEAVER_MONK, HOLY_PALADIN,
              HOLY_PRIEST, RESTORATION_SHAMAN},
  [ "SHADOW" ] = {BLOOD_DEATH_KNIGHT, FROST_DEATH_KNIGHT, UNHOLY_DEATH_KNIGHT,
                HAVOC_DEMON_HUNTER, DISCIPLINE_PRIEST, SHADOW_PRIEST, ASSASSINATION_ROGUE,
                SUBTLETY_ROGUE, AFFLICATION_WARLOCK, DEMONOLOGY_WARLOCK, ARMS_WARRIOR},
  [ "STORM" ] = {BEAST_MASTERY_HUNTER, MARKSMANSHIP_HUNTER, SURVIVAL_HUNTER, BREWMASTER_MONK,
               MISTWEAVER_MONK, WINDWALKER_MONK, OUTLAW_ROGUE, ELEMENTAL_SHAMAN,
               ENHANCEMENT_SHAMAN, FURY_WARRIOR},
}

-- TODO: What about off hands?
-- TODO: Cloaks
PersonalLoot.classProficiencies = {
  [ "DEATHKNIGHT" ] = {
    LBI["Fishing Poles"], LBI["One-Handed Axes"], LBI["One-Handed Maces"],
    LBI["One-Handed Swords"], LBI["Plate"], LBI["Polearms"],
    LBI["Two-Handed Axes"], LBI["Two-Handed Maces"], LBI["Two-Handed Swords"]
  },
  [ "DEMONHUNTER" ] = {
    LBI["Daggers"], LBI["Fishing Poles"], LBI["Fist Weapons"], LBI["Leather"],
    LBI["One-Handed Axes"], LBI["One-Handed Maces"], LBI["One-Handed Swords"],
    -- TODO: LBI["Warglaives"]
  },
  [ "DRUID" ] = {
    LBI["Daggers"], LBI["Fishing Poles"], LBI["Fist Weapons"],
    LBI["One-Handed Maces"], LBI["Leather"], LBI["Polearms"],
    LBI["Two-Handed Maces"], LBI["Staves"]
  },
  [ "HUNTER" ] = {
    LBI["Bows"], LBI["Crossbows"], LBI["Daggers"], LBI["Fishing Poles"],
    LBI["Fist Weapons"], LBI["Guns"], LBI["Mail"], LBI["One-Handed Axes"],
    LBI["One-Handed Swords"], LBI["Polearms"], LBI["Staves"], LBI["Thrown"],
    LBI["Two-Handed Axes"], LBI["Two-Handed Swords"]
  },
  [ "MAGE" ] = {
    LBI["Cloth"], LBI["Daggers"], LBI["Fishing Poles"],
    LBI["One-Handed Swords"], LBI["Staves"], LBI["Wands"]
  },
  [ "MONK" ] = {
    LBI["Fishing Poles"], LBI["Fist Weapons"], LBI["Leather"],
    LBI["One-Handed Axes"], LBI["One-Handed Maces"], LBI["One-Handed Swords"],
    LBI["Polearms"], LBI["Staves"]
  },
  [ "PALADIN" ] = {
    LBI["Fishing Poles"], LBI["One-Handed Axes"], LBI["One-Handed Maces"],
    LBI["One-Handed Swords"], LBI["Plate"], LBI["Polearms"], LBI["Shields"],
    LBI["Two-Handed Axes"], LBI["Two-Handed Maces"], LBI["Two-Handed Swords"]
  },
  [ "PRIEST" ] = {
    LBI["Cloth"], LBI["Fishing Poles"], LBI["One-Handed Maces"], LBI["Staves"],
    LBI["Daggers"], LBI["Wands"]
  },
  [ "ROGUE" ] = {
    LBI["Bows"], LBI["Crossbows"], LBI["Daggers"], LBI["Fishing Poles"],
    LBI["Fist Weapons"], LBI["Guns"], LBI["Leather"], LBI["One-Handed Axes"],
    LBI["One-Handed Maces"], LBI["One-Handed Swords"], LBI["Thrown"]
  },
  [ "SHAMAN" ] = {
    LBI["Daggers"], LBI["Fishing Poles"], LBI["Fist Weapons"], LBI["Mail"],
    LBI["One-Handed Axes"], LBI["One-Handed Maces"], LBI["Shields"],
    LBI["Staves"], LBI["Two-Handed Axes"], LBI["Two-Handed Maces"]
  },
  [ "WARLOCK" ] = {
    LBI["Cloth"], LBI["Daggers"], LBI["Fishing Poles"],
    LBI["One-Handed Swords"], LBI["Staves"], LBI["Wands"]
  },
  [ "WARRIOR" ] = {
    LBI["Bows"], LBI["Crossbows"], LBI["Daggers"], LBI["Fishing Poles"],
    LBI["Fist Weapons"], LBI["Guns"], LBI["One-Handed Axes"],
    LBI["One-Handed Maces"], LBI["One-Handed Swords"], LBI["Plate"],
    LBI["Polearms"], LBI["Shields"], LBI["Staves"], LBI["Thrown"],
    LBI["Two-Handed Axes"], LBI["Two-Handed Maces"], LBI["Two-Handed Swords"]
  },
}

-- Only outputs when debugging is enabled
function PersonalLoot:Trace(message)
  if self.db.char.isDebugging then
    self:Print(message)
  end
end

-- Only outputs when verbose is enabled
function PersonalLoot:Vtrace(message)
  if self.db.char.isVerbose then
    self:Trace(message)
  end
end

function PersonalLoot:Error(message)
  self:ColouredPrint(message, RED)
end

function PersonalLoot:ColouredPrint(message, colour)
  self:Print("|"..colour..message)
end

local function tableIsEmpty(table)
  return next(table) == nil
end

-- Returns -1 when val isn't found
local function tableGetIndex(table, val)
    for index, value in ipairs(table) do
        if value == val then
            return index
        end
    end

    return -1
end

local function tableContains(table, val)
  return tableGetIndex(table, val) > 0
end

function PersonalLoot:GetUnitNameWithRealmByGUID(id)
  local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(id)
  if not realm or realm == "" then
    realm = GetRealmName()
  end
  local nameWithRealm = name.."-"..realm
  self:Vtrace("Name with realm = "..nameWithRealm)
  return nameWithRealm
end

function PersonalLoot:GetUnitNameWithRealm(unit)
  return self:GetUnitNameWithRealmByGUID(UnitGUID(unit))
end

-- If public announcing is enabled and you are the announcer it will report
-- the message to the appropriate channel, otherwie it'll print locally.
function PersonalLoot:Announce(message)
  if not message then
    self:Error("Announce called with a nil message")
    return
  end

  local chatType

  if self.isAnnouncer and self.db.char.enablePublicAnnouncing then
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
      chatType = "INSTANCE_CHAT"
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
      if self.instanceType == "raid" then
        chatType = "RAID"
      end
    else
      chatType = "PARTY"
    end
  end

  self:Vtrace("Announce chatType = "..tostring(chatType))

  if chatType then
    SendChatMessage(message, chatType, "COMMON", nil)
  else
    self:Print(message)
  end
end

-- TODO: Remove, this is for debugging
function PersonalLoot:PLAYER_TARGET_CHANGED(cause)
    local playerName = GetUnitName("playertarget")
    self:InspectEquipment(playerName)
end

function PersonalLoot:GROUP_JOINED()
  self:Trace("GROUP_JOINED")
  self:TryToBecomeAnnouncer()
end

-- Caching is local to the addon, a player's items are removed
-- from the cache on timeout (CACHE_DURATION) or when they're no longer
-- in the player's group
function PersonalLoot:UnitEquipmentIsCached(playerName)
  return playerName and self.playerItems[playerName]
         and not self.playerItems[playerName]["pending"]
         and self.playerItems[playerName]["time"] >= GetTime() - CACHE_DURATION
end

-- Loads a player's equipment from cache if posible and retuns instantly,
-- otherwise a fetch from the server is required and will be handled by
-- INSPECT_READY later on
function PersonalLoot:InspectEquipment(playerName)
  if self:UnitEquipmentIsCached() then
    self:Vtrace(playerName.." items are cached and up to date.")
    self:HandleLootedItem(playerName, self.currentLoot)
  elseif CanInspect(playerName) then
    self.playerItems[playerName] = { }
    self:Vtrace("Starting equipment inspection for "..playerName.."...")
    self.playerItems[playerName]["pending"] = true
    self.playerItems[playerName]["time"] = 0
    self:RegisterEvent("INSPECT_READY")
    -- TODO: what if another addon calls NotifyInspect?
    NotifyInspect(playerName)
  end
end

-- This is called as a result of InspectEquipment when the target's items aren't
-- cached.
function PersonalLoot:INSPECT_READY(fnName, playerGuid)
  self:UnregisterEvent("INSPECT_READY")
  -- TODO: determine whether the player was inspected because they have loot
  -- or are a recipient
  local playerName = self:GetUnitNameWithRealmByGUID(playerGuid)

  if self.playerItems[playerName] then
    self.playerItems[playerName]["pending"] = false
    self:Vtrace("Inspect ready for "..playerName)
    -- Cache all of the equipment slots
    for id=0,19,1 do
      local link = GetInventoryItemLink(playerName, id)
      if not link then
        local distanceSquared, valid = UnitDistanceSquared(playerName)
        if not valid or distanceSquared >= INSPECT_DIST then
          ClearInspectPlayer()
          self:Error(playerName.." is too far to inspect!")
          return
        end
      end
    end
    ClearInspectPlayer()
    self.playerItems[playerName]["time"] = GetTime()
    self:Vtrace("Finished inspecting "..playerName)
    self:HandleLootedItem(playerName, self.currentLoot)
  else
    self:Vtrace(playerName.." is index "..tostring(playerIndex))
  end
end

function PersonalLoot:ItemIsBindOnEquip(itemLink)
  -- TODO: implement
  return false
end

function PersonalLoot:CHAT_MSG_LOOT(id, message)
  local owner, itemLink, _

  _, _, itemLink = string.find(message, "You receive loot: (|.+|r)")
  if itemLink then
    owner = self:GetUnitNameWithRealm("player")
  else
    _, _, owner, itemLink = string.find(message, "(.+) receives loot: (|.+|r)")
  end

  self:Vtrace("Considering "..message)

  if not (owner and itemLink) then
    self:Vtrace("Owner or itemLink is empty in CHAT_MSG_LOOT. Owner: "..tostring(owner==nil).." Item:"..tostring(itemLink==nil))
    return
  end

  if not self:IsEquipment(owner, itemLink) then
    return
  end

  if self:ItemIsBindOnEquip(itemLink) then
    self:Announce(itemLink.." is Bind on Equip.")
  end

  if not UnitIsUnit("player", owner) then
    self.currentLoot = itemLink
    self:InspectEquipment(owner)
  else
    self:HandleLootedItem(owner, itemLink)
  end
end

-- owner and itemLink must be valid and owner's items must be available in the
-- cache
function PersonalLoot:HandleLootedItem(owner, itemLink)
  assert(owner and itemLink)
  if self:IsTradable(owner, itemLink) then
    local potentialTradees = self:EnumerateTradees(owner, itemLink)
    if potentialTradees > 0 then
      self:Announce(itemLink.." owned by "..owner.." is tradable.")
      self:EnumerateTradees(owner, itemLink)
    else
      self:Vtrace("Nobody can use "..itemLink..", skipping announcing.")
    end
  else
    self:Trace(itemLink.." owned by "..owner.." is not tradable.")
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

-- Player group type, location and enemy type determine whether tradable
-- items can drop
function PersonalLoot:TradableItemsCanDrop()
  if self.instanceType == "party" then
    return true
  end

  if self.instanceType == "raid" and self.isPersonalLoot then
    return true
  end

  return false
end

function PersonalLoot:UpdateChatMsgLootRegistration()
  if self:TradableItemsCanDrop() then
    self:RegisterEvent("CHAT_MSG_LOOT")
  else
    self:UnregisterEvent("CHAT_MSG_LOOT")
  end
end

-- FingerSlot is for Finger0Slot / Finger1Slot
-- TrinketSlot is for Trinket0Slot / Trinket1Slot
-- WeaponSlot is for any weapon which isn't specifically main or off hand
-- TODO: Handle relics
function PersonalLoot:InvTypeToEquipSlotName(name)
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

  local numBonuses = select(14, strsplit(":", itemLink, 15))
  if numBonuses == "" then
    return itemLevel
  end

  self:Vtrace("numBonuses = "..numBonuses)
  numBonuses = tonumber(numBonuses)

  local affixes = select(15, strsplit(":", itemLink, 15))

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

-- Returns -1 if it can't get the real item level
function PersonalLoot:GetRealItemLevelBySlotName(owner, slotName)
  self:Vtrace("GetRealItemLevelBySlotName("..owner..", "..slotName..")")
  local slotId = GetInventorySlotInfo(slotName)
  local itemLink = GetInventoryItemLink(owner, slotId)
  if not itemLink then
    return -1
  end
  return self:GetRealItemLevel(itemLink)
end

-- itemSubclass is the 7th return value of GetItemInfo
function PersonalLoot:UnitCanUseItemSubclass(unit, itemSubclass)
  self:Vtrace("Item subclass is "..itemSubclass)

  -- TODO: do necks, rings, trinkets come under Miscellaneous?
  if itemSubclass == LBI["Miscellaneous"] then
    return true
  end

  if itemSubclass == LBI["Cloaks"] then
    return true
  end

  local unitClass = select(2, UnitClass(unit))
  if not self.classProficiencies[unitClass] then
    self:Error("No class entry for class "..tostring(unitClass))
    return false
  end

  local canWear = tableContains(self.classProficiencies[unitClass], itemSubclass)
  self:Vtrace(unitClass.." can use "..itemSubclass.."? "..tostring(canWear))
  return canWear
end

-- TODO: Move quality check to a separate function
function PersonalLoot:IsEquipment(owner, itemLink)
  if not owner or not itemLink then
    self:Error("IsEquipment received nil owner or itemLink")
    return false
  end

  local _, _, quality, _, _, _, _, _, invType = GetItemInfo(itemLink)

  if invType == "" then
    -- It's not an equippable item
    self:Vtrace(itemLink.." has no slotName, it's not equippable.")
    return false
  end

  if not self.db.char.allItemTypes then
    if self.instanceType == "raid" and quality < ITEM_QUALITY_EPIC then
      self:Trace("Quality is "..quality.." so ignoring...")
      return false
    elseif self.instanceType == "party" and quality < ITEM_QUALITY_RARE then
      self:Vtrace("Quality is "..quality.." so ignoring...")
      return false
    end
  end

  local slotName = self:InvTypeToEquipSlotName(invType)
  if not slotName then
    return false
  end

  return true
end

function PersonalLoot:WeaponIsTwoHanded(itemLink)
  local invType, _ = select(9, GetItemInfo(itemLink))
  local isTwoHanded = invType == "INVTYPE_2HWEAPON"
  self:Vtrace("WeaponIsTwoHanded? "..tostring(isTwoHanded))
  return isTwoHanded
end

-- unit must be being inspected
function PersonalLoot:UnitIsFuryWarrior(unit)
  return UnitClass(unit) == "Warrior" and GetInspectSpecialization() == FURY_WARRIOR_SPEC_ID
end

-- owner and itemLink must be valid. owner's items must be cached
function PersonalLoot:IsTradable(owner, itemLink)
  assert(owner and itemLink)
  local itemLevel = self:GetRealItemLevel(itemLink)
  local _, _, quality, _, _, _, _, _, invType = GetItemInfo(itemLink)
  local slotName = self:InvTypeToEquipSlotName(invType)

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
    if not self:WeaponIsTwoHanded(itemLink) or self:UnitIsFuryWarrior(owner) then
      return self:GetRealItemLevelBySlotName(owner, "MainHandSlot") >= itemLevel
             and self:GetRealItemLevelBySlotName(owner, "SecondaryHandSlot") >= itemLevel
    end
    return self:GetRealItemLevelBySlotName(owner, "MainHandSlot") >= itemLevel
  end

  local slotId = GetInventorySlotInfo(slotName)
  self:Vtrace("slot id "..slotId)

  local equippedItemLink = GetInventoryItemLink(owner, slotId)
  if not equippedItemLink then
    self:Trace("No item is equipped in "..slotName)
    return true
  end

  return self:GetRealItemLevel(equippedItemLink) > itemLevel
end

-- owner and itemLink must be valid
function PersonalLoot:EnumerateTradees(owner, itemLink)
  -- TODO: if self.instanceType == "raid"...

  local groupSize = GetNumGroupMembers()
  if groupSize < 1 then
    self:Trace("Group size is "..tostring(groupSize)..", skipping checking tradees.")
    return 0
  end

  local amountOfPotentialTradees = 0
  for i = 1, groupSize, 1 do
    local name = self:GetUnitNameWithRealm(GetRaidRosterInfo(i))
    if not UnitIsUnit("player", name) then
      if self:UnitCanUse(name, itemLink) then
        self:InspectEquipment(name)
        amountOfPotentialTradees = amountOfPotentialTradees + 1
      end
    end
  end
  -- Return the amount of people able to use the item
  return amountOfPotentialTradees
end

-- Returns an item subclass, see GetItemInfo's return values
function PersonalLoot:GetItemSubclass(itemLink)
  return select(7, GetItemInfo(itemLink))
end

-- Returns a player class index or nil
function PersonalLoot:GetArmorClassRestriction(itemLink)
  -- TODO: implement
  return nil
end

-- returns booleans for AGILITY, INTELLECT, STRENGTH
function PersonalLoot:GetItemPrimaryStats(itemLink)
  -- TODO: implement
  -- if statId is nil then check whether the item has no primary stat
  return true, true, true
end

-- The unit must be being inspected and have inspect data available
function PersonalLoot:UnitUsesPrimaryStatsOfItem(unit, itemLink)
  local hasAgility, hasIntellect, hasStrength = self:GetItemPrimaryStats(itemLink)
  if not hasAgility and not hasIntellect and not hasStrength then
    return true
  end

  local unitClass = UnitClass(unit)

  if unitClass == "Death Knight" then
    return hasStrength
  elseif unitClass == "Demon Hunter" then
    return AGILITY
  elseif unitClass == "Druid" then
    return hasIntellect or hasAgility
  elseif unitClass == "Hunter" then
    return hasAgility
  elseif unitClass == "Mage" then
    return hasIntellect
  elseif unitClass == "Monk" then
    return hasAgility or hasIntellect
  elseif unitClass == "Paladin" then
    return hasIntellect or hasStrength
  elseif unitClass == "Priest" then
    return hasIntellect
  elseif unitClass == "Rogue" then
    return hasAgility
  elseif unitClass == "Shaman" then
    return hasAgility or hasIntellect
  elseif unitClass == "Warlock" then
    return hasIntellect
  elseif unitClass == "Warrior" then
    return hasStrength
  end

  self:Error("Unknown primary stat for "..unit)
  return nil
end

function PersonalLoot:UnitCanUse(unit, itemLink)
  local classRestriction = self:GetArmorClassRestriction(itemLink)
  local _, unitClass, _ = UnitClass(unit)

  if classRestriction and classRestriction ~= unitClass then
    self:Vtrace(unit.." can't use items restricted to class "..tostring(classRestriction))
    return false
  end

  local itemSubclass = self:GetItemSubclass(itemLink)
  if not self:UnitCanUseItemSubclass(unit, itemSubclass) then
    self:Vtrace(unit.." can't use item subclass "..tostring(itemSubclass))
    return false
  end

  if itemSubclass == "Miscellaneous" then
    if not self:UnitUsesPrimaryStatsOfItem(unit, itemLink) then
      self:Vtrace(unit.." can't use the primary stats.")
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
  if self.db.char.enablePublicAnnouncing then
    self.isAnnouncer = true
    self:SendCommMessage(ANNOUNCER_NEGOTIATION_CHANNEL, "ME?", "RAID")
  end
end

function PersonalLoot:GetRaidLeader()
  for i=1, GetNumGroupMembers(), 1 do
    local targetMemberName, targetMemberRank = GetRaidRosterInfo(i)
    if targetMemberRank == RAID_LEADER_RANK then
      self:Vtrace(targetMemberName.." was found to be the group leader.")
      return targetMemberName
    end
  end
  self:Vtrace("Failed to find a group leader. Blame Canada.")
end

-- TODO: a priority list of addon users in the group to prevent many people
-- sending "ME?" in response to the announcer leaving
function PersonalLoot:OnCommReceived(prefix, message, distribution, sender)
  self:Vtrace("OnCommReceived: "..prefix..", "..message..", "..distribution..", "..sender)

  -- We receive our own messages, skip them
  if UnitIsUnit(sender, "player") then
    self:Vtrace("I am the sender, ignoring.")
    return
  end

  if message == "LEAVING" then
    self:Vtrace("Announcer is leaving, trying to become the new announcer.")
    self:TryToBecomeAnnouncer()
    return
  end

  if not message == "ME?" then
    self:Vtrace("Recieved message not defined in addon, ignoring.")
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
  if UnitIsGroupLeader(sender) then
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

function PersonalLoot:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("PersonalLootDB", self.defaultOptions)
  LibStub("AceConfig-3.0"):RegisterOptionsTable("PersonalLoot", self.options, "pl")
  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("PersonalLoot", self.options)
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("PersonalLoot", "PersonalLoot")
end

function PersonalLoot:OnEnable()
  self:Trace("OnEnable")
  self.playerItems = {}
  self.currentLoot = nil

  -- Reloading the UI doesn't result in these events being fired, so force them
  self:PARTY_LOOT_METHOD_CHANGED()
  self:ZONE_CHANGED_NEW_AREA()
  self:RegisterEvent("GROUP_JOINED")
  self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  -- self:RegisterEvent("PLAYER_TARGET_CHANGED")

  self:RegisterComm(ANNOUNCER_NEGOTIATION_CHANNEL)

  self:TryToBecomeAnnouncer()
end

function PersonalLoot:OnDisable()
  self:Trace("OnDisable")
  self:StopAnnouncing()
  self:UnregisterAllEvents()
end
