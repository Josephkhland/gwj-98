# gwj-98

## Project structure

```text
.
├── addons/
├── assets/
├── autoload/
├── components/
│   ├── ui/
│   └── modules/
├── definitions/
├── docs/
├── levels/
└── resources/
```

### What goes where

- **`addons/`** — Godot add-ons and plugins used by the project.
- **`assets/`** — Original, source-organized files used to make the game: fonts, images, sounds, and similar assets.
- **`autoload/`** — Scripts and scenes configured as Godot autoloads (singletons).
- **`components/`** — Reusable parts of the game, organized by purpose:
  - **`components/ui/`** — Reusable UI components. Give each component its own subfolder containing its scene, scripts, and `.tres` resources.
  - **`components/modules/`** — Reusable non-UI components. Give each module its own subfolder.
- **`definitions/`** — Definitions describing the project's resources.
- **`docs/`** — Design documents and code documentation.
- **`levels/`** — Scenes that a LevelManager loads into the scene tree as game levels.
- **`resources/`** — The resource database, organized into a subfolder for each resource type.
