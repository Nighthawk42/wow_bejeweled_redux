#!/usr/bin/env bash
# For each gem color: image-to-image clean sprite -> image-to-3d -> Blender 20-frame spin.
set -uo pipefail
cd "$(dirname "$0")"
M="python $HOME/.claude/skills/meshy/scripts/meshy.py"
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
W=$(cygpath -w "$PWD")

declare -A DESC=(
    [blue]="blue sapphire in its ornate gold frame"
    [green]="green emerald wrapped in golden thorny vines with green flame wisps"
    [white]="clear white diamond crystal in its silver setting"
    [purple]="purple vortex gem in its dark ornate setting"
    [yellow]="golden amber gem with a swirl in its bronze setting"
    [orange]="orange diamond-shaped fire gem with a swirl"
)

for color in "$@"; do
    echo "=== $color"
    prompt="Clean, high-resolution game sprite of this exact ${DESC[$color]}: same design, colors and shape, viewed straight on, centered with even margin, sharp edges, painted fantasy style, no background, no text, no extra objects."
    body=$(python -c 'import json,sys; print(json.dumps({"ai_model":"nano-banana-2","prompt":sys.argv[1],"reference_image_urls":["@"+sys.argv[2]],"aspect_ratio":"1:1","remove_background":True}))' "$prompt" "${color}_gem.png")
    out=$($M run image-to-image "$body" --out "./sprite_$color" 2>&1) || { echo "$out" | tail -5; continue; }
    sprite=$(ls "sprite_$color"/*_image0.png | head -1)
    cp "$sprite" "${color}_sprite.png"
    echo "sprite: $(echo "$out" | grep consumed_credits)"

    out=$($M run image-to-3d "{\"image_url\":\"@${color}_sprite.png\",\"should_texture\":true,\"target_formats\":[\"glb\"]}" --out "./model_$color" 2>&1) || { echo "$out" | tail -5; continue; }
    echo "model: $(echo "$out" | grep consumed_credits)"
    glb=$(ls "model_$color"/*_glb.glb | head -1)

    "$B" -b -P "$W\\render_spin.py" -- "$(cygpath -w "$PWD/$glb")" "$W\\frames_$color" 20 180 200 1 2>&1 | grep -E '^rendered'
done
