# Sszorak Helper

Sszorak Helper is a World of Warcraft Retail 12.1 raid addon for coordinating Sszorak wind directions, Venomous Surge drop locations, and Howling Maelstrom pushbacks.

Retail target: WoW `12.1.0` / interface `120100`.

## Features

- Shows a movable eight-position room map during enabled Sszorak encounters.
- Lets any addon user identify incoming wind orders `1`, `2`, and `3` in any order.
- Privately synchronizes assignments and prevents duplicate order or room claims.
- Converts each incoming wind into its opposite Venomous Surge drop location.
- Uses the configured exit marker as drop `4` on every difficulty.
- Uses only private addon messages for assignments during combat.
- Reads compatible numeric raid messages when WoW exposes their values to addons.
- Shows a separate movable four-marker drop-order frame.
- Shows an optional six-button NSRT macro panel below the room map in Test Mode and throughout The Venomous Abyss when the matching NSRT macros exist.
- Can display and speak Surge-pair and Howling Maelstrom push-direction warnings.
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
```

`/sszorak` and `/sh` open Configuration. The `test` subcommand toggles Test Mode. Left-clicking the draggable Sszorak minimap button also opens Configuration.

## Configuration

Frame Options use a two-column layout and include:

- Preview Frames and Lock Frames.
- Room Mini Map and Wind Drop Order Frame visibility.
- Optional NSRT macro buttons with an out-of-combat macro creation and repair action.
- Independent map and order-frame scales from 50% to 200%.
- Shared, uniform frame-background opacity at 0%, 25%, 50%, 75%, or 100%.

Additional settings control the Clear button, NSRT macro buttons, TTS warnings, map rotation, Surge and push warnings, difficulty enablement, and the raid-marker layout. Turn on Preview Frames and turn off Lock Frames to position the encounter UI.

The Marker Layout editor keeps the built-in Default profile immutable. Press New to make an editable named copy of the displayed layout. Up to ten profiles, including Default, fit in a two-column grid; custom profiles can be renamed or deleted. An accepted temporary raid layout appears in pink and can be copied into a permanent profile with New. The NSRT macro panel shares the room-map scale and background opacity and stays anchored below the room map.

Test Mode shows the room map and a fake-event controller with Surge 1, Surge 2, Intermission, Reset, and Quit Test Mode actions. Wind assignments still begin empty so the full selection and drop-order workflow can be tested. Test activity never sends raid chat, raid warnings, or addon traffic; when text-to-speech is enabled, fake warnings are spoken locally.

## Encounter workflow

1. At pull, addon users identify the three incoming winds using the numbered buttons around the room map.
2. A claimed order is synchronized and disabled for everyone else running Sszorak Helper.
3. After all three winds are known, Sszorak Helper users receive the three opposite drop markers followed by the configured exit marker in the order frame.
   The room map badges the three opposite slices `1` through `3`; the NSRT macro panel highlights and unlocks the matching secure macros one at a time.
4. Surge 1 uses drops 1 and 2; Surge 2 uses drops 3 and 4.
5. During Howling Maelstrom, push prompts occur at Dig In, Dig In +8 seconds, and Dig In +18 seconds, using the same opposite destination markers shown for the drops.

Live Surge warnings use Blizzard's encounter-timeline countdowns and fire three seconds before each Surge. The helper recognizes both the spell name and Sszorak's difficulty-specific timeline durations, so the warning does not depend on BigWigs or DBM being installed.
6. The intermission rotation stops after 25 seconds and assignments reset 30 seconds after Dig In.

Only the six side slices can receive winds. The static room map and layout editor keep Exit at the top and Entrance at the bottom for planning. During the intermission, the rotating marker layer applies the physical 45-degree room offset before following the player's point of view.

## NorthernSkyRaidTools compatibility

NorthernSky's Sszorak macros are named `NSRT_SSZORAK_1` through `NSRT_SSZORAK_8` and publish numeric marker IDs in raid chat. When NSRT Macro Buttons are enabled, Create NSRT Macros creates or repairs those eight account-wide macros with NorthernSky's matching icons and `/raid 1` through `/raid 8` bodies. Retail 12.1 protects addon-generated chat during combat and exposes received encounter chat as secret values, so Sszorak Helper cannot safely publish or parse those messages itself. Instead, the secure NSRT panel binds the six macros used by the current side-slice layout before combat. Once assignments are complete, press the highlighted buttons `1` through `3`; only the required next button accepts a click. Test Mode exercises the same progression without sending raid chat.

Because protected buttons cannot be created, rebound, moved, shown, or hidden after combat starts, the NSRT panel is prepared out of combat and remains available while inside The Venomous Abyss. Layout changes made during combat are applied to its secure bindings after combat ends.

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
