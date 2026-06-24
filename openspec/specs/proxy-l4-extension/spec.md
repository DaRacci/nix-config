# proxy-l4-extension Specification

## Purpose
TBD - created by archiving change proxy-extension-registry. Update Purpose after archive.
## Requirements
### Requirement: L4 extension self-registers with system priority

The system SHALL provide an L4 extension at `modules/nixos/server/proxy/extensions/l4.nix` that registers `server.proxy.extensions.l4` with priority 10 (reserved system range). The extension SHALL have `consumesExtraConfig = false` and `config` function returning `""`.

#### Scenario: L4 extension is registered
- **WHEN** the proxy module loads extensions
- **THEN** `server.proxy.extensions.l4` SHALL exist with priority 10
- **AND** its `config` function SHALL return `""` (no per-vhost HTTP injection)

### Requirement: L4 vhost options declared by extension

The L4 extension SHALL declare per-vhost `l4` options on the `server.proxy.virtualHosts` submodule (via `attrsOf (submodule ...)` pattern matching kanidm's approach). The option SHALL be `nullOr (submodule ...)` with `listenPort` (type: port, required) and `config` (type: str, default "").

#### Scenario: Vhost declares L4 forwarding
- **WHEN** a vhost sets `l4 = { listenPort = 1883; config = "route { proxy localhost:1883 }"; }`
- **THEN** the vhost SHALL have `l4.listenPort = 1883` and `l4.config = "route { proxy localhost:1883 }"`
- **AND** the `l4` option path matches the previous `options.nix` declaration exactly

#### Scenario: Vhost without L4
- **WHEN** a vhost does not set `l4`
- **THEN** `l4` SHALL default to `null`

### Requirement: L4 globalConfig generates layer4 Caddy block

The L4 extension's `globalConfig` function (signature: `hostConfig -> string`) SHALL collect all vhosts with `l4 != null` from `server.proxy.virtualHosts` using `collectAllAttrsFunc`, apply `replaceLocalHost` to the config strings, group entries by `listenPort`, and generate a `layer4 { ... }` block.

#### Scenario: Single L4 entry on a port
- **WHEN** only one vhost has L4 on port 1883
- **THEN** the generated config SHALL be:
```
mqtt.racci.dev:1883 {
    route { proxy 10.0.0.5:1883 }
}
```

#### Scenario: Multiple L4 entries on same port
- **WHEN** two vhosts share port 10200
- **THEN** the generated config SHALL use matcher-based routing:
```
:10200 {
    @piper_racci_dev http host piper.racci.dev
    route @piper_racci_dev { ... }
    @whisper_racci_dev http host whisper.racci.dev
    route @whisper_racci_dev { ... }
}
```

#### Scenario: No L4 entries
- **WHEN** no vhosts have `l4 != null`
- **THEN** `globalConfig` SHALL return `""` (empty layer4 block or omitted)

### Requirement: L4 firewall port management

The L4 extension's module `config` block SHALL (when `isThisIOPrimaryHost` and extension is enabled) open TCP and UDP firewall ports for each unique `listenPort` across all vhosts with `l4 != null`.

#### Scenario: Firewall ports opened for L4
- **WHEN** vhosts use L4 on ports 1883, 10200, 10300
- **AND** this is the IO primary host
- **THEN** `networking.firewall.allowedTCPPorts` SHALL include [1883 10200 10300]
- **AND** `networking.firewall.allowedUDPPorts` SHALL include [1883 10200 10300]

#### Scenario: No firewall ports when no L4
- **WHEN** no vhosts have `l4 != null`
- **THEN** no firewall ports SHALL be opened for L4

### Requirement: L4 extension auto-enables

The L4 extension SHALL set `enable = mkDefault` to `true` when any vhost across any host has `l4 != null`, using the `getAllAttrsFunc` pattern (checking all hosts). Users SHALL be able to force-disable with explicit `enable = false`.

#### Scenario: Auto-enable when L4 is used
- **WHEN** at least one vhost has `l4 != null`
- **THEN** `server.proxy.extensions.l4.enable` SHALL be `true` (via mkDefault)

#### Scenario: Auto-disable when no L4 usage
- **WHEN** no vhosts have `l4 != null`
- **THEN** `server.proxy.extensions.l4.enable` SHALL be `false`

### Requirement: L4 config removed from config.nix

After migration, `config.nix` SHALL NOT contain any L4-specific logic. The `l4Config` let-binding (lines ~45-90), `layer4 {}` block injection in `globalConfig` (line ~202), and firewall L4 port handling (lines ~270-285) SHALL all be removed. The L4 logic SHALL live exclusively in the extension.

#### Scenario: No L4 code in config.nix
- **WHEN** the migration is complete
- **THEN** grepping for "l4" or "layer4" in `config.nix` SHALL return no results

### Requirement: L4 options removed from options.nix

After migration, `options.nix` SHALL NOT contain the `l4` option on the vhost submodule. The option SHALL exist only in the L4 extension's vhost module declaration.

#### Scenario: No l4 option in options.nix
- **WHEN** the migration is complete
- **THEN** grepping for "l4" in `options.nix` SHALL return no results

