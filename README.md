# Sszorak Helper

Sszorak Helper is a World of Warcraft Retail 12.1 raid addon for coordinating Sszorak wind directions, Venomous Surge drop locations, and Howling Maelstrom pushbacks.

Retail target: WoW `12.1.0` / interface `120100`.

## Features

- Shows a movable eight-position room map during enabled Sszorak encounters.
- Lets a designated caller identify incoming wind orders `1`, `2`, and `3` locally in any order.
- Prevents duplicate order or room selections on that player's map.
- Converts each incoming wind into its opposite Venomous Surge drop location.
- Uses the configured exit marker as drop `4` on every difficulty.
- Shares the display through manually clicked NSRT raid-chat macros during combat.
- Displays received raid messages directly, including secret values, without parsing them into assignments.
- Shows a separate movable four-marker drop-order frame.
- Shows an optional six-button NSRT macro panel for side markers only, with suggested click order 1-3.
- Displays personal Surge-pair and push-direction warnings with an adjustable font; local selections can also supply spoken marker names.
- Rotates the room map during the intermission with minimal runtime work.
- Supports up to ten account-wide marker-layout profiles plus positions, scales, background opacity, difficulty filters, and warning options.
- Offers raid-leader layout publishing with Reject, Temporary, and Save Profile responses.
- Includes a local Test Mode for configuring and exercising the UI in town.

## Commands and minimap button

```text
/sszorak
/sszorak config
/sszorak test
/sh
/sh config
/sh test
/sh macros
```

`/sszorak` and `/sh` open Configuration. The `test` subcommand toggles Test Mode. Left-clicking the draggable Sszorak minimap button also opens Configuration. Right-click it, or use `/sh macros`, to show/hide the macro panel before combat. The live panel starts hidden; enable it when preparing for Sszorak and hide it when leaving the room. Visibility changes requested during combat are applied after combat. Leaving the instance clears the live-panel toggle. Preview Frames and Test Mode also show the panel unless you explicitly hide it.

## Configuration

Frame Options use a two-column layout and include:

- Preview Frames and Lock Frames, including the Personal Warning frame.
- Room Mini Map and Wind Drop Order Frame visibility.
- Optional NSRT macro buttons with an out-of-combat macro creation and repair action.
- Independent map and order-frame scales from 50% to 200%.
- Shared, uniform frame-background opacity at 0%, 25%, 50%, 75%, or 100%.

Additional settings control the Clear button, NSRT macro buttons, TTS warnings, map rotation, personal Surge and push warnings, difficulty enablement, and the raid-marker layout. Warning Font ranges from 12 to 72 pixels and previews changes immediately. Receive NSRT Raid Messages enables the received-order display. Turn on Preview Frames and turn off Lock Frames to position the encounter UI, including the Personal Warning frame.

The Marker Layout editor keeps the built-in Default profile immutable. Press New to make an editable named copy of the displayed layout. Up to ten profiles, including Default, fit in a two-column grid; custom profiles can be renamed or deleted. An accepted temporary raid layout appears in pink and can be copied into a permanent profile with New. The NSRT macro panel shares the room-map scale and background opacity and stays anchored below the room map.

Test Mode shows the room map and a fake-event controller with Surge 1, Surge 2, Intermission, Reset, and Quit Test Mode actions. Wind assignments begin empty. In a raid, the macro-frame buttons execute the real NSRT macros and send raid chat; other players running Test Mode receive those messages through the same display path used in the encounter. Create or repair the macros on the sending character first, and enable Receive NSRT Raid Messages and Wind Drop Order Frame on receivers. Local wind selection is optional for testing macro clicks. Outside a raid, clicks simulate reception locally without requiring macros. Joining or leaving a raid updates the bindings out of combat. The fake Surge/Push controls can preview received markers; their timing is local to the character pressing the control. Reset clears only that character's selections and received slots. Quit Test Mode before pulling.

## Encounter workflow

1. Before pulling, the caller creates/repairs the macros in Configuration, quits Test Mode, and opens the macro panel with `/sh macros` or a minimap right-click.
2. At pull, that caller selects the three incoming winds on their room map. These selections are local; there is no combat coordinator or cross-player claim synchronization.
3. The caller's order frame shows the three opposite drop markers and the configured exit marker. Click the suggested macros `1`, `2`, then `3`, once each, with a pause between messages. The panel contains only the six side markers; Exit and Entrance have no buttons. Receivers use their configured Exit marker for drop 4 without a fourth click. Buttons remain clickable for manual retries. Clear receivers before repeating a three-message batch in the same phase.
4. Other SszorakHelper users with Receive NSRT Raid Messages enabled see the received order. NSRT users with Winds Helper enabled see the same raid messages. Received values are display-only: they do not select room-map positions or configure secure buttons. Completed local assignments take precedence over received values on that player's display.
5. Surge 1 uses drops 1 and 2; Surge 2 uses drops 3 and 4. Push prompts occur at Dig In, +8 seconds, and +18 seconds. All warnings are personal; marker-name TTS requires local selections because secret received values cannot be decoded into names.
6. The intermission rotation stops after 25 seconds and local selections/received slots reset 30 seconds after Dig In.

Live Surge warnings use readable Blizzard encounter-timeline countdowns and fire three seconds before each Surge. If the required event values are secret, that event is skipped without attempting arithmetic on them.

Only the six side slices can receive winds. The static room map and layout editor keep Exit at the top and Entrance at the bottom for planning. During the intermission, the rotating marker layer applies the physical 45-degree room offset before following the player's point of view.

## NorthernSkyRaidTools compatibility

NorthernSky's Sszorak macros are named `NSRT_SSZORAK_1` through `NSRT_SSZORAK_8` and contain `/raid 1` through `/raid 8`. Create NSRT Macros creates or repairs those eight account-wide macros so custom layouts can use any marker on a side. The panel binds only the six side markers before combat and explicitly executes on mouse-up, independently of the player's action-on-key-down setting. Changed or missing macro bodies are left unbound until repaired. No action-bar slots are needed.

The receiver follows NSRT's display-only approach: a public four-slot counter chooses where to pass each opaque raid-chat message to `FontString:SetFormattedText`. It never parses, compares, converts, or measures the received text. Every raid/raid-leader message consumes a slot; sender/content filtering is unavailable for secret values. Use a single caller and keep these channels clear of unrelated messages. Missing, extra, or throttled messages can misalign both receivers; click progress is explicitly unconfirmed. SszorakHelper's Clear button resets only its local receive counter. Align/reset receivers before re-entering a full batch.

Blizzard can block macro chat if raid members are outside the instance or if messages arrive too quickly. The addon cannot confirm or bypass those restrictions. The panel must be opened and its layout prepared before combat; movement, binding, and visibility changes wait until combat ends. There is no automatic room detection: the quick toggle is the supported way to keep the panel hidden elsewhere in the raid.

Private addon messages are retained only for raid-leader layout offers outside chat lockdown. Their API result is checked, and failed sends no longer report success. The old HELLO/PROPOSE/STATE/CLEAR/RESET combat protocol has been removed; older addon versions cannot synchronize live assignments with this version.

Implementation references: [Blizzard 12.1 chat API](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua), [chat result enums](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua), [secure action clicks](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua), [NSRT's Sszorak implementation](https://github.com/Reloe/NorthernSkyRaidTools/blob/main/NorthernSkyRaidTools/EncounterAlerts/MidnightS2/Sszorak.lua), and [Blizzard's macro chat restrictions](https://us.forums.blizzard.com/en/wow/t/macro-changes-now-live-target-markers-and-chat-messages/2261956).

## Validation

Run `lua tests/regression.lua` from the repository root with Lua 5.1 for offline checks of lockdown, failed sends, opaque received values, local planning, secure macro attributes, deferred visibility, and personal warnings. These use simulated APIs, so they cannot certify protected macro execution or delivery in WoW. In game, verify with two clients during Sszorak: all three clicked messages reach the receiving display, drop 4 shows the receiver's configured Exit marker, both action-on-key-down settings work, warnings remain personal, and a queued panel hide applies after combat. Check with the raid fully inside the instance and avoid rapid clicks.

## Repository layout

- `Core/`: saved settings, encounter state, communication, timing, and options loading.
- `UI/`: the room map, order frame, minimap button, shared widgets, and layout offer.
- `Options/`: source for the load-on-demand `SszorakHelper_Options` companion addon.
- `SszorakHelper.toc`: Retail addon manifest and release version.
- `.pkgmeta`: BigWigs packager layout and release exclusions.
- `build.ps1`: creates a Retail zip in `dist/` and uses the optional local verifier when available.

## Build

```powershell
.\build.ps1
```

The resulting archive contains sibling `SszorakHelper/` and `SszorakHelper_Options/` directories and only the files referenced by their TOCs.

## GitHub and CurseForge releases

Tags matching `v*` run the BigWigs packager workflow and create a GitHub release. To also publish on CurseForge:

1. Create the Sszorak Helper project on CurseForge and copy its numeric project ID.
2. Add `## X-Curse-Project-ID: <id>` to `SszorakHelper.toc`.
3. Add a repository Actions secret named `CF_API_KEY` containing a CurseForge API token.
4. Upload an initial file as a Release so CurseForge submits the project for moderation and lists it in the app. This can be a manual upload from `build.ps1`, or the first tagged release after the project ID and secret are configured.
5. Update `CHANGELOG.md` and the version in both TOCs and `SszorakHelper.lua`.
6. Commit the release and push a matching `v<version>` tag.

Local deployment, verification, architecture notes, and agent instructions are intentionally ignored and are not included in repository clones or release packages.
