#!/usr/bin/env bash
# Populate Libs/ for local testing. Release builds get the same libraries from
# the .pkgmeta externals via the BigWigs packager.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
libs="$root/Libs"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git clone -q --depth 1 https://github.com/WoWUIDev/Ace3.git "$tmp/ace3"
git clone -q --depth 1 https://github.com/tekkub/libdatabroker-1-1.git "$tmp/ldb"

rm -rf "$libs"
mkdir -p "$libs/LibDataBroker-1.1" "$libs/LibDBIcon-1.0"
for lib in LibStub CallbackHandler-1.0 AceAddon-3.0 AceEvent-3.0 AceTimer-3.0 AceConsole-3.0 \
    AceDB-3.0 AceDBOptions-3.0 AceSerializer-3.0 AceComm-3.0 AceGUI-3.0 AceConfig-3.0; do
    cp -r "$tmp/ace3/$lib" "$libs/"
done
cp "$tmp/ldb/LibDataBroker-1.1.lua" "$libs/LibDataBroker-1.1/"
for f in LibDBIcon-1.0.lua lib.xml; do
    curl -sfL -o "$libs/LibDBIcon-1.0/$f" "https://repos.wowace.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0/$f"
done

echo "Libraries installed to $libs"
