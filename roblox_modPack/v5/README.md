# roblox_modPack / Realism v5.2 — Local weather and styles

## Start in Real Executor

One command:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/roblox_modPack/v5/load.lua"))()
```

Only use in environments in which you are allowed to use your executor. Modules are pinned by the loader to a fixed Git commit and the encoded releases include Adler32 byte checks; this is **not** unbreakable DRM or encryption.

## What actually changed

- **Snow**: impact-triggered 3D white irregular overlapping ellipsoid mounds, with random width/height/rotation, wind-influenced placement, small topography, 3D rooftops, non-linear mass based melting. No squared snow sheets.
- **Rain**: physically integrated droplet velocity/gravity, swept collision raycasts, rounded rain puddles and pooled ballistic splash particles; tiny expanding circular surface ripples. Sounds using real Roblox audio asset IDs (subject to Roblox asset permissions).
- **Storm**: real local 3D zig-zag lightning segments, white light flash, delayed thunder sample with randomized timing.
- **Hands, weapon handles**: local attached droplets/snow, running down moving limbs, detach with velocity and hit nearby ground. Cosmetic, not gameplay.
- **Physics**: target 90 fixed simulation steps/s with catchup capped to avoid hanging, measured rate on the UI.
- **Lighting**: realistic daylight and supported weather-dependent postprocessing; no injection of native GPU shaders.
- **14 styles**: Realism, Anime, Hello Kitty, Star Wars, WW2, Russia, Walter White, Galaxy, CS2, Sophy Rain, Kung Fu Panda, Stalin, Gewitter, Bright. These are **original approximate color/atmosphere looks**, not copyrighted imagery, not full cel-shading, and not wholesale changes to the game's geometry. Galaxy includes local 3D stellar dots rather than replacing the game's entire sky.
- **UI**: custom dark window, draggable and animated, independently set rain or snow 1–100%, style selection/intensity 1–100%, rain audio volume, local music player by Roblox audio ID, corner radius, opacity, image background from approved Roblox asset ID, remappable hotkeys. UI toggled by F10 by default.

## Limitations to expect
- This only changes **your local client**. No server terrain, hitboxes, target accuracy, weapon ballistics, other players' weather, or server object physics changes.
- Snow is a bounded visual surface mass model — it does not replace Roblox Terrain voxels or make physical snowbanks.
- Music plays on **your client only**. Ordinary Luau cannot route playing Roblox sounds into the networked microphone so other people hear them. This needs a supported OS virtual audio input and the game's voice chat permissions; not implemented here.
- Custom UI backgrounds use `rbxassetid://ID` for Roblox-approved image assets, not arbitrary `https` URLs, local PNG, or animated GIF.
- Sound asset IDs may be blocked by experience-level permissions. Example public Creator Store rain sound from Roblox: `1516791621`; impacts `9126179648`; storm sample `125355642447331`.
- All extra geometry has `CanCollide=false`, `CanQuery=false`, is local and temporary. Some clients may restrict the graphics effects. Loading many objects still costs GPU/CPU; lower strength or disable modules if FPS drops.
- Codec in `dist/*.lua` is reversible Hex/XOR, *not* a secure VM. The loader pins release modules to an immutable Git revision and packed files check their data with Adler32. A client can decode them.
- This has **not** been tested live inside Real Executor; only upload and packed-file byte integrity are verifiable here.

## File layout
`load.lua`: tiny pinned loader and shared 90-Hz job loop.
`core.lua`: core lighting/weather and verified impact event API.
`body.lua`: hands and equipped tool interactions.
`surface.lua`: irregular snow mounds and rounded puddle lenses.
`weatherfx.lua`: impacts/ripples, rain audio and thunder.
`styles.lua`: named cinematic looks and galaxy dots.
`worldfx.lua`: gentle fire lighting, tree foliage wind, scoped depth effects.
`optics.lua`: subtle atmospheric postprocessing.
`ui.lua`: fully custom draggable menu, dynamic sliders and audio.

`dist/`: code-packed, checksummed release files, not copy-protection.

## Default keys
F10 UI · F6 diagnostic (core) · F7 rain/snow/off · F8 base on/off · F9 intensity cycle.
Keybinds can be changed from the Custom tab. Rerunning the loader stops the old v5 instance and clears its effects.
