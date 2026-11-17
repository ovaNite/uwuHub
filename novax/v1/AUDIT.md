# NovaX v1.0 — Source audit and compatibility status

**Source:** original attached 7,466-line `message (2).txt` split into full `ui/NovaPremiumUI.lua` + `core/legacy.lua`. It contained about **247 named function declarations** (93 in the UI portion, 154 in main) and about **110 control-creation call sites**. These are textual counts, not independent tests of function behavior.

## Source preservation and changes
- Full original Premium UI and functional main code are stored separately. The new GUI reuses the entire original API rather than substituting a simpler menu.
- Added `Credits` tab: **Klaus (Dev)** and **Nexus (Bug Fixer)**.
- Changed blue-glow-heavy palette to restrained dark graphite, slightly tighter corners and quicker transitions.
- Preserved original routines: `setupCombat`, `setupTrigger`, `setupESP`, `setupMovement`, `setupInfJump`, `setupBeggerFarm`, `setupAutoBackstab`, settings/config controls and main window.
- Silent Aim originally offered only `No Hook` and spun the camera for a few milliseconds around firing. The previous code also tried to fire generic remotes without their expected arguments. Replaced this Silent Aim path with **Snap** and **Hook (Internal)**, without invoking arbitrary weapon remotes.
- The internal mode is a **conditional client __namecall Raycast interceptor** restricted to camera-origin raycasts and a short firing window. It only initializes if `hookmetamethod`, `newcclosure`, `getnamecallmethod` and `checkcaller` are present. Hook presence does NOT imply actual hit registration. Repeated starts reuse a disabled-on-stop hook gate rather than stacking hooks.
- The Snap mode visibly orients the local camera toward an on-screen opponent during a manual shot. It does not guarantee server damage.
- Reduced excessive `MAX_TRIGGER_CPS` from 500 to 30 to avoid an unrealistic input loop; this is still an upper bound and may exceed any specific game's accepted firing rate.
- Added runtime capability audit and independent Weather tab to the existing GUI.

## Capability matrix

| Area | Source review | Runtime status |
| --- | --- | --- |
| UI, controls, settings/config | Existing implementations preserved | Requires executor/client test |
| AimLock/AutoAim/RageBot | Scheduler and target-selection code present | Game-specific accuracy untested |
| Silent Aim Snap | Camera reorientation code now present | Must test with each game's weapon behavior |
| Silent Aim Hook (Internal) | Gated `__namecall` hook now present | Requires executor APIs and compatible client Raycast weapon |
| ESP (names, boxes, skeleton etc.) | `setupESP` and GUI controls present | May require Drawing and compatible characters |
| Trigger | `setupTrigger` present; cap adjusted | Server shot acceptance untested |
| Speed, Fly, NoClip, InfJump, BunnyHop | Original routines remain | Game movement authority can override |
| AutoBackstab/BeggerFarm | Original routines remain | Experience-specific, behavior unverified |
| FullBright/NoFog | Lighting override routines remain | Client visual effect only |
| FPS unlock/boost | Uses executor-only `setfpscap` and graphics controls | May fail or be restricted |
| HitboxExpander | State setting present but no complete behavior found | **Not verified/likely nonfunctional** |
| NoSpread | State setting present but no complete implementation found | **Not verified/likely nonfunctional** |
| Wallbang | References exist but no game-wide implementation found | **Not verified/likely nonfunctional** |
| Device/control spoof | Attempts executor/game-specific operations | Never assume server spoof succeeded |
| Weather snow/rain | v9 solver+particles and new adaptive bridge | 90Hz target; results/FPS untested in Roblox |
| RTX ray tracing | Engine exposes `Raycast`, not native RTX enablement | **Not supported as actual GPU RTX via Luau** |

## Public documented Roblox APIs vs executor features

Documented Roblox API surfaces used in the code include:
- `Workspace:Raycast`, `RaycastParams`: https://create.roblox.com/docs/workspace/raycasting
- `Camera:ViewportPointToRay`: https://create.roblox.com/docs/reference/engine/classes/Camera
- `RunService.Heartbeat` and frame scheduling: https://create.roblox.com/docs/reference/engine/classes/RunService
- `ParticleEmitter` and wind/drag behavior: https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter

Executor-only calls such as `getgenv`, `hookmetamethod`, `checkcaller`, `setfpscap`, `gethui`, `Drawing`, `readfile` and `getconnections` **are not Roblox public-engine APIs** and cannot be independently certified for all executors from repository code alone. The read-only runtime `capabilities.lua` reports availability without trying dangerous privileged operations.

## Weather

The NovaX weather module loads its fixed v9 physics modules separately, **without loading the old ModPack UI or duplicate snow systems**. It starts in OFF mode. The settings include rain/snow intensity (1–100%), snow quality ECO/BALANCED/ULTRA, wind/snow impact, spray/mist, wet floors, camera lens rain, audio and an optional storm. A simple performance controller reduces the particle level at sustained lower measured FPS. The 90Hz accumulator is a **simulation-step target**, and caps the number of catch-up steps per rendered frame.

## What has actually been tested here
1. Source reconstructed from the uploaded text at the original 236,553-character length and split at exact UI/main boundaries.
2. Repository modules uploaded and retrieved at an immutable revision.
3. Static checks for the original major function names, new aim modes and GUI credits.
4. No live Roblox/Real Executor test available, so no claim that all features work in a real game.

## Test procedure for user
1. Close Roblox and old NovaX/ModPack scripts to avoid stacked hooks and effects.
2. Run `novax/v1/start.lua` once and check console for errors.
3. Open NovaX with K. Select **Compatibility** to inspect reported executor APIs.
4. Verify Snap separately from Hook. If Hook prerequisites are missing, use Snap. Do not assume server-confirmed hits from client visual effects.
5. Open Weather, enable Snow at Balanced. Compare impact counters and FPS. Try Eco at lower FPS.
6. Report console errors with exact mode and game; individual fixes should be made against reproducible evidence.
