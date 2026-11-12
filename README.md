# Teams Backgrounds

[![Buy me a coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=russcollis&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff)](https://www.buymeacoffee.com/russcollis)

A macOS app that turns a set of images into a deployable package of custom Microsoft Teams backgrounds. It converts and renames the images to the format Teams expects, builds the folder structure, and produces a **Folder**, **DMG** or **PKG** containing an install script that copies the backgrounds into Teams and restarts Teams so they show up.

It's based on the approach described in [Deploying Custom Backgrounds to New Microsoft Teams on macOS](https://www.oddsandendpoints.co.uk/posts/macos-teams-new-backgrounds/).

## Requirements

- macOS 27.2 or later
- Xcode 27 or later (to build)
- Microsoft Teams (new and/or classic) on the target Macs

## Building

From the repository root:

```bash
./build.sh                 # Release build -> build/Teams Backgrounds.app
./build.sh --zip           # Also create build/Teams Backgrounds.zip
./build.sh --clean --zip   # Clean first, then build and zip
./build.sh --debug         # Debug build
```

You can also open `Untitled Project.xcodeproj` in Xcode and run the **MyApp** scheme.

The app is not sandboxed because it runs `hdiutil`, `pkgbuild` and `xattr` to build disk images and installer packages.

## Using the app

1. Drag images (or folders of images) into the window, or click **Add Images…**. Any format macOS can read is accepted (JPEG, HEIC, PNG, TIFF, …).
2. Pick the output format: **Folder**, **DMG** or **PKG**.
3. Choose the conversion options:
   - **Resize:** Fill (crop to 16:9), Fit (letterbox) or Keep original size
   - **Resolution:** 1920 × 1080, 2560 × 1440 or 3840 × 2160
4. Choose the Teams options:
   - **Install for:** New & Classic Teams, New Teams only, or Classic Teams only
   - **Restart Teams if running:** quits and reopens Teams so the new backgrounds load
   - **All local users when run as root:** otherwise only the logged-in user is updated
5. For a PKG, set the identifier, version and (optionally) a `Developer ID Installer` signing identity.
6. Click **Build**, then **Reveal** to show the result in Finder.

The app never overwrites an earlier build. If the name is already taken it adds " 2", " 3" and so on.

## What gets generated

Each image is converted to PNG and renamed to a lowercase UUID, with a 280 × 158 thumbnail:

```
898ffbba-4997-4911-b2ab-b5d8ef4998d2.png
898ffbba-4997-4911-b2ab-b5d8ef4998d2_thumb.png
```

### Folder / DMG

```
<Package Name>/
├── Backgrounds/
│   ├── <uuid>.png
│   └── <uuid>_thumb.png
├── Install Teams Backgrounds.command
└── README.txt
```

Double-click `Install Teams Backgrounds.command` to install for the current user. `README.txt` lists each original file name and its new UUID name.

### PKG

The package installs its payload to a temporary location:

```
/private/tmp/TeamsBackgrounds/<Package Name>/
├── Backgrounds/
└── install-backgrounds.sh
```

The `postinstall` script then runs `install-backgrounds.sh` as root, which copies the images into each user's Teams folder, and **deletes the `/private/tmp` staging folder** afterwards. The images only end up in the Teams folders, not in two places on the drive. If the postinstall is interrupted, macOS clears `/private/tmp` on restart anyway.

Output is logged to `/var/log/TeamsBackgrounds.log`.

The PKG works with Intune, Jamf or any MDM that deploys flat packages.

## The install script

Teams folders it writes to:

| Client | Folder |
|---|---|
| New Teams | `~/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads` |
| Classic Teams | `~/Library/Application Support/Microsoft/Teams/Backgrounds/Uploads` |

Behavior:

- **Run as a user** (Folder/DMG): installs for that user only.
- **Run as root** (PKG/MDM): installs for every local user (UID 501 and above) or just the logged-in user, depending on the setting. Files are created as each user so they own them.
- **Restart:** if Teams is running for the logged-in user, it's quit cleanly and reopened. Teams only reads new backgrounds at launch. Turn this off if interrupting calls is a concern.
- **Re-running** is safe: file names are fixed at build time, so the same files are overwritten rather than duplicated.

You can also run the script by hand with a custom source folder:

```bash
./install-backgrounds.sh /path/to/Backgrounds
```

## Deployment notes

- **App container protection:** New Teams stores backgrounds in its app container. Recent macOS versions may block other processes from writing there. If the PKG can't copy the images when deployed through MDM, deploy a Privacy Preferences Policy Control (PPPC) profile, or upload `install-backgrounds.sh` as an Intune shell script that runs as the signed-in user.
- **Gatekeeper:** an unsigned `.command` file from a downloaded DMG may be blocked. Sign the PKG for wider distribution.
- **Package receipts:** because the PKG payload is deleted after installation, `pkgutil --files <identifier>` lists files that no longer exist. That's expected.

## Project layout

| File | Purpose |
|---|---|
| `MyApp/MyApp.swift` | App entry point and About panel |
| `MyApp/ContentView.swift` | User interface |
| `MyApp/PackagerModel.swift` | UI state, file pickers, build action |
| `MyApp/Models.swift` | Options, output formats and errors |
| `MyApp/ImageConverter.swift` | Image conversion, resizing and thumbnails (ImageIO / Core Graphics) |
| `MyApp/ScriptTemplates.swift` | Generated install script, PKG postinstall and README |
| `MyApp/PackageBuilder.swift` | Builds the Folder, DMG and PKG (`hdiutil`, `pkgbuild`) |
| `MyApp/Assets.xcassets/AppIcon.appiconset` | App icon (all macOS sizes) |
| `Scripts/make-icon.swift` | Regenerates the app icon images |
| `build.sh` | Command-line build script |
| `LICENSE` | MIT License |

## Regenerating the icon

The icon is drawn in code. After editing `Scripts/make-icon.swift`, regenerate every size with:

```bash
swiftc -o /tmp/make-icon Scripts/make-icon.swift
/tmp/make-icon MyApp/Assets.xcassets/AppIcon.appiconset
```

## License

Copyright © 2026 Russell Collis. Released under the [MIT License](LICENSE).
