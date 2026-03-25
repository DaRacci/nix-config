# DIY & Making

This section documents the Home-Manager modules under `purpose.diy`, which provide tooling and configuration for hardware tinkering, 3D printing, and related maker activities.

______________________________________________________________________

## Printing

The printing module installs 3D-printing software and wires up persistent storage so that settings survive reboots on impermanence-based systems.

- **Entry point**: `modules/home-manager/purpose/diy/printing.nix`

### Options

#### `purpose.diy.printing.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `false` |

Enables 3D-printing support. Installs OrcaSlicer and LycheeSlicer and registers their configuration directories for persistence.

______________________________________________________________________

### Git Sync

The `gitSync` sub-module adds a long-running systemd user service that watches the OrcaSlicer profile directory and automatically creates a git commit every time a profile file is added, changed, or removed. This gives you a full revision history of your slicer settings with zero manual effort.

#### `purpose.diy.printing.gitSync.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `false` |

Enable the OrcaSlicer git auto-commit watcher. Requires `purpose.diy.printing.enable = true`.

#### `purpose.diy.printing.gitSync.repoPath`

| | |
|---|---|
| Type | `string` |
| Default | `"${config.home.homeDirectory}/.config/OrcaSlicer/user/default"` |

Absolute path to the directory that will be managed as a git repository. The directory is initialised automatically the first time the watcher service starts, so it does not need to exist at activation time.

The default points at the standard OrcaSlicer per-user profile directory, which contains the `filament/`, `process/`, and `machine/` sub-directories, so all profile types are tracked without any additional configuration.

______________________________________________________________________

### Commit Message Convention

Commit messages are generated automatically based on the type of filesystem event and the location of the file within the repository:

| Event | Commit message format |
|---|---|
| File added / created | `feat(<type>): added <name>` |
| File modified | `refactor(<type>): updated <name>` |
| File deleted | `chore(<type>): removed <name>` |

Where:

- **`<type>`** is the name of the first directory component under the repo root (e.g. `filament`, `process`, `machine`). Files placed directly at the root level use the fallback type `config`.
- **`<name>`** is the filename stripped of its extension (e.g. a file named `Prusament_PLA.json` yields the name `Prusament_PLA`).

**Examples:**

```
feat(filament): added Prusament_PLA
refactor(process): updated Standard_0.2mm_Quality
chore(machine): removed Prusa_MK4S
```

______________________________________________________________________

### How It Works

1. A systemd user service (`orca-slicer-git-sync.service`) is started at login and kept alive by systemd.
1. The service uses `inotifywait` (from `inotify-tools`) in one-shot mode inside a loop to detect any filesystem event under the repo path (excluding the `.git` directory).
1. After an event is received the watcher sleeps for **2 seconds** to debounce rapid bursts of writes (e.g. when OrcaSlicer rewrites multiple files at once).
1. All pending changes are then committed **one file at a time**, each with an individually crafted commit message.
1. If the watched directory does not yet exist (e.g. OrcaSlicer has never been run), the service polls every 10 seconds until it appears, then initialises the repository and starts watching.

______________________________________________________________________

### Usage Example

```nix
{ ... }: {
  purpose.diy.enable = true;

  purpose.diy.printing = {
    enable = true;

    gitSync = {
      enable = true;
      # Optional: use a custom path outside the OrcaSlicer config directory
      # repoPath = "/home/alice/slicer-profiles";
    };
  };
}
```

______________________________________________________________________

### Operational Notes

- The git repository is initialised with `git init` and an initial commit (`chore: initial commit`) the first time the service starts if no `.git` directory exists.
- The service is set to restart on failure (`Restart=on-failure`, `RestartSec=10`) so transient errors do not leave settings un-tracked.
- Because the watcher operates on the live OrcaSlicer profile directory, no separate mirroring or rsync step is needed.
