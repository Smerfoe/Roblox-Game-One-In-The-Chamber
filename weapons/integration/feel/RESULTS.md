# FPS response pass — 2026-11-01

Installed in Studio and left in Edit mode; not published. Backup: `ServerStorage.Backups.BeforeResponsiveness_2026_11_01`.

## Changes

- Local recoil/slash presentation, gunshot/swing sound, muzzle flash and cosmetic casing now start on a locally eligible attack request. Clients still cannot authorize ammo, hits or damage. Obvious countdown/dead/empty/cooldown attempts are filtered locally; server checks remain authoritative.
- Request IDs are echoed on accepted server cues. The owning client suppresses duplicate predicted animations/audio/muzzle effects. Confirmed tracer/endpoints still originate from the server's raycast. Unpredicted cues retain their previous presentation path.
- White hit / red elimination marker appears only for a server-confirmed damaging hit/elimination.
- Sound assets preload asynchronously. Knife draw has a distinct cue name from attacks so repeated attacks can be checked independently.
- The viewmodel caches character parts rather than searching the character tree every rendered frame. A named MicroProfiler scope wraps weapon placement.
- Sprint/slide camera field of view now eases toward a modest +4/+2 degrees while armed and returns toward the original value. Existing smoothed camera height and weapon motion remain. This new FOV transition has not been visually verified because rendered-frame sampling was unavailable.

## Executed checks

- Clean play startup after integration; no new runtime script errors in the final session. Existing Studio DataStore API warning remains the intended memory fallback.
- An in-context temporary client probe called the actual WeaponController.TryFire path. First effect object creation was approximately 0.45 ms after the request began. Exactly one shot sound, muzzle flash and confirmed tracer were observed. This is script-side creation time, NOT displayed input-to-photon latency.
- Repeated with an explicitly temporary 250 ms server-processing delay: predicted shot sound/flash were created around 0.4 ms; confirmed tracer arrived around 299 ms. One sound/flash/tracer was observed. Knife attack was accepted after the same delay; total swing sound count included the separate automatic knife-draw sound. The draw cue is now named separately.
- Practice-target shot: target health reached 0, ammo was restored to 1, red confirmed-elimination marker was visible (TextTransparency 0). The server logged the elimination.
- Temporary server delay and LocalScript probe were removed. Verified no probe or artificial delay remains. All six global network-simulation settings remain at their starting zero values; no network shaping was applied.

## Limits — do not claim complete smoothness

The client RenderStepped probes returned zero rendered frames, including from a real LocalScript. MicroProfiler backend was accessible, but its captured session had no usable frame descriptor for this test. Therefore no FPS, 95th-percentile frame time, GPU bound conclusion, or performance target is claimed. Foregrounding Studio did not resolve sampling. Profiler enabled for the test was disabled afterward.

The artificial server-processing delay is a cue-ordering/responsiveness regression check; it is not packet loss, network jitter or a full latency simulation. No real two-client match was run. Broad device/graphics testing, perceived input latency, visual recoil/camera comfort, and observer behavior remain unverified. These require an actively rendering Studio test and two clients.

GitHub main remains at commit 78e0366c347ff21bf51f1d5cf141ac89aaab1885 (October 30). That establishes no newer main-branch changes since the earlier check; it does not reveal Claude's private chat, other branches or uncommitted activity.

## Applying sources elsewhere

These are snapshots of modules in the existing project, not a standalone game. Create RemoteEvent `ReplicatedStorage.Remotes.HitFeedback` before starting the updated controllers/server service. Keep the existing PolishEffect/ShotAccepted/SwingAccepted/Fire/Melee remotes and shared dependencies. Update all seven modules in this folder together so request IDs and prediction suppression agree. Existing armory integration modules remain necessary. Restore matching controller/server/effects backups together to roll back.

