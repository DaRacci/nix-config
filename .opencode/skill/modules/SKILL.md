---
name: modules
description: Create and modify NixOS and Home-Manager modules
---

# Modules

## Module Structure

Standard module pattern:

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

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on.";
    };
  };

  config = mkIf cfg.enable {
    # Configuration applied when enabled
  };
}
```

## Creating a NixOS Module

1. Create file at `modules/nixos/<category>/<name>.nix`

2. Define options and config:
   ```nix
   {
     config,
     lib,
     pkgs,
     ...
   }:
   let
     cfg = config.services.myService;
   in
   {
     options.services.myService = {
       enable = lib.mkEnableOption "my service";
     };

     config = lib.mkIf cfg.enable {
       systemd.services.my-service = {
         wantedBy = [ "multi-user.target" ];
         serviceConfig.ExecStart = "${pkgs.myPackage}/bin/my-service";
       };
     };
   }
   ```

3. Register in parent `default.nix`:
   ```nix
   # modules/nixos/services/default.nix
   _: {
     imports = [
       ./existing-service.nix
       ./my-service.nix  # Add this
     ];
   }
   ```

4. Enable in host config:
   ```nix
   # hosts/server/myhost/default.nix
   { services.myService.enable = true; }
   ```

## Creating a Home-Manager Module

1. Create file at `modules/home-manager/<category>/<name>.nix`

2. Define with optional osConfig access:
   ```nix
   {
     osConfig ? null,
     config,
     lib,
     pkgs,
     ...
   }:
   let
     cfg = config.purpose.myFeature;
   in
   {
     options.purpose.myFeature = {
       enable = lib.mkEnableOption "my feature";
     };

     config = lib.mkIf cfg.enable {
       home.packages = [ pkgs.myPackage ];
     };
   }
   ```

3. Register in parent `default.nix`

4. Enable in user config:
   ```nix
   # home/<user>/hm-config.nix
   { purpose.myFeature.enable = true; }
   ```

## Common Namespaces

| Namespace | Module Type | Purpose |
|-----------|-------------|---------|
| `services.<name>` | NixOS | System services |
| `hardware.<name>` | NixOS | Hardware configuration |
| `boot.<name>` | NixOS | Boot configuration |
| `host.<name>` | NixOS | Host-specific options |
| `server.<name>` | NixOS | Server cluster options |
| `purpose.<category>` | Home-Manager | Use-case modules |
| `custom.<name>` | Home-Manager | Custom extensions |
| `user.<name>` | Home-Manager | User-specific options |

## Directory Index Patterns

### Export as attribute set (top-level)

```nix
# modules/nixos/default.nix
{
  boot = import ./boot;
  hardware = import ./hardware;
  services = import ./services;
}
```

### Import list (subdirectories)

```nix
# modules/nixos/services/default.nix
_: {
  imports = [
    ./service-a.nix
    ./service-b.nix
  ];
}
```

## Modifying Existing Modules

1. Find the module using project-structure skill
2. Understand existing options with `nix eval`
3. Add new options or extend config
4. Test affected configurations
5. Run `nix fmt` on changed files
