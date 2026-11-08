---
name: code-style-nix
description: Write Nix code using repo conventions
---

# Code Style

## Indentation

- Use 2 spaces
- No tabs

## Naming Conventions

| Context | Convention | Example |
| --------------------- | ---------- | -------------------------------- |
| Files | Match adjacent files; kebab-case for packages and scripts, camelCase for lib helpers | `new-host.nix`, `mkSystem.nix` |
| Directories | kebab-case | `home-manager/` |
| Nix attributes | camelCase | `myOption`, `enableFeature` |
| Option paths | camelCase | `services.myService.enable` |

## Comments

- Keep comments minimal
- Let code explain itself
- Use comments for _why_, not _what_

```nix
# Good: explains why
# Workaround for upstream bug #1234
extraConfig = "...";

# Bad: repeats obvious code
# Set extraConfig to value
extraConfig = "...";
```

## Imports

- Use relative imports within a directory: `./hardware.nix`
- Use `${self}/...` for cross-tree references
- Group imports at top
- Use list form for multiple imports:

```nix
{
  imports = [
    ./hardware.nix
    ./services.nix
    ./networking.nix
  ];
}
```

## Structured Data

When generating JSON, YAML, or other structured formats, define data as Nix attr sets first, then convert:

```nix
# Good: define as Nix, convert to JSON
environment.etc."config.json".text = builtins.toJSON {
  setting = "value";
  nested = { key = 123; };
};

# Avoid: inline JSON strings
environment.etc."config.json".text = ''
  {"setting": "value", "nested": {"key": 123}}
'';
```

## Common Patterns

### Module Structure

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.services.myService;
in
{
  options.services.myService = {
    enable = mkEnableOption "my service";
  };

  config = mkIf cfg.enable {
    # configuration here
  };
}
```

### Let Bindings

```nix
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.myModule;
in
{
  # use cfg, mkIf, etc.
}
```
