## Install

**Homebrew (recommended)**

```sh
brew install --cask rishikeshsreekumar/tap/wakeintosh
```

**Manual:** download `Wakeintosh-{{VERSION}}.dmg` below, open it and drag Wakeintosh to Applications.

The first time you open it, macOS may say it can't verify the app (it isn't notarized yet). Go to **System Settings → Privacy & Security → Open Anyway**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Wakeintosh.app
```

Needs macOS 13 or later. Runs natively on Apple Silicon and Intel.

## What's in it

- Keep your Mac awake from the menu bar, like `caffeinate -dimsu`
- Sleep timer (15 min to 8 hours, or custom) with a live countdown in the menu bar
- Allow Display to Sleep option
- Open at Login
- Stops keeping your Mac awake if the app quits or crashes
