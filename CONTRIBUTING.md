# Contributing to Bejeweled Redux

Thank you for helping maintain and improve *Bejeweled Redux*! This guide covers getting set up, how the code is organized, and the workflow for bug fixes, features, and client compatibility updates.

---

## 🚀 Getting Started

1. Clone the repository and run `scripts/fetch-libs.sh` (Git Bash works on Windows) to download the libraries into `Libs/`.
2. Make the checkout visible to the game. Either copy it to `<client folder>/Interface/AddOns/BejeweledRedux` (for example `World of Warcraft/_retail_/`), or link it so edits apply on `/reload`. Linking the same checkout into several clients lets you test them all:
   - Windows: `mklink /J "<WoW>\_retail_\Interface\AddOns\BejeweledRedux" "<path to checkout>"`
   - macOS/Linux: `ln -s <path to checkout> "<WoW>/_retail_/Interface/AddOns/BejeweledRedux"`
3. Only the runtime files are needed in-game: `BejeweledRedux.toc`, `embeds.xml`, the code folders, `Libs/`, `images/` and `sounds/`.

---

## 🌿 Supported Clients

All clients are served from the single `main` branch and a single package:

| Client | Interface | Status |
|---|---|---|
| **Retail** (Midnight) | `120100` | Supported |
| **WoW Forever** | `16001` | Supported (beta client) |
| **Mists of Pandaria Classic** | `50504` | Supported |
| **Titan Reforged** (Wrath) | `38002` | Supported |
| **TBC Anniversary** | `20506` | Supported |
| **Classic Era** | `11509` | Supported |

---

## 🛠️ Development & Contribution Workflow

### 1. Fixes & Features
- Base your work on `main`, test it in-game, and open a Pull Request against `main`.

### 2. Client Differences
Every client runs the same files. Where APIs differ, check at runtime instead of forking the code:
- Feature-test functions and tables: `if C_DeathRecap then ... end`, `local isSecret = issecretvalue or function() return false end`.
- Only register events the client has: `C_EventUtils.IsEventValid(event)`. Registering an unknown event raises an error.
- Use `WOW_PROJECT_ID` only for differences in game content rather than API (for example, Classic Era has no arenas).
- Use the Retail code path wherever an API exists everywhere, and add the fallback beside it with a one-line comment naming the client that needs it.

### 3. TOC & Versioning Conventions
- **Single TOC:** `BejeweledRedux.toc` lists every supported client in one comma-separated `## Interface:` line. Do not add suffixed TOCs (`_Mainline`, `_Vanilla`, ...) unless a client needs a different file list.
- **TOC Interface Numbers:** When a client patches, update its number in the `## Interface:` list.
- **Version Strings:** Versions follow [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`), independent of WoW client versions. Update `## Version:` in `BejeweledRedux.toc` (the About screen reads it from there) and add a matching entry to [CHANGELOG.md](CHANGELOG.md).

### 4. Releases
- Tag the release commit `vX.Y.Z` and push the tag. The release workflow runs the BigWigs packager, which fetches the libraries listed in `.pkgmeta` and publishes the addon zip as a GitHub release, then zips each folder in `packs/` and attaches it to the same release as `<pack>-vX.Y.Z.zip`.
- When a pack changes, update the `## Version:` in its `.toc` too.

---

## 🧱 Code Layout

The addon is split into one file per system, loaded in the order listed in `BejeweledRedux.toc`:

| Folder | Contents |
|---|---|
| `Core/` | Addon bootstrap (`Init.lua`), shared constants, AceDB saved variables, utilities, slash commands, login glue |
| `Data/` | Static tables: skills and achievements, the texture database (`Textures.lua`), fade presets |
| `Game/` | Board state, matching and hints, scoring, game flow (start/end/pause/save), mouse input |
| `Animation/` | Pooled visual effects and the 0.025 s animator loop that drives the board state machine |
| `UI/` | Main window, menus, popup, board and status bar, summary, Feats of Skill and About screens |
| `Features/` | High-score sync (AceComm), achievements, flight paths, optional open/close triggers, sound, minimap/LDB launcher |
| `Config/` | AceConfig options (in-window and in the Blizzard Settings panel) |
| `packs/` | The released texture packs, each a separate addon (not part of the main download) |
| `art/` | Editable art sources and guides; see [art/README.md](art/README.md) (not part of any download) |
| `scripts/` | Developer tools: library fetching, art guides, BLP conversion |

Conventions:
- Files share state through the addon namespace (`local _, ns = ...`) and the AceAddon object `ns.addon`. Never create globals.
- Code that needs saved variables or creates frames runs from `ns.RegisterBuilder(name, func)` (on `OnInitialize`); event registration and login logic run from `ns.RegisterEnabler(name, func)` (on `OnEnable`).
- Settings live in `ns.db.profile`, per-character progress in `ns.db.char`, account-wide data in `ns.db.global`.
- Lua 5.1 allows at most 60 upvalues per function; large functions should read rarely used constants as `C.NAME` instead of file-level locals.
- Settings are booleans (`true`/`false`), never `1`/`nil`. Unnamed frames take `nil` as their name, not `""`.
- Never hard-code image paths or texture coordinates. Add the image to `Data/Textures.lua` and use `ns.Textures.Path`, `Coords` or `Apply`, so texture packs can replace it. See [art/README.md](art/README.md).

### Midnight Restrictions (Retail and WoW Forever)
WoW Forever runs on the Retail engine, so these apply to both. Classic clients don't have them, but code must still work where they do.
- Addons no longer receive `COMBAT_LOG_EVENT_UNFILTERED`; use other events, such as the death recap or `PARTY_KILL`. Classic clients keep the combat log, and `Features/Achievements.lua` uses it there as a fallback.
- Unit data and event payloads can be *secret values* in instances, encounters and PvP. Check with `issecretvalue()` before comparing or doing arithmetic, and never do math on `UnitHealth`.
- Addon messages and chat can be locked down (`C_ChatInfo.InChatMessagingLockdown()`). `Features/HighScores.lua` queues messages until the lockdown lifts; follow the same pattern for anything that sends.

### Libraries
Ace3, LibDataBroker-1.1 and LibDBIcon-1.0 are not committed. Release builds pull them in through the `.pkgmeta` externals. For local testing, run `scripts/fetch-libs.sh` (Git Bash works on Windows) to populate `Libs/`.

---

## 📜 Licensing & Asset Attribution
- All new community contributions, bug fixes, and maintenance code are licensed under the **[MIT License](LICENSE)**.
- Original game design, art, sounds, and base code remain copyright **PopCap Games, Inc. / Electronic Arts**.
- Please credit any original ideas, patches, or third-party tools in [ACKNOWLEDGEMENT.md](ACKNOWLEDGEMENT.md).

---

## 🧪 Testing Guidelines
- Test changes in-game before submitting a PR, on Retail and, for anything touching client-specific code, on at least one Classic client. Use BugSack / BugGrabber to catch silent Lua errors.
- At minimum, check:
  - Login, the first-run legal notice and the splash screen.
  - A Classic game: play, pause, `/reload` to resume, game over and summary.
  - A Timed game running out.
  - A flight: opening on takeoff (if enabled), the Flight-mode game ending on landing, and flight times on the flight map tooltip.
  - The Feats of Skill, About and Options screens.
- Code that can only be confirmed in-game is marked `-- TODO(in-game):`. If you verify one, remove the marker in your PR.

## 🤖 AI-Assisted Contributions
- AI tools may be used, but you are responsible for the result: read the code, test it in-game, and make sure it follows this guide.
- Say in the PR description when a substantial part of a change was AI-generated.
