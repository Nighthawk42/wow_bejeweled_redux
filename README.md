# Bejeweled for World of Warcraft

Bejeweled has returned to Azeroth! A game originally made by PopCap Games, Inc., maintained for modern World of Warcraft clients.

## Client Versions

| Branch | Client Flavor | Interface Version | Status |
|---|---|---|---|
| [`main`](https://github.com/Nighthawk42/wow_bejeweled/tree/main) | **Retail / Midnight** | `120100` | Current (12.1.1) |

The Classic flavors (Mists, Cataclysm, Wrath, TBC Anniversary and Classic Era) are being rebuilt on the new code base and will return as their own branches.

## Installation

1. Download the latest release zip from the [Releases](https://github.com/Nighthawk42/wow_bejeweled/releases) page.
2. Extract the `Bejeweled` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

Release archives include everything. If you install Retail straight from a git checkout instead, run `scripts/fetch-libs.sh` first: the Ace3 and LibDBIcon libraries are fetched, not committed.

## Usage

- `/bej` toggles the game window. `/bej options`, `/bej reset` and `/bej help` are also available.
- Click the minimap button or the addon compartment entry to toggle the window; right-click the minimap button for options.
- Options are also under **Settings → AddOns → Bejeweled**.

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
