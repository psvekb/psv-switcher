# PSV Switcher

macOS menu-bar daemon that works like Punto Switcher: it watches your typing and, on **Caps Lock**, converts the last typed word (or the current selection) between Russian and English layouts. Caps Lock itself is suppressed — no Caps Lock mode, only layout switching and word conversion.

## Features

- Global keyboard event tap (requires Accessibility permission)
- Converts last typed word RU ↔ EN (ЙЦУКЕН ↔ QWERTY)
- Converts selected text via Accessibility API (+ clipboard fallback)
- Switches input source (RU ↔ EN) automatically
- Menu-bar icon with enable/disable and quit
- Auto-start via LaunchAgent

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permission

## Build & Install

```bash
git clone git@github.com:psvekb/psv-switcher.git
cd psv-switcher
./install.sh
```

`install.sh` builds the release `.app`, copies it to `~/Applications/PSVSwitcher.app`, and registers a LaunchAgent for auto-start.

## Grant Accessibility

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click **+**, choose `~/Applications/PSVSwitcher.app` (or its binary `Contents/MacOS/PSVSwitcher`), enable the toggle
3. The daemon retries automatically every 2 seconds; once granted, the tap is created

## Usage

- Type a word in the wrong layout (e.g. `ghbdtn`) → press **Caps Lock** → becomes `привет`, layout switches
- Type a word followed by a space → Caps Lock converts the word before the space
- Select text → Caps Lock → selected text is converted
- Click the **PS** icon in the menu bar to enable/disable or quit

## Notes

- Caps Lock is suppressed (no uppercase mode); only layout switching + conversion happens
- Ad-hoc signing means Accessibility permission may need to be re-granted after a rebuild
- Not tested with all input methods; standard Russian/English keyboard layouts assumed

## License

MIT