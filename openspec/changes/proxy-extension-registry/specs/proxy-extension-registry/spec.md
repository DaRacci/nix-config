## ADDED Requirements

### Requirement: Global extension registry

The system SHALL provide `server.proxy.extensions` as an attribute set of named extension submodules. Each extension submodule MUST have a `priority` (int, default 100), an `enable` (bool, default false — extensions auto-set to true via `mkDefault` when they have work to do), a `consumesExtraConfig` (bool, default false), a `config` function with signature `vhostName -> vhostAttrSet -> hostConfig -> string`, and a `globalConfig` function with signature `hostConfig -> string` (default returns `""`). Lower priority values SHALL result in earlier placement in generated Caddy config. When priorities are equal, SHALL order alphabetically by extension name.

#### Scenario: Register a new extension

- **WHEN** a module sets `server.proxy.extensions.my-ext = { priority = 75; config = name: vh: hostCfg: "header My-Ext ${vh.baseUrl}"; }`
- **THEN** the extension is available in the registry with priority 75
- **AND** its `config` function can be called with a vhost name, vhost attrset, and host config

#### Scenario: Register a new extension with global config

- **WHEN** a module sets `server.proxy.extensions.my-ext = { priority = 75; globalConfig = hostCfg: "order myext before respond"; }`
- **THEN** the extension's `globalConfig` function SHALL be called on the IO primary host
- **AND** its output SHALL appear in `services.caddy.globalConfig` sorted by priority

#### Scenario: Default extension enable state

- **WHEN** an extension is registered without an explicit `enable` value
- **THEN** `enable` SHALL default to `false`
- **AND** the extension SHALL set `enable = mkDefault true` in its module config when it detects relevant configuration exists

#### Scenario: Extension auto-disables when no work to do

- **WHEN** no vhosts have `kanidm != null`
- **AND** the kanidm extension checks `proxyLib.hasAnyKanidm` and finds `false`
- **THEN** `server.proxy.extensions.kanidm.enable` SHALL be `false`
- **AND** the kanidm extension's config function SHALL never be called

#### Scenario: User can force-disable an extension

- **WHEN** the kanidm extension auto-sets `enable = mkDefault true`
- **AND** the user explicitly sets `server.proxy.extensions.kanidm.enable = false`
- **THEN** `enable` SHALL be `false` (explicit overrides `mkDefault`)
- **AND** the kanidm extension's config function SHALL never be called

#### Scenario: Default extension priority

- **WHEN** an extension is registered without an explicit `priority` value
- **THEN** `priority` SHALL default to `100`

#### Scenario: Default consumesExtraConfig

- **WHEN** an extension is registered without an explicit `consumesExtraConfig` value
- **THEN** `consumesExtraConfig` SHALL default to `false`

#### Scenario: Default globalConfig

- **WHEN** an extension is registered without an explicit `globalConfig` value
- **THEN** `globalConfig` SHALL default to a function returning `""`

### Requirement: Single consumer of extraConfig

The system SHALL enforce that at most one extension with `consumesExtraConfig = true` is enabled for any given vhost. If multiple consuming extensions are enabled for the same vhost, the system SHALL raise an assertion error at evaluation time.

#### Scenario: Single consuming extension — allowed

- **WHEN** only the kanidm extension has `consumesExtraConfig = true` for a vhost
- **THEN** evaluation succeeds

#### Scenario: Multiple consuming extensions — rejected

- **WHEN** two extensions both with `consumesExtraConfig = true` are enabled for the same vhost
- **THEN** the system SHALL raise an assertion error

### Requirement: Vhost name available in attrset

The system SHALL expose the vhost's attribute name as `_name` (str, readOnly, internal) in each vhost submodule's options. Extensions SHALL reference `vh._name` to generate name-scoped identifiers such as `${name}_portal` and `${name}_policy`.

#### Scenario: Kanidm extension references vhost name

- **WHEN** a vhost is named `grafana` and has kanidm enabled
- **AND** the kanidm extension's config function reads `vh._name`
- **THEN** it SHALL receive `"grafana"` and generate `authenticate with grafana_portal`

### Requirement: Extension priority ordering

The system SHALL sort extensions by their `priority` value in ascending order (lower number = earlier in generated config) when collecting extensions for vhost config generation. Equal priorities SHALL be resolved alphabetically by extension name.

#### Scenario: Multi-extension ordering

- **WHEN** extensions exist with priorities 50 (kanidm), 75 (custom), and 200 (dashboard)
- **AND** all three are enabled for a vhost
- **THEN** the config generation SHALL iterate in order: kanidm, custom, dashboard

#### Scenario: Equal priority tie-breaking

- **WHEN** extensions "auth-ext" and "z-ext" both have priority 50
- **THEN** the system SHALL order them: auth-ext, then z-ext

### Requirement: Extension config injection into vhost Caddy blocks

The system SHALL call each enabled extension's `config` function with the vhost name, the vhost's full attribute set (including `_resolvedExtraConfig`), and the host configuration. The vhost attrset SHALL contain `_resolvedExtraConfig` which is the user's `extraConfig` with `replaceLocalHost` already applied. Extension outputs SHALL be concatenated. If any extension with `consumesExtraConfig = true` returned non-empty output, the system SHALL skip appending the raw `extraConfig` afterward. Otherwise, `extraConfig` SHALL be appended after all extension output.

#### Scenario: Extension with non-empty output and consumesExtraConfig

- **WHEN** the kanidm extension (consumesExtraConfig=true) is enabled for a vhost with `kanidm != null`
- **THEN** the extension's output (which includes `_resolvedExtraConfig` wrapped in handles) SHALL appear in the Caddy block
- **AND** `config.nix` SHALL NOT append the raw `extraConfig` afterward

#### Scenario: Extension with non-empty output but does not consume extraConfig

- **WHEN** an extension returns config directives but has `consumesExtraConfig = false`
- **THEN** the user's `extraConfig` SHALL still be appended after the extension output

#### Scenario: Extension with empty output

- **WHEN** the kanidm extension is enabled for a vhost with `kanidm == null`
- **AND** the extension's `config` function returns `""`
- **THEN** nothing from that extension SHALL appear in the vhost Caddy block

### Requirement: Extension global config injection

The system SHALL call each enabled extension's `globalConfig` function (signature: `hostConfig -> string`) exactly once on the IO primary host. Outputs from all enabled extensions SHALL be concatenated into `services.caddy.globalConfig`, sorted by extension priority (ascending, alphabetical tie-break).

#### Scenario: Kanidm extension generates global security block

- **WHEN** the kanidm extension is enabled on the IO primary host
- **AND** its `globalConfig` function returns the `security { ... }` block with identity providers, portals, and policies
- **THEN** the output SHALL be concatenated into `services.caddy.globalConfig`

#### Scenario: Extension with empty globalConfig

- **WHEN** the dashboard extension's `globalConfig` function returns `""`
- **THEN** nothing from the dashboard extension SHALL appear in `services.caddy.globalConfig`

### Requirement: Vhost extension module injection

The vhost submodule in `options.nix` SHALL collect non-null `vhostModule` values from all enabled extensions in `server.proxy.extensions` and include them in its `imports` list. Extensions SHALL set `vhostModule` to a module declaring per-vhost options (relative path, e.g. `options.<extensionName>`).

#### Scenario: Extension declares vhost-level options

- **WHEN** the kanidm extension sets `vhostModule = { options.kanidm = { ... } }`
- **THEN** the `kanidm` option appears on every vhost submodule
- **AND** vhosts can set `server.proxy.virtualHosts.myapp.kanidm = { ... }`

#### Scenario: Multiple extensions declare vhost options

- **WHEN** extensions "kanidm" and "crowdsec" each set `vhostModule` with their options
- **THEN** both `kanidm` and `crowdsec` options appear on every vhost submodule
