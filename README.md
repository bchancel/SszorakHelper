# Sszorak Helper

Sszorak Helper is a World of Warcraft Retail 12.1 raid addon for coordinating Sszorak wind directions, Venomous Surge drop locations, and Howling Maelstrom pushbacks.

Retail target: WoW `12.1.0` / interface `120100`.

## Features

- Shows a movable eight-position room map during enabled Sszorak encounters.
- Lets any addon user identify incoming wind orders `1`, `2`, and `3` in any order.
- Privately synchronizes assignments and prevents duplicate order or room claims.
- Converts each incoming wind into its opposite Venomous Surge drop location.
- Uses the configured exit marker as drop `4` on every difficulty.
- Publishes completed four-marker orders in a NorthernSkyRaidTools-compatible format.
- Reads compatible numeric raid messages published by NorthernSky users.
- Shows a separate movable four-marker drop-order frame.
- Can warn for Surge pairs and Howling Maelstrom push directions.
- Rotates the room map during the intermission with minimal runtime work.
- Supports account-wide marker layouts, positions, scales, background opacity, difficulty filters, and warning options.
- Offers raid-leader layout publishing with Reject, Temporary, and Make Default responses.
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
- Independent map and order-frame scales from 50% to 200%.
- Shared frame-background opacity at 0%, 25%, 50%, 75%, or 100%.

Additional settings control the Clear button, map rotation, Surge and push warnings, difficulty enablement, and the raid-marker layout. Turn on Preview Frames and turn off Lock Frames to position the encounter UI.

Test Mode shows the room map and a fake-event controller with Surge 1, Surge 2, Intermission, Reset, and Quit Test Mode actions. Wind assignments still begin empty so the full selection and drop-order workflow can be tested. Test activity never sends raid chat, raid warnings, or addon traffic.

## Encounter workflow

1. At pull, addon users identify the three incoming winds using the numbered buttons around the room map.
2. A claimed order is synchronized and disabled for everyone else running Sszorak Helper.
3. After all three winds are known, the elected coordinator publishes the three opposite drop markers followed by the configured exit marker.
4. Surge 1 uses drops 1 and 2; Surge 2 uses drops 3 and 4.
5. During Howling Maelstrom, push prompts occur at Dig In, Dig In +8 seconds, and Dig In +18 seconds.
6. The intermission rotation stops after 25 seconds and assignments reset 30 seconds after Dig In.

Only the six side slices can receive winds. Exit and entrance remain configurable marker positions but never show wind-order buttons.

## NorthernSkyRaidTools compatibility

NorthernSky's Sszorak macros publish numeric marker IDs `1` through `8` in raid chat. Sszorak Helper sends the same numeric format in drop order and always publishes four messages so NorthernSky's four-slot counter remains aligned. Sszorak Helper users synchronize partial assignments privately before the completed order is published.

## Repository layout

- `Core/`: saved settings, encounter state, communication, timing, and options loading.
- `UI/`: the room map, order frame, minimap button, shared widgets, and layout offer.
- `Options/`: source for the load-on-demand `SszorakHelper_Options` companion addon.
- `SszorakHelper.toc`: Retail addon manifest and release version.
- `.pkgmeta`: BigWigs packager layout and release exclusions.
- `verify.ps1`: source, version, manifest, and metadata checks.
- `build.ps1`: creates a verified Retail zip in `dist/`.
- `update_and_push.ps1`: versions, commits, pushes, and optionally tags releases.

## Verify and build

```powershell
.\verify.ps1
.\build.ps1
```

The resulting archive contains sibling `SszorakHelper/` and `SszorakHelper_Options/` directories and only the files referenced by their TOCs.

## Local deployment

`deploy.ps1` is a local, ignored helper. Its default targets are:

```text
C:\games\World of Warcraft\_retail_\Interface\AddOns\SszorakHelper
C:\games\World of Warcraft\_retail_\Interface\AddOns\SszorakHelper_Options
```

Run it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Override the main addon target with `-TargetRoot` or the `SSZORAKHELPER_ADDON_DEPLOY_TARGET` environment variable. The options addon is deployed beside it.

## GitHub and CurseForge releases

Tags matching `v*` run the BigWigs packager workflow and create a GitHub release. To also publish on CurseForge:

1. Create the Sszorak Helper project on CurseForge and copy its numeric project ID.
2. Add `## X-Curse-Project-ID: <id>` to `SszorakHelper.toc`.
3. Add a repository Actions secret named `CF_API_KEY` containing a CurseForge API token.
4. Update `CHANGELOG.md`, then run `./update_and_push.ps1 -NewVersion <version> -Release`.

Use `-NoTag` when pushing ordinary source changes from `main` without creating a release.
