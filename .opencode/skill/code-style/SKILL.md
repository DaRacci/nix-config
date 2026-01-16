---
name: code-style
description: Write Nix code following repository conventions
---

# Code Style

## Critical Requirement

**MUST** run `nix fmt <paths...>` after making any changes to ensure consistent formatting.

## Indentation

- Use 2 spaces for indentation
- No tabs allowed

## Naming Conventions

| Context | Convention | Example |
|---------|------------|---------|
| Files and directories | kebab-case | `my-module.nix`, `home-manager/` |
| Nix attributes | camelCase | `myOption`, `enableFeature` |
| Option paths | camelCase | `services.myService.enable` |

## Comments

- Minimal comments preferred
- Code should be self-explanatory
- Use comments to explain *why*, not *what*

```nix
# Good: explains why
# Workaround for upstream bug #1234
extraConfig = "...";

# Bad: describes what (obvious from code)
# Set extraConfig to the value
extraConfig = "...";
```

## Imports

- Prefer relative imports: `./modules/foo.nix`
- Group imports at the top of the file
- Use list format for multiple imports:

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

When generating JSON, YAML, or other structured formats, define as Nix attribute sets and convert:

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
