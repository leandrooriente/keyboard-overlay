# Keyboard Overlay

A native macOS overlay for a three-layer ZSA Moonlander layout, opened with a Raycast shortcut. The keys, labels, colors, and split keyboard geometry are rendered from editable data. No screenshots are used in the app. The included layout is a personal Moonlander configuration; you can customize its labels and layers in JSON.

Raycast handles the global shortcut through [Script Commands](https://github.com/raycast/script-commands). A small SwiftUI app draws the floating keyboard: Raycast's [native extension UI](https://developers.raycast.com/api-reference/user-interface) provides List, Grid, Detail, and Form components, which do not expose the freeform layout needed for a staggered split keyboard.

## Set up with Raycast

### 1. Install the prerequisites

- macOS 14 or later.
- [Raycast](https://www.raycast.com/).
- Git and Apple's **Swift 6.0 or later** toolchain. Install the Command Line Tools with `xcode-select --install` if needed, or use Xcode 16 or later. Check the active toolchain with `swift --version`.

### 2. Clone and install

Choose a permanent location for the repository, then run:

```sh
git clone https://github.com/leandrooriente/keyboard-overlay.git
cd keyboard-overlay
./scripts/install.sh
```

This builds the app locally, installs it at `~/Applications/Keyboard Overlay.app`, and registers the `keyboard-overlay://` URL scheme. You do not need a paid Apple Developer account.

### 3. Add the Raycast commands

1. Open **Raycast Settings → Extensions**, click **+ → Add Script Directory**, and choose this repository's `raycast` folder.
2. Find **Show Keyboard Overlay**, click its **Hotkey** field, and assign your preferred global shortcut, such as **⌃⌥⌘K**.
3. Optionally assign separate shortcuts to **Show Base Layer**, **Show Symbols Layer**, and **Show Numbers Layer**.

| Raycast command | Opens |
| --- | --- |
| Show Keyboard Overlay | The last selected layer |
| Show Base Layer | Layer 0: Base |
| Show Symbols Layer | Layer 1: Symbols |
| Show Numbers Layer | Layer 2: Numbers |

Run a command from Raycast search or press its assigned shortcut to show the overlay. To check installation directly from Terminal, run `./raycast/show-keyboard.sh` from the repository.

Keep the repository in place: Raycast runs the scripts from this folder, and those scripts call `scripts/launch.sh`. If you move the repository, remove the old Script Directory in Raycast and add the new `raycast` folder. The scripts also work through symlinks if you keep your Raycast commands in another folder. Setup leaves existing Raycast shortcuts and settings unchanged.

## Controls

| Input | Action |
| --- | --- |
| Click a layer tab | Select that layer |
| Run a per-layer Raycast command | Select Base, Symbols, or Numbers |
| `Esc` | Dismiss the overlay |
| `⌘R` | Reload layout data |
| `⌘Q` | Quit the app |

Layer selection is manual: click a tab or run a per-layer Raycast command. Ordinary typing leaves the displayed layer unchanged, and reopening the overlay preserves your selected layer. The layer shown is a reference view; selecting it does not change your keyboard's firmware layer. The bundled key labels include the inherited keys visible in Symbols and Numbers.

## Edit the layout

For changes without rebuilding, copy the bundled layout to your user configuration:

```sh
mkdir -p ~/.config/keyboard-overlay
cp Resources/moonlander.json ~/.config/keyboard-overlay/layout.json
```

Edit `~/.config/keyboard-overlay/layout.json`, then reopen the overlay or press `⌘R`. The app reloads this file each time it opens. Remove it to return to the bundled layout.

The default layout lives in `Resources/moonlander.json`; after changing that file, run `./scripts/install.sh` again. The JSON holds the static layout and layer overrides separately from the renderer. A future Oryx fetch can supply this data without replacing the UI.

Keys can include an optional `shifted` string, shown in the keycap's top-left corner while the main `label` stays centered:

```json
"L0-1": { "label": "1", "kind": "standard", "shifted": "!" }
```

The bundled number and punctuation legends use the US Shift mapping. Customize each `shifted` value to match your macOS input source. Letters, dedicated `(` and `)` keys, and numpad keys have no Shift legend. A missing key in another layer inherits the entire base legend, including `shifted`; an explicit layer override replaces the entire legend, so add `shifted` there only when that layer needs it.

## Development

```sh
# Run the layout and URL-routing tests.
swift test

# Build an app bundle in dist/.
./scripts/build.sh

# Show a particular layer, including while the app is already running.
./scripts/launch.sh 1

# Or run the executable directly.
swift run KeyboardOverlay --layer 2

# Render a preview without opening the overlay.
.build/release/KeyboardOverlay --render-preview /tmp/keyboard-overlay.png --layer 0
```

Deep links use zero-based layer IDs: `keyboard-overlay://show?layer=0`, `keyboard-overlay://show?layer=1`, and `keyboard-overlay://show?layer=2`. `keyboard-overlay://show` opens the overlay without requesting a specific layer. The Raycast commands send these URLs to the installed app, falling back to the local build in `dist`.

After changing app code or bundled data, quit the running app before reopening an updated build. Local builds are signed ad hoc for use on your Mac; distributing the app to other Macs would need Developer ID signing and notarization.

## Update

With the overlay open, press `⌘Q` to quit it. Then, from the repository:

```sh
git pull --ff-only
./scripts/install.sh
```

Your Raycast hotkeys and `~/.config/keyboard-overlay/layout.json` are preserved.

## Troubleshooting

- **Build fails with a Swift tools version error:** run `swift --version` and install or select a Swift 6.0+ toolchain. If using Xcode, select it in **Xcode Settings → Locations → Command Line Tools**.
- **Commands are missing from Raycast:** check that the registered Script Directory is the repository's `raycast` folder, not the repository root. If scripts lost their executable permissions, run `chmod +x raycast/*.sh scripts/*.sh` and reopen Raycast Settings.
- **The command asks you to install first:** run `./scripts/install.sh` from the repository. To test launching independently of Raycast, run `./raycast/show-keyboard.sh`.
- **An update still shows the old app:** quit the overlay with `⌘Q`, install again, and run the Raycast command.
- **The app reports a layout error:** check your custom `~/.config/keyboard-overlay/layout.json`. Move it aside to return to the bundled layout, then reopen the overlay.
