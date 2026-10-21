# Changelog

All notable changes to Bejeweled Redux. Versions follow [Semantic Versioning](https://semver.org/) and are independent of WoW client versions.

## [1.0.0] - Unreleased

- **Bejeweled Redux**: First release as its own addon (`BejeweledRedux`) and repository. It can be installed alongside the original Bejeweled; `/bejredux` always opens this one.
- **Rewrite**: The obfuscated single `Bejeweled.lua` was deobfuscated, then split into one file per system (`Core/`, `Data/`, `Game/`, `Animation/`, `UI/`, `Features/`, `Config/`).
- **Libraries**: Now built on Ace3 (AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceDBOptions, AceComm, AceSerializer, AceGUI, AceConfig), LibDataBroker-1.1 and LibDBIcon-1.0.
- **Fresh saved data**: Stats, skills and high scores start over in a new `BejeweledReduxDB` (AceDB, with profiles). Old `BejeweledProfile` / `BejeweledData` saves are not migrated.
- **New score sync**: Guild and friend high scores use a new versioned AceComm protocol. It does not talk to older versions of the addon. Messages are queued while Midnight's addon-message lockdown is active.
- **Options**: The options screen is built with AceConfig and is also available under Settings → AddOns. It includes a toggle keybinding and profiles.
- **Minimap**: The minimap button now uses LibDBIcon. Added an addon compartment entry. Titan Panel shows the LibDataBroker launcher; the FuBar and Titan-specific plugins were removed.
- **Auto open/close triggers** (on login, death, ready check, combat, flight start/end) are now opt-in and off by default.
- **Flight paths**: Flight times are learned per route (origin and destination node) with the modern taxi APIs and shown on Flight Map tooltips. The obsolete built-in coordinate tables were removed.
- **Achievements**: Fun achievements that relied on the combat log, which Midnight no longer gives to addons, now use the death recap, `PARTY_KILL`, `PVP_MATCH_COMPLETE` and `READY_CHECK_CONFIRM`. "Say yes to a raid ready check" now counts any ready check, and "Gain Honor from a killing blow" is now "Get an honorable kill".
- **Skill cap**: The full 450 skill and Grand Master rank are reachable again. The 375 cap was meant for accounts without Wrath of the Lich King.
- **Fixes**:
  - Friend high scores were always deleted and friend whispers dropped, because of a broken friend lookup.
  - Scroll lists had no scrollbar, and the popup close button did nothing.
  - Lightning effects were invisible; they are now drawn with Line regions.
  - The first-time tips never appeared.
  - Effects stayed at half alpha after pausing a Flight-mode game.
  - The level-up wipe was sped up in Classic mode too.
  - Several accidental global variables were removed.
  - The window did not auto-fade when sounds were off.
  - The Timed-mode length slider could produce fractional minutes.
  - The level-up sound pointed at a game file path that no longer works.
  - Flight-mode games did not end on landing when the client reported the taxi state late. Flights that outlast their learned time are now timed until the actual landing.

---

# Original Bejeweled Addon

History of the original addon that Bejeweled Redux is based on, archived at [Nighthawk42/wow_bejeweled](https://github.com/Nighthawk42/wow_bejeweled). These versions followed WoW client versions.

## [12.1.0] - 2026

- **Midnight Migration**: Updated TOC interface version for World of Warcraft: Midnight (12.1.0 / 120100).
- **Client Branches**: Split repository into dedicated branches for each active WoW client flavor (`master` / Retail, `mists`, `tbc`, `vanilla`, `wrath`, `cata`).
- **Single TOC & Lua**: Standardized addon structure to a single `Bejeweled.toc` and `Bejeweled.lua` per client branch.
- **Score Sync Fixes**: Fixed guild and friend high score synchronization by properly registering addon message prefixes (`BEJEWELED2` and `BEJ2a`).
- **UI Bug Fixes**:
  - High Scores panel now defaults to the Guild tab.
  - Fixed popup close buttons broken by template syntax.
  - Publish Scores button on the Game Over screen no longer disables after one click and includes helpful tooltips.
  - Fixed crash in dropdown menu when selecting Party/Raid/Custom channel for score bragging.
  - Prevented keyboard input from remaining trapped after keybind capture using `SetPropagateKeyboardInput(true)`.

## [11.0.2] - 2024

- Initial support for *The War Within* (Mainline).
- Updated interface versions for Cataclysm Classic and Classic Era.

## [10.0.5] - 2023

- Updated interface versions for *Dragonflight* (Mainline), *Wrath of the Lich King Classic*, and *Classic Era*.

## [10.0.2] - 2022

- Fixed window resizing issues (credit: `chrisliebaer`).

## [10.0.0] - 2022

- Modernized and updated to function with *World of Warcraft: Dragonflight* (Patch 10.0).

## [9.2.0] - 2022

- Updated to function with *World of Warcraft: Shadowlands* (Patch 9.2.0).

## [7.0.3] - 2016

- Upgraded to function with *World of Warcraft: Legion* (Patch 7.0.3).
- Version numbering adjusted to match WoW client interface versions.

## [1.1] - 2009

- **Score System Upgrade**: Migrated score data to a new format with enhanced guild and friend score broadcast.
- **Stats & Achievements**:
  - Renamed the "Personal" tab to "Stats" and added "Total Games Played" across all characters.
  - Added dedicated "Achievements" tab to the Feats of Skill window.
  - Adjusted achievement requirements and difficulty curves.
- **Gameplay & Flight Integration**:
  - Added default flight times for Northrend.
  - Fixed various edge cases with shape matches (L/T power gem vs hypercube creation).
  - Resolved conflicts with flight path addons and shape-shifted states.

## [1.03] - 2008

- Added "One score per person on high score lists" option.
- Fixed achievement triggers for combat damage, falling damage, and raid ready checks.
- Prevented game element state bleed-over between consecutive games.

## [1.02] - 2008

- Added `/bejeweled reset` slash command.
- Added option to toggle and detach the minimap button.

## [1.01] - 2008

- Improved addon communication bandwidth efficiency during score sync.
- Resolved flight auto-start logic edge cases.
- Fixed non-English client localization quirks.
