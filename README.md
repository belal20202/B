# Bassam — بسام
Iraqi 3D endless runner for Android (Godot 4.3, GDScript). **صنع في العراق — Made in Iraq.**

## Get the APK (no software to install)
1. Create a new GitHub repository and upload everything in this folder (keep the `.github` folder).
2. Open the **Actions** tab → **Build Android APK** → it runs on every push (or press *Run workflow*).
3. When it finishes, open the run and download the artifact **Android-APK**. Unzip it and install `Bassam.apk` on your phone (allow installs from unknown sources).

## Controls
Swipe left / right to change lane, up to jump, down to roll. Android back button pauses.

## Features
- 3 lanes, trains (some move toward you), taxis, concrete blocks, market stalls, overhead bars
- Power-ups: magnet, jetpack, ×2 coins, jump boots, shield — each upgradable with coins (6 levels)
- 20 outfits (the first, the green shirt, is free), live preview in the wardrobe
- Six invented cities change with distance every 1,200 m: Salmora → Helanor → Korband → Navira → Demara → Yaslun
- Missions, daily reward, revive (500 coins), saved progress
- Procedural music (Hijaz maqam + darbuka rhythm) and sound effects — no audio files needed
- Animated home screen with a live 3D scene

## Graphics v2
- Detailed runner: blinking eyes, lips, mustache and stubble, layered hair, jointed hands and shoes, outfit details (jersey number, robe buttons, ghutra tails that flutter), squash-and-stretch, contact shadow
- Day cycle across the cities (afternoon, noon, sunset, night with lit windows, moon and stars, sunrise)
- Roads with asphalt texture, cracks, patches, manholes, zebra crossings, edge lines, tram rails, tiled sidewalks
- Animated scenery: swaying palms, flags, bunting, walking pedestrians, boats, birds, drifting clouds, cars on overpasses
- Animated obstacles: spinning train and taxi wheels, swaying trains, bouncing taxis, blinking warning lights
- Dust, landing puffs and speed lines; three graphics levels in Settings (use low on weaker phones)

## Notes
- All text is Arabic and uses a bundled font (fonts/arabic.ttf, DejaVu Sans Bold, see FONT-LICENSE.txt).
- The APK is a debug-signed build, fine for testing and sharing. For store release, add your own release keystore.
