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

2. Define with optional `osConfig` access:

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

| Namespace            | Module Type        | Purpose                               |
| -------------------- | ------------------ | ------------------------------------- |
| `services.<name>`    | NixOS              | System services                       |
| `hardware.<name>`    | NixOS              | Hardware configuration                |
| `boot.<name>`        | NixOS              | Boot configuration                    |
| `host.<name>`        | NixOS              | Host-specific options                 |
| `server.<name>`      | NixOS              | Server cluster options                |
| `core.<name>`        | Home-Manager/NixOS | Opinionated configurations & features |
| `purpose.<category>` | Home-Manager       | Use-case modules                      |
| `user.<name>`        | Home-Manager       | User-specific options                 |

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

1. Find module with `project-structure` skill
2. Understand existing options with `nix eval`
3. Add new options or extend config
4. Test affected configs
5. Run `nix fmt` on changed files

## Extending Submodules Declared in Other Modules

**When you need to add new options to a submodule defined in another module** —
without modifying the original file.

### The Pattern: Declare the same option path

NixOS's module system merges `attrsOf (submodule ...)` declarations from
multiple modules. Two modules declaring the same `options.` path with
compatible `submodule` types will have their inner `options` attrsets
**merged additively**.

```nix
# Module A: core/options.nix — defines the submodule
options.server.proxy.virtualHosts = mkOption {
  type = attrsOf (submodule ({ name, ... }: {
    options = {
      port = mkOption { type = port; description = "Backend port."; };
      extraConfig = mkOption { type = str; default = ""; };
    };
  }));
};

# Module B: extensions/kanidm.nix — injects new options WITHOUT touching A
options.server.proxy.virtualHosts = mkOption {
  type = attrsOf (submodule ({ name, ... }: {
    options.kanidm = mkOption {
      type = nullOr (submodule { ... });
      default = null;
    };
  }));
};
```

After merge, every virtualHost entry has `port`, `extraConfig`, AND `kanidm`.

### Why not `imports` in the submodule?

A common intuition is to have each extension set a `vhostModule` field and
have the submodule collect them in its `imports`:

```nix
# Fails: circular dependency
submodule ({ config, ... }: {
  imports =
    config.extensions
    |> builtins.attrValues
    |> map (ext: ext.vhostModule);
})
```

This creates **infinite recursion** — reading `config` inside `imports`
means the submodule type depends on config values that haven't been resolved.
Nix detects this and throws `"infinite recursion: you probably reference
config in imports"`.

### When direct `options` merge works vs. `imports`

| Approach | Works? | Use when |
|----------|--------|----------|
| Declare same `options.` path with `attrsOf (submodule ...)` | ✅ Yes | Adding new options to existing submodule entries |
| Dynamic `imports` in submodule reading `config` | ❌ No | Circular — config needs submodule type, import needs config |
| Static `imports` in submodule (no `config` access) | ✅ Yes | Importing known modules, no conditional logic |
| Wrap the whole `config` in `mkIf` inside imported submodule | ✅ Yes | Conditional config generation (but options always declared) |

### Key rules

- **Both declarations must use the same outer wrapper** — both `attrsOf (submodule ...)`, not one `str` and one `submodule`.
- **Options declared this way are always present** on the submodule — they
  can't be gated by `enable`. Use `mkIf` in `config` to control behavior.
- **Works for `submodule` and `submoduleWith`** — the inner `options`
  attrsets union at type-resolution time, before config evaluation.
- **Used by nixpkgs internally** — `systemd.services`, `nginx.virtualHosts`,
  and others compose submodule options from multiple modules.

### Read our real usage

See the proxy extension registry for a complete example:
- `modules/nixos/server/proxy/options.nix` — declares core vhost submodule
- `modules/nixos/server/proxy/extensions/kanidm.nix` — injects `kanidm` option + owns all kanidm logic (auth, globalConfig, provisioning)
- `modules/nixos/server/proxy/extensions/dashboard.nix` — no vhost options needed
- `modules/nixos/server/proxy/extensions/cloudflared.nix` — no vhost options needed

## Device-gated options (server-only config in shared modules)

**Problem:** A module loaded on all device types sets options that only exist on servers (e.g. `server.proxy.virtualHosts`). `mkIf` does **not** help — the NixOS module system resolves the attribute path in the definition body even when the condition is false. On a desktop, `server.proxy` doesn't exist → evaluation fails.

### Pattern: `imports` gated on `deviceType` specialArg

`mkSystem` passes `deviceType` via `specialArgs` (like `importExternals`), so it is available at module level without touching `config` — no circular dependency.

1. Accept `deviceType` in the module's function parameters.
2. Gate the device-specific submodule in `imports`.
3. The submodule can use `mkIf` normally since it only loads on matching device types.

```nix
# modules/nixos/ai/services/mnemosyne.nix
{
  config,
  pkgs,
  lib,
  deviceType ? null,
  ...
}:
{
  imports = lib.optionals (deviceType == "server") [ ./mnemosyne-caddy.nix ];
  ...
}
```

```nix
# The standalone submodule (mnemosyne-caddy.nix)
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.mnemosyne;
in
lib.mkIf (cfg.enable && cfg.caddy.enable) {
  server.proxy.virtualHosts = lib.mkMerge [ ... ];
}
```

```nix
# lib/builders/mkSystem.nix — deviceType passed as specialArg
specialArgs = {
  inherit deviceType;
  ...
};
```

### Why not `imports` + `config`?

```nix
# Fails: infinite recursion
{
  config, ...
}: {
  imports = lib.optionals (config.host.device.role == "server") [ ./caddy.nix ];
}
```

Reading `config` inside a module's `imports` creates a circular dependency:
`config` needs all imports resolved first, but the import list depends on `config`.
`deviceType` from `specialArgs` avoids this — it's a plain value, not a thunk into `config`.

### When to use this pattern

- Your module defines `config` that references options from a device-type-specific namespace (`server.*`, `hardware.*`)
- The module is loaded via `attrValues allModules` (all device types)
- Those options don't exist on other device types

### Alternative: stub the option

If the device-gated config is small, declare a stub option in a core module that always loads:

```nix
# modules/nixos/core/default.nix
options.server.proxy.virtualHosts = lib.mkOption {
  type = lib.types.attrsOf lib.types.anything;
  default = { };
};
```

Then `mkIf` works normally. Downside: pollutes the option namespace on non-server hosts, and the stub type might accept invalid config silently. Prefer the `imports` + `deviceType` pattern for anything non-trivial.
