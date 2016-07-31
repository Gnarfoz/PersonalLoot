--[[
PersonalLoot
All global variables and options for PL are stored here.

TODO: figure out if the blizz interface options can also be made here
--]]

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

local ANNOUNCER_NEGOTIATION_CHANNEL = "PLAnnNeg"

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

local PersonalLoot:relicTypes = {
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

-- TODO: Localise
-- What about off hands? Fishing Poles
local PersonalLoot:wearables = {
  [ "Death Knight" ] = { "One-Handed Axes", "One-Handed Maces",
                         "One-Handed Sword", "Plate", "Polearms",
                         "Two-Handed Swords", "Two-Handed Maces",
                         "Two-Handed Swords" },
  [ "Demon Hunter" = { },
  [ "Druid" ] = { "Daggers", "Fist Weapons", "One-Handed Maces", ARMOR_TYPE_LEATHER,
                  "Polearms", "Two-Handed Maces", "Staves" },
  [ "Hunter" ] = { "Bows", "Crossbows", "Daggers", "Fishing Poles",
                   "Fist Weapons", "Guns", "Mail", "One-Handed Axes",
                   "One-Handed Swords", "Polearms", "Staves", "Thrown",
                   "Two-Handed Axes", "Two-Handed Swords" },
  [ "Mage" ] = { "Cloth", "Daggers", "One-Handed Swords", "Staves",
                 "Wands" },
  [ "Monk" ] = { "Fist Weapons", ARMOR_TYPE_LEATHER, "One-Handed Axes", "One-Handed Maces", "One-Handed Swords", "Polearms", "Staves"},
  [ "Paladin" ] = { },
  [ "Priest" ] = { },
  [ "Rogue" ] = { },
  [ "Shaman" = { },
  [ "Warlock" = { },
  [ "Warrior" ] = { "Bows", "Crossbows", "Daggers", "Fishing Poles",
                    "Fist Weapons", "Guns", "One-Handed Axes",
                    "One-Handed Maces", "One-Handed Swords", "Plate",
                    "Polearms", "Shields", "Staves", "Thrown",
                    "Two-Handed Axes", "Two-Handed Maces",
                    "Two-Handed Swords" },
}
