# Bejeweled Redux for World of Warcraft

Bejeweled has returned to Azeroth! A game originally made by PopCap Games, Inc., rebuilt for modern World of Warcraft clients.

Bejeweled Redux is a ground-up modernization of the original addon. It installs as its own addon (`BejeweledRedux`) with its own saved data, so it can sit alongside the original. The original addon and its Classic releases are archived at [Nighthawk42/wow_bejeweled](https://github.com/Nighthawk42/wow_bejeweled).

## Supported Clients

One download works on every supported client.

| Client | Interface | Status |
|---|---|---|
| **Retail** (Midnight) | `120100` | Supported |
| **WoW Forever** | `16001` | Supported (beta client) |
| **Mists of Pandaria Classic** | `50504` | Supported |
| **Titan Reforged** (Wrath) | `38002` | Supported |
| **TBC Anniversary** | `20506` | Supported |
| **Classic Era** | `11509` | Supported |

On Classic Era, "Two Gems Enter, One Gem Leaves" (win an arena match) is unavailable because the client has no arenas, and it doesn't count against "Complete all Achievements".

## Installation

1. Download the latest release zip from the [Releases](https://github.com/Nighthawk42/wow_bejeweled_redux/releases) page.
2. Extract the `BejeweledRedux` folder into your client's `Interface/AddOns/` folder, for example `World of Warcraft/_retail_/Interface/AddOns/` or `World of Warcraft/_classic_era_/Interface/AddOns/`.

Release archives include everything. If you install straight from a git checkout instead, run `scripts/fetch-libs.sh` first: the libraries (Ace3, LibDataBroker, LibDBIcon) are downloaded, not committed.

## Texture Packs

Texture packs change the game's art. Each pack is a small addon of its own, attached to every [release](https://github.com/Nighthawk42/wow_bejeweled_redux/releases) next to the main download:

| Download | Pack | What it changes |
|---|---|---|
| `BejeweledRedux_2x-<version>.zip` | **HD (2x)** | Every texture at twice the original resolution (AI-upscaled original art) |
| `BejeweledRedux_4x-<version>.zip` | **Ultra HD (4x)** | Every texture at four times the original resolution (AI-upscaled original art) |
| `BejeweledRedux_Concept-<version>.zip` | **Concept** | New gems that spin in 3D, a new logo, window border, icon and stone background, in a darker fantasy style |

To use a pack:

1. Install Bejeweled Redux first; packs need it.
2. Extract the pack's folder (for example `BejeweledRedux_4x`) into the same `Interface/AddOns/` folder.
3. Restart the game client fully. The game only picks up new addon folders at startup.
4. Open **Options → General → Texture Pack**, choose the pack, then type `/reload`.

Choose **Default** in the same place to go back to the original art. You can install several packs and switch between them.

The packs use PNG images. PNG is confirmed on Retail and WoW Forever; on the Classic clients it hasn't been tested yet, so if a pack shows blank textures there, switch back to Default and let us know.

Want to make your own? See [art/README.md](art/README.md). All you need is an image editor.

## Usage

- `/bej` toggles the game window. Subcommands: `show`, `hide`, `options`, `reset` (erases this character's progress) and `help`. `/bejeweled` works too; if the original Bejeweled addon is also installed, use `/bejredux`, which always reaches this one.
- Click the minimap button or the addon compartment entry to toggle the window; right-click the minimap button for options.
- Options are also under **Settings → AddOns → Bejeweled Redux**, including a key binding to toggle the window.

## Feedback & Contributions

- If you encounter bugs, please report them with detailed error messages/traces.
- Contributions and Pull Requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the code layout and workflow.

## Documentation & License

- [Contributing Guide](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
- [Acknowledgements](ACKNOWLEDGEMENT.md)
- [License (MIT)](LICENSE)

---

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/P5P21QRW51)
