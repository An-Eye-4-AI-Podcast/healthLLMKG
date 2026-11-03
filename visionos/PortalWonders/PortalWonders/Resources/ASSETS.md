# Asset manifest

Drop files here with these exact basenames. Everything except the panoramas is optional: with
no video the app projects the still panorama onto a 360° dome (and lights the creatures from
it); with no model it uses primitive stand-in creatures; with no audio it stays quiet. The
in-world HUD lists whatever it could not find.

Asset resolution order per world: video → panorama still → flat backdrop colour.

| Slot | File | Notes |
|------|------|-------|
| Trench panorama | `Panoramas/trench_pano.jpg` | **Included.** 2:1 equirectangular still, used when the video is absent |
| Valley panorama | `Panoramas/valley_pano.jpg` | **Included.** Same |
| Den panorama | `Panoramas/den_pano.jpg` | **Included.** Same |
| Trench video | `Videos/trench_360.mp4` | Full 360° mono equirectangular (2:1). HEVC, ≤ 4096×2048 |
| Valley video | `Videos/valley_180.mp4` | VR180 **mono** half-equirectangular (1:1 per hemisphere, i.e. 2048×2048) |
| Den video | `Videos/den_180.mp4` | Same as valley |
| Narwhal | `Models/narwhal.usdz` | Nose along +Z, origin at centre of mass, metres. Clips: `swim`, `spin` |
| Mermaid | `Models/mermaid.usdz` | Faces +Z, origin at tail tip (y = 0). Clips: `idle`, `wave` |
| Unicorn | `Models/unicorn.usdz` | Faces +Z, origin between hooves (y = 0). Clips: `walk`, `rear` |
| Puppy | `Models/puppy.usdz` | Faces +Z, origin at paws (y = 0). Clips: `sit`, `jump` |
| Ambience | `Audio/{trench,valley,den}_ambience.m4a` | Loops. `.mp3`/`.wav` also accepted |

`.mov`/`.m4v` work for video too. The video's own soundtrack plays as well, so mute the file
if you rely on the ambience bed.

## Model orientation

`CreatureSystem` assumes the model's nose points down **+Z**. If your export faces −Z (the
common USD/Blender convention), set `modelYawOffset: .pi` on that `CreatureSpec` in
`Environments/WonderEnvironment.swift`. If the asset has no animation clips the system
falls back to procedural motion (swoop / footfall bob / hops) plus a `head` and `tail` pivot
wag when entities with those names exist.

## Stereo footage

The dome is a single `VideoMaterial`, so it renders **mono**. For stereo (MV-HEVC / APMP)
immersive video you would use `VideoPlayerComponent` with an immersive viewing mode, which
takes over the whole space rather than sitting inside a portal. Mono inside the portal is the
Encounter Dinosaurs trade-off too: parallax comes from the 3D creatures, not the backdrop.
