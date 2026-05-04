---
name: vhs
description: Create terminal screenshots and GIFs with VHS tape files. Use when automating terminal recordings, capturing TUI screenshots, or generating demo GIFs.
---

# VHS

Terminal recorder from Charm. Makes GIFs, PNGs, MP4s, or WebMs from scripted terminal actions.

## Run

```bash
nix run nixpkgs#vhs -- <file>.tape
```

## Tape File Syntax

```tape
Output output.gif           # or .png, .mp4, .webm

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"

Hide                        # Hide commands from output
Type "echo hello"
Enter
Sleep 1s
Show                        # Show commands again

Screenshot output.png       # Capture current frame
```

## Commands

| Command                           | Description       |
| --------------------------------- | ----------------- |
| `Type "text"`                     | Type text         |
| `Enter`, `Tab`, `Escape`, `Space` | Press key         |
| `Ctrl+x`, `Alt+x`                 | Key combo         |
| `Up`, `Down`, `Left`, `Right`     | Arrow keys        |
| `Sleep 1s`                        | Wait (`ms`, `s`)  |
| `Screenshot file.png`             | Capture frame     |
| `Hide` / `Show`                   | Toggle visibility |

## Settings

| Setting                        | Example            |
| ------------------------------ | ------------------ |
| `Set Shell "bash"`             | Shell to use       |
| `Set FontSize 14`              | Font size          |
| `Set Width 1200`               | Terminal width     |
| `Set Height 600`               | Terminal height    |
| `Set Theme "Catppuccin Mocha"` | Color theme        |
| `Set Padding 20`               | Window padding     |
| `Set WindowBar Colorful`       | Window decorations |

## Example: TUI Screenshot

```tape
Output screenshots/demo.png

Set Shell "bash"
Set FontSize 14
Set Width 1400
Set Height 800
Set Theme "Catppuccin Mocha"

Hide
Type "cd /path/to/project && my-tui-app"
Enter
Sleep 2s
Show

Ctrl+p
Sleep 1s
Screenshot screenshots/demo.png

Escape
Type "q"
Enter
```

## Tips

- Use tape files for repeatable terminal demos
- Use `Hide` when command text should stay out of output
- Use `Sleep` to give TUIs time to render
- Use `Screenshot` for still images
- Use GIF or video output for motion demos

## List Themes

```bash
nix run nixpkgs#vhs -- themes
```
