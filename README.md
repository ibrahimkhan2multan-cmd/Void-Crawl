"VOIDCRAWL Game Icon" (media/game-icon.png)

VOIDCRAWL — Mobile Dungeon Adventure

"Godot Engine" (https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)
"Platform" (https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
"Genre" (https://img.shields.io/badge/Genre-3D_Action_RPG-8B5CF6)
"Development Status" (https://img.shields.io/badge/Status-In_Development-orange)
"GitHub commit activity" (https://img.shields.io/github/commit-activity/m/YOUR_USERNAME/YOUR_REPOSITORY)

VOIDCRAWL is an original 3D dungeon-crawling adventure being developed for Android using Godot Engine.

Explore mysterious dungeons, fight dangerous creatures, discover valuable loot, upgrade your equipment, and challenge powerful bosses in a dark fantasy world.

Inspired by the dungeon-crawling genre, VOIDCRAWL aims to deliver an accessible mobile action RPG with original characters, environments, combat mechanics, and a distinctive black-and-purple visual identity.

Objective

Create a complete, playable Android dungeon crawler with responsive touchscreen controls, engaging combat, dungeon exploration, equipment progression, and challenging boss encounters.

The project prioritizes mobile performance, scalable gameplay systems, reusable environments, and an automated Android build workflow.

Features

Gameplay

- Third-person or isometric 3D exploration.
- Touchscreen movement and combat controls.
- Melee and ranged combat.
- Multiple enemy types and combat encounters.
- Boss battles with unique attack patterns.
- Health, damage, healing, and character progression.
- Loot collection, equipment, and inventory management.
- Dungeon objectives, treasure rooms, and rewards.

World and Exploration

- Stylized blocky 3D environments.
- Dark fantasy dungeons, caves, and ancient ruins.
- Reusable room layouts and procedural dungeon generation.
- Hidden locations, treasure chests, and environmental details.
- Original creatures, equipment, and world design.

Mobile Experience

- Android-first development.
- Touch-friendly interface and HUD.
- Adjustable graphics settings where practical.
- Performance-conscious rendering.
- Save and load support.
- Installable APK builds for testing.

Features listed above are project goals. Refer to the current build and roadmap to determine what is implemented and tested.

Installation

Android APK

When a tested Android build becomes available:

1. Open the repository's Releases page.
2. Select a release containing an APK.
3. Download the APK to your Android device.
4. Allow installation from the relevant source if Android requests permission.
5. Install and launch VOIDCRAWL.

"View Releases" (../../releases)

If no release is available yet, the game has not been published as a downloadable release.

Development Build

When GitHub Actions is configured to export Android builds:

1. Open the repository's Actions tab.
2. Select a successful Android build workflow.
3. Open the completed workflow run.
4. Download the APK from its Artifacts section.
5. Install the APK and test the game.

Running the Godot Project

1. Install a compatible version of Godot Engine 4.
2. Clone or download the repository.
3. Open the project using Godot's Project Manager.
4. Import the project resources.
5. Open the main scene and run the project.

Android export requires compatible export templates and Android build dependencies.

Development Roadmap

- [ ] Establish a working Godot project.
- [ ] Implement player movement and camera controls.
- [ ] Add mobile touchscreen controls.
- [ ] Create the first playable dungeon.
- [ ] Implement enemies and combat.
- [ ] Add health, healing, and damage feedback.
- [ ] Implement loot and inventory systems.
- [ ] Add equipment progression.
- [ ] Create a complete boss encounter.
- [ ] Implement saving and loading.
- [ ] Improve visual effects and audio.
- [ ] Optimize for Android devices.
- [ ] Configure automated APK builds.
- [ ] Publish the first playable release.

Technology

Component| Technology
Engine| Godot Engine 4
Programming| GDScript
Platform| Android
Version Control| Git and GitHub
Build Automation| GitHub Actions
Game Style| 3D action-adventure

Documentation

Documentation will be expanded as the project develops.

- "Gameplay Overview" (docs/Gameplay.md)
- "Controls" (docs/Controls.md)
- "Combat System" (docs/Combat.md)
- "Inventory and Equipment" (docs/Inventory.md)
- "Dungeon Generation" (docs/Dungeons.md)
- "Android Builds" (docs/AndroidBuilds.md)
- "Development Roadmap" (docs/Roadmap.md)

Documentation links become active when the corresponding files are added to the repository.

Media

Screenshots

Screenshots of the actual playable game will be added here as development progresses.

Main Menu| Dungeon Gameplay| Boss Encounter
Coming soon| Coming soon| Coming soon

Contributing

Ideas, bug reports, and constructive feedback are welcome.

When reporting a bug, include the following where possible:

- Steps to reproduce the problem.
- Expected behavior.
- Actual behavior.
- Relevant error logs or screenshots.
- Android device and game build information.

License

The project license will be specified in the repository.

Third-party assets, plugins, and dependencies must retain their applicable licenses.

Links

- "Source Code" (../../)
- "Issues" (../../issues)
- "Releases" (../../releases)
- "GitHub Actions" (../../actions)
- "Godot Engine" (https://godotengine.org/)
- "Godot Android Export Documentation" (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

Infinity Studios

VOIDCRAWL — Enter the unknown.

Explore deeper. Discover hidden treasures. Conquer the darkness.

An original mobile dungeon adventure in development.

---

## Current build status (developer notes)

**Implemented and covered by the headless test suite** (`godot --headless res://voidcrawl/tests/test_runner.tscn`): seeded dungeon generation with guaranteed reachable exit, combat, enemies, boss phases, loot and equipment stats, save/resume, tutorial and Crypt missions, menus.

**Download the debug APK:** GitHub **Actions → "Android Debug Build"** → latest successful run → artifact `voidcrawl-debug-apk`. Install by enabling "install unknown apps" for your browser/file manager and opening the APK. Signed release builds come from the manual **"Android Release (signed)"** workflow and need the `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD` repository secrets.

**Not yet verified on a real phone:** touch feel, frame rate (target 30 FPS, unmeasured), thermals, audio on device. The code under `scenes/`, `addons/` and `scripts/` is the unused MIT template (see ATTRIBUTION.md) and is excluded from the APK.
