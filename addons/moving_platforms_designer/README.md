# Reusable moving platform (Godot 4)

This standalone sibling of addons/charged_platformer has no character dependency. Copy this folder at addons/moving_platform, or update its three script/scene references when relocating it.

## Designer setup

Instance MovingPlatform.tscn. Select its root and assign Texture in the Inspector; no Editable Children setting is needed for artwork. Changes preview immediately in the level editor and are saved per instance. Enable Moving Platform Designer under Project Settings > Plugins. Selecting a platform shows Edit Path, Edit Collision and Select Platform in the 2D toolbar. No additional level nodes or manual Editable Children setup is needed.

1. Select the platform and click Edit Path in the 2D toolbar. Draw/edit the built-in route using Godot's native path tools. Add/move points and drag tangent handles for curves; the platform preview follows edits immediately. Click Select Platform to return to the root settings.
2. Select the MovingPlatform root and assign Texture. The supplied gradient is only a placeholder; clearing Texture hides the artwork while keeping physics. For advanced sprite offset, scale or region settings, edit Body/Sprite2D through Editable Children. Custom textures retain their original colors.
3. Click Edit Collision to select the existing CollisionShape2D. Choose its Shape in the Inspector or resize it using native viewport handles. Collision size remains independent of the sprite.
4. Set movement options on the MovingPlatform root.

Curve and collision resources are local to each instance. Avoid scaling the physics body; resize the collision shape instead. Keep root/path scale at 1 for speed to represent world pixels/second.

## Editor plugin

plugin.cfg and editor/platform_editor_plugin.gd provide the optional Moving Platform Designer plugin. It is enabled in this project; enable it under Project Settings > Plugins when copying the addon to another project.

Select one moving platform or one of its children to show the 2D toolbar:
- Edit Path selects its built-in MovementPath, or its assigned external route if one exists.
- Edit Collision selects Body/CollisionShape2D for native shape editing.
- Select Platform returns to the platform root and its texture/movement settings.

The plugin uses native Godot editors rather than custom geometry tools, retaining path tangent controls, collision handles and normal geometry undo/redo. On the first edit it automatically enables editable children for the relevant scene instance through an undoable action. This is an instance-editability flag saved in the level, not an added node. Non-local internal geometry resources are duplicated before editing; default curves/shapes already have per-instance resources. An explicitly assigned external route is edited as-is and may intentionally be shared.

Save the level to persist path and collision overrides. No nodes are created or reparented. The plugin can be disabled without changing runtime behavior; manual Editable Children remains available as a fallback. Detection also supports scripts inheriting from the moving-platform script.

Editor integration validation checked toolbar selection, internal editability, per-instance curve/shape isolation, and saving/reloading geometry overrides. Interactive mouse dragging should still be reviewed in your editor.

## Optional external paths

Movement Path is an exported Path2D node reference, saved as a node path relative to the platform instance. It uses the selected Path2D's world transform, so the route can be placed and rotated directly in the level. Moving the platform root does not offset an assigned external route: the path controls the body's location.

Keep the route outside Body (preferably a sibling of the platform) so it does not move with the carrier. Multiple platforms may share a route; use different Start Progress values to space them apart. Use independent Curve2D resources for independent routes.

Leaving Movement Path empty uses the built-in MovementPath child. Clearing an assignment restores that default; changing the assignment resets the body to Start Progress on the new route. If an external route is deleted during gameplay, movement stops safely. Demo.tscn uses built-in routes so the plugin workflow needs no additional path nodes.

## Movement options

- Travel Mode: PING_PONG reverses at each endpoint; WRAP disappears at the travel endpoint and reappears at the opposite end.
- Speed: path pixels travelled per second. Zero stops travel.
- Running: start enabled or paused; runtime changes pause/resume.
- Reversed: exported current direction. Enable to travel toward the start of the curve. Runtime changes reverse immediately without resetting position. Ping-pong endpoints update this flag automatically.
- Start Progress: initial path fraction, 0=start and 1=end. For a reversed WRAP route, usually start at 1.
- Disappear Duration: hidden interval for WRAP. A minimum of three physics callbacks is enforced even at zero to reset collision velocity safely.
- Orient To Path: optionally rotate sprite and collision body with the curve tangent; disabled by default.

In the editor, the body previews Start Progress; it does not continuously move. Changes to curve points update the preview. Empty/zero-length paths remain stationary and show an editor configuration warning.

## Script interface

Call on the MovingPlatform root:
- reverse_direction(): toggle current direction.
- set_reversed(bool): set direction explicitly.
- start() / stop(): resume/pause.
- get_progress(): current normalized path position.
- Set speed, travel_mode or reversed directly if preferred.

Signals: direction_changed(is_reversed), disappeared and reappeared. These can be wired through Godot's Signals panel to switches, triggers or other scripts. Demo.tscn demonstrates R reversing both platforms and Space pausing/resuming.

## Physics and riders

Body is an AnimatableBody2D; it moves in physics ticks with sync_to_physics=false. It uses collision layer 1 by default. Riders must scan that layer and update after the platform; the charged platformer character already uses physics priority 100.

WRAP removes Body from physics and hides it before teleporting, then restores physics after the hidden interval. It does not sweep through intervening geometry. Riders should drop when the platform disappears, rather than teleport with it. Native floor riders lose support; custom attachments must detect a carrier whose physics space has become invalid.

Animatable bodies are prescribed moving surfaces, not obstacle-avoiding actors. Design routes with sufficient clearance. A paused platform finishes an in-progress hidden reset, then waits. Changing Reversed during disappearance changes subsequent travel; the already selected reappearance endpoint remains unchanged.

## Files and checks

moving_platform.gd owns path travel and runtime controls. MovingPlatform.tscn contains the designer-editable route, sprite and collision shape. Demo.tscn/demo.gd show both travel modes. smoke_test.gd tests travel, reversing, endpoint reflection, wrap visibility and physics removal, pauses, degenerate paths and native floor carrying.

	Godot --headless --path . --script res://addons/moving_platform/smoke_test.gd

Godot references:
- https://docs.godotengine.org/en/stable/classes/class_curve2d.html
- https://docs.godotengine.org/en/4.1/classes/class_animatablebody2d.html
