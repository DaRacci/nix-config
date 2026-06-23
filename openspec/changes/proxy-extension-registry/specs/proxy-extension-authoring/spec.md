## ADDED Requirements

### Requirement: Extension module authoring pattern

The system SHALL support adding new extension files to `modules/nixos/server/proxy/extensions/` that self-register by setting `server.proxy.extensions.<name>`. Extension files MUST receive `proxyLib` through `importModule` and SHALL have access to all server helper functions (isThisIOPrimaryHost, etc.).

#### Scenario: Adding a new extension file

- **WHEN** a developer creates `modules/nixos/server/proxy/extensions/crowdsec.nix`
- **AND** the file sets `server.proxy.extensions.crowdsec = { priority = 60; config = ...; }`
- **AND** `default.nix` imports it via `(importModule ./extensions/crowdsec.nix { inherit proxyLib; })`
- **THEN** the extension appears in the registry without any changes to `config.nix`, `options.nix`, or `kanidm.nix`

#### Scenario: Extension receives proxyLib

- **WHEN** an extension file is imported via `importModule ./extensions/foo.nix { inherit proxyLib; }`
- **THEN** the extension SHALL have access to `proxyLib` functions including `replaceLocalHost`, `resolveKanidmContext`, and `contextToEnvPrefix`

#### Scenario: Extension conditional on host role

- **WHEN** an extension's config function references host configuration that only exists on certain hosts
- **THEN** the extension SHALL guard its output with `isThisIOPrimaryHost` checks where appropriate

### Requirement: Extension declares vhost-level options

An extension SHALL declare its per-vhost options by setting `vhostModule` to a module with `options.<extensionName>` (relative to vhost submodule scope).

#### Scenario: Declaring vhost options for an extension

- **WHEN** the kanidm extension sets `vhostModule` to a module with `options.kanidm`
- **THEN** the extension's `config` function can read `vh.kanidm.bypassPaths`, `vh.kanidm.allowGroups`, etc. from the vhost attrset

### Requirement: Extension declares top-level proxy options

An extension SHALL declare its own `server.proxy`-level options directly in its module's `options` block. The NixOS module system SHALL merge these into the global `server.proxy` option tree.

#### Scenario: Declaring top-level proxy options for an extension

- **WHEN** the kanidm extension declares `options.server.proxy.kanidmContexts` in its module
- **THEN** users can set `server.proxy.kanidmContexts = { ... }` in their host config
