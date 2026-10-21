# Acknowledgements

*Bejeweled for World of Warcraft* is built upon the classic PopCap minigame and sustained by community maintainers.

## Original Game & Assets

- **PopCap Games, Inc.** (now Electronic Arts)  
  Original creator, designer, and developer of *Bejeweled* for World of Warcraft.  
  *(c) 2000, 2008 PopCap Games, Inc. All rights reserved.*

## Open-Source & Community Contributors

- **Sebastian ([`scbasss`](https://github.com/scbasss))**  
  - Fixed guild/friend score synchronization prefix registrations.
  - Fixed popup close buttons, brag dropdown crashes, keyboard input capture propagation, and UI improvements.
  - Added TBC Anniversary & Classic support.
- **Chrisliebär ([`chrisliebaer`](https://github.com/chrisliebaer))**  
  - Modern client updates, frame fixes, and window resizing improvements.
- **Nighthawk ([`Nighthawk42`](https://github.com/Nighthawk42))**  
  - Project maintenance, release builds, multi-client branches, and the 12.1.1 modernization (deobfuscation and modular rewrite).

## Third-Party Libraries

- **[Ace3](https://www.wowace.com/projects/ace3)** (AceAddon, AceDB, AceDBOptions, AceEvent, AceTimer, AceConsole, AceComm, AceSerializer, AceGUI, AceConfig), with LibStub, CallbackHandler and ChatThrottleLib  
  Copyright (c) 2007, Ace3 Development Team. See the license bundled with the library.
- **[LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1)** by Tekkub.
- **[LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0)** by the WowAce community.

The libraries are fetched at build time (see `.pkgmeta`) and are not part of this repository.
