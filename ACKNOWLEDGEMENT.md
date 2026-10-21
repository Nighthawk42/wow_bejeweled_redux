# Acknowledgements

*Bejeweled Redux* is built upon the classic PopCap minigame and sustained by community maintainers.

## Original Game & Assets

- **PopCap Games, Inc.** (now Electronic Arts)  
  Original creator, designer, and developer of *Bejeweled* for World of Warcraft.  
  *(c) 2000, 2008 PopCap Games, Inc. All rights reserved.*

## Open-Source & Community Contributors

- **Kadecgos**  
  - Previous maintainer of the original addon (credited in the in-game About screen).
- **Sebastian ([`scbasss`](https://github.com/scbasss))**  
  - Fixed guild/friend score synchronization prefix registrations.
  - Fixed popup close buttons, brag dropdown crashes, keyboard input capture propagation, and UI improvements.
  - Added TBC Anniversary & Classic support.
- **Chrisliebär ([`chrisliebaer`](https://github.com/chrisliebaer))**  
  - Modern client updates, frame fixes, and window resizing improvements.
- **Nighthawk ([`Nighthawk42`](https://github.com/Nighthawk42))**  
  - Project maintenance, release builds, multi-client branches, and Bejeweled Redux (deobfuscation and modular rewrite).

## Third-Party Libraries

- **[Ace3](https://www.wowace.com/projects/ace3)** (AceAddon, AceDB, AceDBOptions, AceEvent, AceTimer, AceConsole, AceComm, AceSerializer, AceGUI, AceConfig), with LibStub, CallbackHandler and ChatThrottleLib  
  Copyright (c) 2007, Ace3 Development Team. See the license bundled with the library.
- **[LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1)** by Tekkub.
- **[LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0)** by the WowAce community.

The libraries are fetched at build time (see `.pkgmeta`) and are not part of this repository.

## AI Assistance Disclaimer

Parts of Bejeweled Redux were produced with **Claude Opus 5.5**, a large language model by Anthropic, under the direction and review of the maintainer. This includes deobfuscating the original code, the modular rewrite, the Midnight API updates and this documentation. All AI-generated code was reviewed and tested in-game by the maintainer before release. PopCap's original game design, sounds and built-in art (`images/`) were not generated or altered by AI.

The optional texture packs are different:

- **HD (2x)** and **Ultra HD (4x)** are the original PopCap art upscaled with an AI upscaler (Upscayl).
- **Concept** is new art made with AI from the concept sheets in `art/custom/`: the gems were cleaned up and turned into 3D models, and the logo, border, icon and background were generated, with **Meshy** (meshy.ai), then rendered or cut to size with Blender and scripts. The concept art follows PopCap's design, and Bejeweled remains a trademark of Electronic Arts.
