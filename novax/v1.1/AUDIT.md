# NovaX v1.1 — HitPart, Hitchance and hold-state audit

## Implemented
- Hit Part selector: Head, UpperTorso, LowerTorso, HumanoidRootPart, Random.
- R6 fallback uses Torso where R15 upper/lower torso parts do not exist.
- Hitchance slider: 0–100%, one-point increments.
- Chance is rolled once per physical MouseButton1 press. At 0%, the camera assist does not activate for that hold; at 100%, it activates whenever a valid target is available.
- While MouseButton1 remains down, the camera tracks the chosen part. InputEnded and WindowFocusReleased immediately release the hold state.
- No synthetic clicks, repeated firing calls, or remote spam.
- Snap uses standard Roblox client APIs and no executor metatable hooks.
- The previous internal raycast hook mode is removed in v1.1.

## Hitchance semantics
Hitchance means probability that camera assistance activates for one physical hold. It is not the probability that a server accepts a shot or registers damage. While held, the selected target part refreshes every 50 ms. A generic client script cannot reliably detect every bullet in every game's private weapon implementation.

## Static checks
- HitPart options, R6 fallbacks and Random-per-hold selection are present.
- Hitchance 0 and 100 boundaries are explicit.
- InputBegan, InputEnded, WindowFocusReleased and RenderStepped are connected.
- No installInternalRayHook, hookmetamethod shot redirector or Hook (Internal) UI option remains.
- Roblox Creator Hub documents UserInputService InputBegan/InputEnded and WindowFocusReleased. See https://create.roblox.com/docs/reference/engine/classes/UserInputService

## Not tested
No live Real Executor session was run. Static code and GitHub retrieval do not prove that every executor supports loadstring/HttpGet or that camera changes cooperate with a particular game's camera and weapon code.
