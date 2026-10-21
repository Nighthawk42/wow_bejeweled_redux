# Contributing to Bejeweled for World of Warcraft

Thank you for helping maintain and improve *Bejeweled for World of Warcraft*! This guide explains our multi-client branch architecture and workflow for contributing bug fixes, features, and compatibility updates.

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
- **Version Strings:** Update `## Version:` in `Bejeweled.toc` (the About screen reads it from there) and tag the release `vX.Y.Z`. Pushing the tag runs the release workflow.

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

### Libraries
Ace3, LibDataBroker-1.1 and LibDBIcon-1.0 are not committed. Release builds pull them in through the `.pkgmeta` externals. For local testing, run `scripts/fetch-libs.sh` (Git Bash works on Windows) to populate `Libs/`.

---

## 📜 Licensing & Asset Attribution
- All new community contributions, bug fixes, and maintenance code are licensed under the **[MIT License](LICENSE)**.
- Original game design, art, sounds, and base code remain copyright **PopCap Games, Inc. / Electronic Arts**.
- Please credit any original ideas, patches, or third-party tools in [ACKNOWLEDGEMENT.md](ACKNOWLEDGEMENT.md).

---

## 🧪 Testing Guidelines
- Whenever possible, test changes live in-game on the appropriate client version before submitting a PR.
- Use a Lua error reporting addon (e.g., BugSack / BugGrabber) to ensure no silent errors or frame leaks occur during gameplay, score syncing, flight paths, or game transitions.
