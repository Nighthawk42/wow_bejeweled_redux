# Bejeweled Redux for World of Warcraft

Bejeweled has returned to Azeroth! A game originally made by PopCap Games, Inc., rebuilt for modern World of Warcraft clients.

Bejeweled Redux is a ground-up modernization of the original addon. It installs as its own addon (`BejeweledRedux`) with its own saved data, so it can sit alongside the original. The original addon and its Classic releases are archived at [Nighthawk42/wow_bejeweled](https://github.com/Nighthawk42/wow_bejeweled).

## Client Versions

| Branch | Client Flavor | Interface Version | Status |
|---|---|---|---|
| [`main`](https://github.com/Nighthawk42/wow_bejeweled_redux/tree/main) | **Retail / Midnight** | `120100` | Current (1.0.0) |

The Classic flavors (Mists, Cataclysm, Wrath, TBC Anniversary and Classic Era) are being rebuilt on the new code base and will return as their own branches.

## Installation

1. Download the latest release zip from the [Releases](https://github.com/Nighthawk42/wow_bejeweled_redux/releases) page.
2. Extract the `BejeweledRedux` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

Release archives include everything. If you install Retail straight from a git checkout instead, run `scripts/fetch-libs.sh` first: the libraries (Ace3, LibDataBroker, LibDBIcon) are downloaded, not committed.

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
