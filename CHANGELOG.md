# Changelog

Versioning: **MAJOR.MINOR.PATCH**
- **MAJOR** — Breaking changes (saved variable resets, incompatible data format changes)
- **MINOR** — New features or significant improvements
- **PATCH** — Bug fixes, data corrections, small tweaks

## v3.10.1

- Current content phase is now Phase 2 by default.
- Refreshed Wowhead BiS data with the latest Phase 2 guide updates, including Season 2 arena pieces.
- Refreshed ThatsMyBis community wishlist data — now reflects live Phase 2 wishlists, adds previously missing glove slots.
- WowTBC.gg Phase 2 lists are now full ranked lists (~12 items per slot) instead of only the single top pick.
- Fixed the Settings phase dropdown showing the wrong phase until the menu was clicked open.
- Raid scans saved by older versions now re-guess each member's spec from their scanned gear when restored — previous versions often stamped raiders with the wrong spec.
- Sockets filled with gems your game client hasn't seen yet (common with new Phase 2 gems on other players) are no longer reported as empty.

## v3.10.0

- **Wishlists as comparison sources**: any wishlist can be opted in via a new "Enable Compare" checkbox on the Wishlists tab, making it selectable in the Compare-tab source dropdown (and optionally contributing to tooltips). Flags live in the same Data Sources settings table as published sources.
- Wishlist-as-source honors a single spec per wishlist — the **Rename dialog** now includes a "Compare Spec" dropdown with an `(Auto)` default that infers the spec from the majority `specKey` across the wishlist's items.
- **Phase-future items drop silently** from BiS lists when the player's real game phase is below the item's phase. Compare view no longer counts phase-2 items as "filtered" while we're in phase 1; rank numbering collapses around them implicitly.
- **Raid scan pins the spec at scan time** — displayed spec stays accurate across `/reload` and later respec/talent-data corrections. Talent-based guess runs at scan time; if talent data isn't available, the player's current saved spec is preserved (no more silent fall-through to Affliction/Arms).
- **Raid scan honors the Compare-tab filter settings** (PvP, World Boss, Classic zones, faction). Removed the separate `raidInclude*` flags and the "Raid Scanning" section in Settings — one place to configure filters now. Close Rank Gaps also applies to raid-scan rank numbering.
- Raid scan output **merges equipped + upgrades per slot** into a single block. Warnings (missing enchant, bad gem) fold onto the worn-item row. Each slot's upgrade candidates indent beneath.
- **BiS2!** text for rank 2 in dual slots (Rings, Trinkets) on the Compare tab — the top two picks are effectively co-BiS.
- **Collapsed dual slots** show both equipped items inline on the header row instead of an empty `[+] Rings` stub.
- **Spec auto-guess hardening**: `GuessSpec` now returns nil when talent data isn't loaded (instead of silently defaulting to the first spec). `CHARACTER_POINTS_CHANGED` re-runs the guess when talents resolve, so a wrong initial guess self-corrects without user intervention.
- Fixed `Data.lua` (WowTBC.gg): Clefthoof Hide Leggings (31544) was mis-placed in the Shoulders list for 6 spellcaster specs; replaced with the intended quest sibling Spaulders of the Torn-heart (30925). `SourceDB.lua` also had 31544 mis-labeled as "Spaulders of the Torn-heart" — corrected.

## v3.9.0

- Refreshed Wowhead BiS data: broader coverage in Phase 1 (~45% more items, including pre-raid and alt picks) and a complete Phase 2 list for every spec (previously sparse for several specs).
- MH weapons equipped in your off-hand no longer show up as main-hand upgrades (and vice versa). Respects one-hand/off-hand handedness — shields and main-hand-only weapons are unaffected.
- New setting "Close rank gaps when filtering": when a higher-ranked BiS item is filtered out (PvP, World Boss, Classic zones, phase, etc.), the next visible item is treated as BiS. Off by default.
## v3.8.1

- Ring and trinket upgrades now appear correctly

## v3.8.0

- Added centralized theme system, including optional ElvUI support.
- Main window is now resizable.

## v3.7.3

- Release package trimmed: no longer ships developer-only files (`CURSEFORGE.md`, `site-content.json`, `.github/`, etc.)
- `LICENSE` file now included in the release zip

## v3.7.2

- Fixed settings panel crash triggered by accumulated inspect history over long sessions.

## v3.7.1

- Fixed spurious inspections caused by other addons doing inspections

## v3.7.0

- Added Phase 2 BiS data from all six sources (SSC/TK, Season 2 PvP, engineering goggles, Ogri'la gear).
- Added phase selector dropdown in Settings and BiS Lists tab to switch between Phase 1 and Phase 2.
- Refreshed ThatsMyBis Phase 1 wishlist data with current community rankings.

## v3.6.2

- Fixed Cloak of Eternity (defense cloak) incorrectly appearing in healer BiS lists instead of White Remedy Cape.
- Fixed inspect events firing excessively from other addons' background inspections.
- Compare tab now switches back to your character when you inspect yourself.

## v3.6.1

- Fixed enchant tooltip showing Major Spellpower when hovering Major Healing.
- Fixed weapon slot showing duplicate entries for Main Hand and Twohand.
- Fixed raid scan using Compare tab spec instead of detecting from talents.
- Corrected several enchant IDs and tooltip mappings.

## v3.6.0

- Added Raid Scan: inspect your entire raid and see enchant/gem issues, BiS rank of equipped items, and upgrade suggestions per character.
- Right-click any scanned character to whisper their issues directly.
- Scan results can be exported as CSV or printed as a text report.
- Zone and source filters carry over from Compare settings.

## v3.5.6

- Fixed CurseForge packaging to exclude test files from release archives.

## v3.5.5

- Added test suite covering EP scoring, gear comparison, wishlist CRUD, character/inspection management, tooltip indexing, item filtering, and settings initialization.
- Fixed class-colored text rendering for Lua 5.4 compatibility.

## v3.5.4

- Fixed spec auto-detection for Druid and Priest.

## v3.5.3

- Trinkets and Rings no longer suggest items ranked below your lowest-ranked equipped piece.
- Sections with all upgrades hidden by filters now show "X items filtered"; hover for a breakdown by filter type (Classic, PvP, World Boss, BoP Crafted, Zone filter).

## v3.5.2

- Fixed inspect window opening from background inspect events.

## v3.5.1

- Partial fix for inspect window opening from background inspect events.

## v3.5.0

- Added inspect snapshot: view and compare gear for inspected players.

## v3.4.0

- Added source filters for PvP, World Boss, and BoP crafted items.
- Added info tooltips to data source names.
- Zone dropdown now filters by content phase.
- PvP vendor items now categorized under PvP.
- Fixed TMB data missing 7 specs.

## v3.3.2

- Added About section to Settings.

## v3.3.1

### Improvements
- Data Sources settings table now shows Specs and Items counts per source.
- Added item phase data from WoWSims (4,513 items).
- Filled in WoWSims P1 data for Warlock, Paladin Protection/Retribution, and Enhancement Shaman.

### Fixes
- Fixed WoWSims showing Phase 2-4 items as Phase 1 data.

## v3.3.0

### Features
- Added BiS-Tooltip, WoWSims, Wowhead, and ThatsMyBis data sources with per-source enable for addon UI and tooltips.
- Tooltip BiS entries grouped by source with labeled headers.
- Minimap button (LibDBIcon).
- Zone filter for BiS Lists and Wishlists, including Crafted, Quest, and PvP.
- SourceDB expanded to 2,200+ items.
- Character level threshold and ignore list settings.

### Fixes
- Fixed wrong enchantment ID for Enchant Bracer - Major Intellect causing false warnings.
- Fixed [Wrong Enchant] tooltip showing wrong slot name for shared enchant IDs.

## v3.2.0

### Features
- Lesser warnings: [Lesser Enchant] and [Lesser Gems] shown in yellow instead of red for budget/lower-rank alternatives.
  - Lesser enchants: lesser shoulder inscriptions (Aldor/Scryer), Silver/Mystic Spellthread, Cobrahide/Clefthide Leg Armor.
  - Lesser gems: green (Uncommon) quality gems shown as [Lesser Gems] in yellow; white/grey gems remain [Wrong Gems] in red.
- Broadened enchant recommendations across all 27 specs — most slots now list 2-3 valid alternatives to reduce false [Wrong Enchant] warnings.

## v3.1.1

### Fixes
- Added Nethercleft Leg Armor as a recommended leg enchant for Protection Paladin (was only listing Runic Spellthread).

## v3.1.0

### Features
- Equipped gear warnings: [No Enchant], [Wrong Enchant], [Empty Socket], [Wrong Gems] displayed pinned-right on equipped item rows.
- [Wrong Enchant] is interactive -- hover to see a tooltip of the currently applied enchant.
- Enchant recommendations shown per slot on Compare and BiS Lists tabs with spell/item tooltips.
- Gem recommendations shown per spec (meta, red, yellow, blue) at the bottom of Compare and BiS Lists.
- Aldor/Scryer-aware shoulder enchant filtering -- only shows inscriptions available to your chosen faction.
- Faction-aware enchant tooltips (e.g., Glyph of Renewal shows the correct Alliance or Horde variant).

### Fixes
- Fixed gem quality check not detecting low-quality gems in filled sockets (tooltip scan only found empty sockets).
- Fixed Runic/Golden Spellthread enchant ID swap (2748 = Runic, 2746 = Golden).
- Fixed Silver/Mystic Spellthread item ID mapping.
- Added non-BiS enchants (lesser inscriptions, lesser spellthreads, leg armors) to tooltip lookup so [Wrong Enchant] shows useful tooltips.

## v3.0.4

### Changes
- Added CurseForge project ID to TOC for automated publishing.
- Versioned build zip filenames (e.g. BiSGearCheck_3.0.4.zip).
- Fixed carriage return in version extraction for build workflows.

## v3.0.3

### Fixes
- Fixed CurseForge description: moved gear comparison screenshot to correct section, added missing BiS Lists image placement.

## v3.0.2

### Fixes
- Fixed Resto Druid BiS shoulders listing Mantle of Malorne (feral) instead of Shoulderguards of Malorne (restoration).
- Fixed Cloak of the Fallen God appearing in the Neck slot for Resto Druid, Holy Paladin, and Resto Shaman. Replaced with correct item Amulet of the Fallen God.
- Corrected SourceDB name for item 29100 (Mantle of Malorne, was mislabeled as Shoulderguards).
- Added missing SourceDB entries for Shoulderguards of Malorne and Amulet of the Fallen God.

## v3.0.1

### Fixes
- Fixed memory leak: UI frames are now pooled and recycled instead of created fresh each render.
- Eliminated per-render closure allocations by using shared script handlers with frame-stored data.
- Reduced table churn in comparison engine and faction filtering with reusable buffers.
- Added garbage collection on window close to reclaim render allocations promptly.

### Changes
- Moved compare screenshot to Gear Comparison section in CurseForge description.
- Constrained CurseForge images with width attributes and replaced em dashes for encoding compatibility.

## v3.0.0

### Breaking Changes
- Renamed addon from BISGearCheck to BiSGearCheck. Addon folder, TOC file, SavedVariables, and all Lua identifiers updated. Existing users must rename their addon folder and saved variable files.

### Changes
- Refactored Core.lua and UI.lua into smaller, focused files: Character.lua, Wishlist.lua, Comparison.lua, UIControls.lua, UIWishlistControls.lua, UIRenderComparison.lua, UIRenderLists.lua.
- Added GitHub Actions workflows for manual release and pre-release builds.
- Fixed dropdown indentation inconsistency across all dropdown menus.
- Added Limitations section to README.
- TOC version is now maintained manually instead of using @project-version@ token.
- GitHub repository permissions locked down (branch protection, Actions visibility, fork workflow restrictions).

## v2.1.0

### New Features
- **Faction Support**: Detects player faction and filters BiS lists to show only faction-appropriate items. Items in SourceDB can be tagged with a `faction` field ("Alliance" or "Horde"); untagged items are available to both.
- **Multi-Character Management**: Characters on the same WoW account can view and edit each other's wishlists. A character selector dropdown at the top of the addon window lets you switch between characters.
- **Gear Snapshots**: Each character's equipped gear is saved when they log in or change equipment, allowing other characters to see their gear on the Compare tab.
- **Per-Character Settings**: Spec selection, data source, and wishlist auto-filter are now saved per-character instead of account-wide.

### Changes
- SavedVariables restructured: `BiSGearCheckSaved` is account-wide (character registry, wishlists, tooltip settings), `BiSGearCheckChar` is per-character (spec, data source, filters).
- Automatic migration from pre-2.1.0 saved data format.
- Added `.pkgmeta` and GitHub Actions workflow for CurseForge packaging.

## v2.0.0

- Initial release with Compare, Wishlists, and BiS Lists tabs.
- WowTBC.gg and AtlasLoot data sources.
- Tooltip integration with BiS rankings.
- Zone-based wishlist filtering with auto-detect.
- Multiple named wishlists with create/rename/delete.
- Minimap button via LibDBIcon.
