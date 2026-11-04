## 12.1.10

- Add Organize Groups to Mythic Positions for raid leaders and assistants. Arrange groups 1-4 from the displayed assignments, following the saved formation, with missing-player handling and swaps for full groups.
- Label Buttons on Map as Experimental.
- Let enabling Preview Frames turn off Lock Frames, and enabling Lock Frames turn off preview.
- Show Mythic intermission wind warnings two seconds earlier and keep them visible two seconds longer.

## 12.1.9

- Keep Mythic spread markers on the same left/right side of the room when switching between Entrance and Exit. Lower-left assignments now become upper-left instead of upper-right.

## 12.1.8

- Add Buttons on Map to send NSRT macros by clicking room-map markers, using the same keybinds and Opposite macros setting as the separate panel.
- Disable Attach to Map while Buttons on Map is active, restoring the saved attachment preference when switched off. Apply mode and scale changes after combat to keep clicks aligned.
- Move map and wind-order scale sliders into their gear menus, add hover help, and allow dragging Configuration beyond the screen edges.
- Always receive NSRT raid messages and grey out dependent macro controls when macro buttons are disabled.
- Turn off Preview Frames while frames are locked, and enable its toggle again when unlocked.
- Update new settings to show Mythic spread positions, hide boss landmarks, wind selection buttons, and macro buttons, and use 75% frame opacity with 40-pixel warning text. Preserve existing saved preferences.

## 12.1.7

- Add Mythic Positions with fourteen damage spots, two tank soaks, and four reserved healer positions. Damage spots use numbers 1-14, with 14 marked FURY BAIT; tank and healer spots use role icons.
- Assign unassigned raid members by role using movable circles and class-colored short names. Save full Name-Realm identities and separate position profiles; opening the tab takes one out-of-combat roster snapshot and leaves absent players' spots empty for replacement.
- Use the saved raid arrangement as the default layout while preserving existing custom positions and assignments.
- Let the raid leader publish complete or partly assigned plans before combat, including in Test Mode. Confirm receipt from other addon users, retry temporary messaging throttles, and preserve unsaved edits when a new plan arrives.
- Add a room floor or outline, separate floor opacity, an outlined green assignment dot, and optional assignment labels and boss portrait. Move the entrance and exit markers outward for better visibility.
- Add a Room Mini Map gear for display settings, including the clear button and wind order buttons. Hiding wind buttons preserves existing selections.
- Alternate the boss and assigned point between Entrance and Exit with each scheduled Fury countdown, with manual overrides and a configurable starting side. Floor markers stay fixed; Test Mode previews both sides and Reset restores the starting side.
- Add an editable five-second Fury stack countdown with optional synchronized voice cues. Show Stack in X and Stack now; short audio clips avoid speech-queue delays and stop on Reset, Quit, or encounter end.

## 12.1.6

- Replace Double Row with a Rows dropdown for single, paired, or room-position layouts, preserving existing row settings.
- Arrange three rows by relative room position, with optional Exit at the top right and Entrance at the middle right.
- Add optional room keybinds to Marker Layout. Right-click a label beneath a marker to assign a key, including modifiers, middle/side mouse buttons, and mouse wheel.
- Reject occupied keys with a warning and skip saved keys that later conflict, protecting existing WoW and other addon bindings.
- Clear individual binds or all Sszorak Helper binds without changing any others. Disabling preserves assignments and releases the keys while inactive.

## 12.1.5

- Move Marker Layout to its own sidebar page with layout profiles, Publish Layout, and Reset Layout.
- Add a room background with clickable markers positioned over the room floor.
- Add an Opposite macros toggle that sends the marker across the room, supports custom and temporary layouts, and shows an active-mode notice. Turn it off to restore normal macros.
- Add Show Entrance / Exit: Exit and Entrance fill slots 7 and 8 in a single row, or the last column with Exit above Entrance in Double Row. Changes during combat apply after combat ends.
- Move the compact Create button beside the NSRT enable toggle and show it only when enabled. It creates or repairs macros and restores normal marker behavior.
- Make hover help easier to read with wrapped text, headings, examples, and reset instructions.
- Fix the layout profile dropdown arrow and remove extra sidebar and header text.

## 12.1.4

- Added an optional Double Row layout for NSRT macros, with opposite markers aligned vertically.
- Removed macro status text for a more compact frame.
- Improved detached macro-frame positioning and preview visibility.
- Fixed the room map failing to show when NSRT buttons are disabled.
- Configuration header and close button now stay visible while scrolling.
- Removed the unsupported mini map rotation feature.

## 12.1.2

- Add a dedicated NSRT Macro Buttons section with macro creation and an Attach to Map option. Detached panels save their own position.
- Add optional automatic macro-panel visibility: show at Altar of the Six Winds, hide at The Serpent Warren or Pit of Fangs. Changes wait until combat ends.
- Add movable Surge Targets bars with player names, drop markers, ten-second countdowns, previews, and animated test controls.
- Make 100% map and order scale match the previous 75% size, including the attached NSRT macro panel.
- Default frame background opacity to 50%, preserving existing saved choices.
- Add a Personal Warning Delay slider for 1-10 second display durations (4 seconds by default).
- Add editable fight schedules for each difficulty, including Surge casts, intermissions, wind prompts, and resets. Raid Finder uses Normal defaults; newly observed events are saved. Changes apply next pull.

## 12.1.1

- Share wind orders through manually clicked NSRT raid macros, with support for displaying restricted raid messages in Midnight.
- Replace automatic combat assignment synchronization with local wind selections. Older versions cannot synchronize assignments with this release.
- Show only the six side macros in a panel aligned with the room map, with click suggestions for markers 1-3.
- Add `/sh macros` and a minimap right-click shortcut to toggle the macro panel before combat; visibility changes requested during combat wait until combat ends.
- Add movable personal Surge and push warnings with Preview Frames, Lock Frames, saved positions, and adjustable font size.
- Open test controls directly with `/sh test`, and support testing received raid messages with other players.
- Restrict layout publishing to outside encounters and chat lockdown, and report failed sends accurately.

## 12.1.0

Initial Sszorak Helper Addon
