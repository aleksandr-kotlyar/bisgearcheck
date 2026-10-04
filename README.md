<p align="center">
  <img src="art/logo.png" alt="BiS Gear Check" width="200"/>
</p>

<h1 align="center">BiS Gear Check</h1>

<p align="center">
  A World of Warcraft TBC Anniversary addon that compares your equipped gear against ranked Best in Slot lists.<br/>
  Tooltip integration, wishlists, full BiS list browsing, and multi-character support.
</p>

<p align="center">
  <strong>Author:</strong> Breakbone - Dreamscythe&nbsp;&nbsp;|&nbsp;&nbsp;<strong>Interface:</strong> 20505 (TBC Anniversary)
</p>

---

## Compare

See every upgrade available for your spec, ranked by slot. Your equipped item is shown with its BiS rank, and every item ranked higher is listed with its drop source.

<img src="art/screenshot-compare.png" alt="Compare Tab" width="600"/>

- Auto-detects your spec from talent points
- Collapsible slot sections with Collapse All / Expand All
- Add upgrades directly to your wishlist with the **+** button
- Automatically refreshes when you swap gear
- Faction-aware: filters out items not available to your faction

## BiS Lists

Browse the full BiS list for any spec across all classes. Switch between data sources to compare rankings. Filter by zone to focus on a specific dungeon or raid.

<img src="art/screenshot-bis-lists.png" alt="BiS Lists Tab" width="600"/>

- Class-colored headers in the spec dropdown
- Six data sources: WowTBC.gg, BiS-Tooltip, AtlasLoot, WoWSims, ThatsMyBis, Wowhead
- Zone filter to narrow results to a specific instance

## Wishlists

Track the items you're chasing across dungeons and raids. Create multiple named wishlists and filter by zone.

<img src="art/screenshot-wishlist.png" alt="Wishlist Tab" width="600"/>

- Multiple wishlists per character with create, rename, and delete
- Filter by dungeon or raid zone
- Auto-filter mode shows items for your current zone when you enter an instance
- Zones with wishlist items are highlighted green in the dropdown

## Tooltip Integration

BiS rankings appear directly in item tooltips, grouped by data source. Hover over any item to see which specs rank it and at what position, with class-colored spec names.

<img src="art/screenshot-tooltip.png" alt="Tooltip Integration" width="380"/>

- Works in bags, chat links, vendor windows, and the auction house
- Entries grouped by source with labeled headers (e.g., "BiSGearCheck (AtlasLoot)")
- Filter to your class only, or disable entirely
- Each source can be independently enabled/disabled for tooltips in Settings
- Detects conflicts with AtlasBIS Tooltips and lets you choose which to use

## Multi-Character Support

Switch between all characters on your account from the character selector dropdown. View another character's gear on the Compare tab, edit their wishlists, and plan upgrades across your roster. Gear snapshots are saved automatically. Set a minimum level threshold or ignore specific characters to keep the dropdown clean.

## Raid Scan

Inspect your entire raid at once. Scan all members to check for missing enchants, wrong gems, empty sockets, and mount-speed items left equipped. Each issue row shows the item's BiS list position so you can see at a glance how close someone's gear is to optimal.

<img src="art/screenshot-raid-scan.png" alt="Raid Scan" width="600"/>

- Scans all raid members in range via inspect
- Shows enchant, gem, and gear issues per character with BiS rank
- Upgrade suggestions per slot using the active data source
- Right-click a character to whisper their issues directly
- Export results as CSV or print a text report to chat
- Zone filter to focus upgrades on a specific instance
- Collapse/expand individual characters or all at once

<img src="art/screenshot-raid-scan-csv.png" alt="Raid Scan CSV Export" width="600"/>
<img src="art/screenshot-raid-scan-report.png" alt="Raid Scan Chat Report" width="450"/>
<img src="art/screenshot-raid-scan-whisper.png" alt="Raid Scan Whisper Issues" width="450"/>

## Settings

Configure tooltip display, enable or disable individual data sources for the addon UI and tooltips, and manage character filters.

<img src="art/screenshot-settings.png" alt="Settings Panel" width="380"/>

- Toggle BiS tooltip injection and class-only filtering
- Per-source enable/disable for addon UI and tooltips
- Minimum character level threshold for the multi-character dropdown
- Character ignore list

## Usage

| Action | How |
|--------|-----|
| Open Compare | Left-click minimap button, or `/bisgear` |
| Open Wishlists | Right-click minimap button, or `/bgc wl` |
| Open Settings | Alt-click minimap button |

## Data Sources

BiS data is available for Phase 1 (Karazhan/Gruul/Mag) and Phase 2 (SSC/TK). Switch phases via the dropdown in Settings or the BiS Lists tab.

| Source | Phase 1 | Phase 2 | Description |
|--------|---------|---------|-------------|
| WowTBC.gg | 27 specs | 27 specs | Community-voted BiS lists from wowtbc.gg. Broad coverage, rankings reflect community opinion. |
| BiS-Tooltip | 27 specs | 27 specs | BiS rankings from BiS-Tooltip (boegi1's TBC backport) combined with WoWSims presets. Most comprehensive source. |
| AtlasLoot | 27 specs | 25 specs | BiS rankings from AtlasLoot loot tables. Missing Rogue Assassination and Rogue Subtlety for Phase 2. |
| WoWSims | 22 specs | 5 specs | Simulation-optimized gear sets from WoWSims TBC. Most mathematically rigorous but limited spec coverage. |
| ThatsMyBis | 27 specs | 27 specs | Community wishlist aggregates from thatsmybis.com. Phase 2 lists include SSC/TK items where wishlisted, with Phase 1 gear filling remaining slots. |
| Wowhead | 27 specs | 24 specs | Editorial BiS guides from Wowhead. Missing Rogue Assassination, Rogue Subtlety, and Shaman Restoration in Phase 2. |

Each source can be independently enabled for the addon UI and/or tooltips in Settings. Item drop sources (boss names, zones, quest names) are stored in `SourceDB.lua` covering 2,200+ items. Items can be tagged with a `faction` field ("Alliance" or "Horde") for faction-specific filtering; untagged items are available to both factions.

## Dependencies

No hard addon dependencies. The following libraries are bundled:

- LibStub
- CallbackHandler-1.0
- LibDataBroker-1.1
- LibDBIcon-1.0

## Limitations

- This addon is built for and tested on the **WoW TBC Anniversary** client only. BiS data sets are specific to this version.
- UI labels and bundled data are in **English only**. Cyrillic wishlist and character names use the client's built-in Cyrillic font, preserving text size and styling; this does not translate the interface.
- Spec detection is based on talent points and may guess wrong for hybrid specs or characters that haven't spent talent points.

## Installation

Copy the `BiSGearCheck` folder into your WoW AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/BiSGearCheck/
```
