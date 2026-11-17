# NovaX v1.1 — HitPart + Hold Snap

Developers: **Klaus (Dev)** and **Nexus (Bug Fixer)**.

## New loader

    loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/novax/v1.1/start.lua"))()

## Silent Aim / Snap
- Snap is the only enabled mode in this release and does not use executor metatable hooks.
- Hit Part: Head, UpperTorso, LowerTorso, HumanoidRootPart or Random.
- R6 rigs use Torso fallback where R15 torso parts are absent.
- Hitchance is adjustable from 0 to 100 in one-point increments.
- The chance is rolled once per Mouse1 press. It does not reroll while held.
- Hold Mouse1 to keep the camera aligned; release Mouse1 to stop. Window focus loss also releases it.
- No synthetic mouse clicks, repeated FireServer calls or automatic fire spam.

Hitchance means chance to activate camera assistance for one physical hold. It is not a guarantee of server-side projectile hits. Snap changes the local camera; it is not silent server-side shot redirection.

The previous internal hook option was removed from this release. A generic client hook cannot promise all weapon systems or all games will register a hit.

## Original features
The supplied original Premium UI library and main feature core are preserved as separate modules. Existing aim, ESP, trigger, movement, configuration and other original controls remain; individual features still require experience/executor testing.

## Weather
The v9 weather bridge is retained: rain/snow modes, 1–100 intensity, snow quality, wind and impact effects, wet surfaces, camera rain, sounds and adaptive quality. It starts OFF. Its 90 Hz value is a fixed-step simulation target, not guaranteed real FPS.

## Diagnostics
Run the compile-only verifier:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/novax/v1.1/verify.lua"))()

This checks module download and Luau compilation only. It does not prove executor compatibility or live-game behavior.

See AUDIT.md for precise status and limitations.
