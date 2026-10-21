# Contributing to Bejeweled for World of Warcraft

Thank you for helping maintain and improve *Bejeweled for World of Warcraft*! This guide covers getting set up, how the code is organized, and the workflow for bug fixes, features, and client compatibility updates.

---

## 🚀 Getting Started

1. Clone the repository and run `scripts/fetch-libs.sh` (Git Bash works on Windows) to download the libraries into `Libs/`.
2. Make the checkout visible to the game. Either copy it to `World of Warcraft/_retail_/Interface/AddOns/Bejeweled`, or link it so edits apply on `/reload`:
   - Windows: `mklink /J "<WoW>\_retail_\Interface\AddOns\Bejeweled" "<path to checkout>"`
   - macOS/Linux: `ln -s <path to checkout> "<WoW>/_retail_/Interface/AddOns/Bejeweled"`
3. Only the runtime files are needed in-game: `Bejeweled.toc`, `embeds.xml`, the code folders, `Libs/`, `images/` and `sounds/`.

---

## 🌿 Branches

| Branch | Client Flavor | Interface Version | Purpose |
|---|---|---|---|
| [`main`](https://github.com/Nighthawk42/wow_bejeweled/tree/main) | **Retail / Midnight** | `120100` | Default development branch |

Classic flavors will get their own branches, built from `main` with flavor-specific API changes.

---

## 🛠️ Development & Contribution Workflow

### 1. General Fixes & Features
- Base your work on `main`, test it in-game, and open a Pull Request against `main`.
- Changes that apply to every client are propagated from `main` to the flavor branches once they exist.

### 2. Flavor-Specific Fixes (API Differences)
- Fixes that only apply to one client go directly against that client's branch. Note in the PR description why the change is flavor-specific.

### 3. TOC & Versioning Conventions
- **Single TOC:** Each branch has one `Bejeweled.toc`. Do not introduce flavor suffixes (`Bejeweled_Mainline.toc`, etc.).
- **TOC Interface Numbers:** Ensure `## Interface:` matches the latest patch interface value for that client flavor.
- **Version Strings:** Update `## Version:` in `Bejeweled.toc` (the About screen reads it from there) and add a matching entry to [CHANGELOG.md](CHANGELOG.md).

### 4. Releases
- Tag the release commit `vX.Y.Z` and push the tag. The release workflow runs the BigWigs packager, which fetches the libraries listed in `.pkgmeta` and publishes the zip as a GitHub release.

---

## 🧱 Code Layout

The addon is split into one file per system, loaded in the order listed in `Bejeweled.toc`:

| Folder | Contents |
|---|---|
| `Core/` | Addon bootstrap (`Init.lua`), shared constants, AceDB saved variables, utilities, slash commands, login glue |
| `Data/` | Static tables: skills and achievements, large-text atlas, fade presets |
| `Game/` | Board state, matching and hints, scoring, game flow (start/end/pause/save), mouse input |
| `Animation/` | Pooled visual effects and the 0.025 s animator loop that drives the board state machine |
| `UI/` | Main window, menus, popup, board and status bar, summary, Feats of Skill and About screens |
| `Features/` | High-score sync (AceComm), achievements, flight paths, optional open/close triggers, sound, minimap/LDB launcher |
| `Config/` | AceConfig options (in-window and in the Blizzard Settings panel) |

Conventions:
- Files share state through the addon namespace (`local _, ns = ...`) and the AceAddon object `ns.addon`. Never create globals.
- Code that needs saved variables or creates frames runs from `ns.RegisterBuilder(name, func)` (on `OnInitialize`); event registration and login logic run from `ns.RegisterEnabler(name, func)` (on `OnEnable`).
- Settings live in `ns.db.profile`, per-character progress in `ns.db.char`, account-wide data in `ns.db.global`.
- Lua 5.1 allows at most 60 upvalues per function; large functions should read rarely used constants as `C.NAME` instead of file-level locals.
- Settings are booleans (`true`/`false`), never `1`/`nil`. Unnamed frames take `nil` as their name, not `""`.

### Midnight (12.x) Restrictions
- Addons no longer receive `COMBAT_LOG_EVENT_UNFILTERED`; use other events, such as the death recap or `PARTY_KILL`.
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
- Test changes in-game on the client the branch targets before submitting a PR. Use BugSack / BugGrabber to catch silent Lua errors.
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
