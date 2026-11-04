# Development — Languages, Editors and Version Control

## Purpose

The `purpose.development` Home-Manager modules describe language support once and render it into every enabled editor.
Adding a language should not require editing Zed, VSCode, Helix, and OpenCode separately.
The same purpose owns version control, so git and Jujutsu share one user identity and one signing key.

## Entry Point

- **Language modules**: [`modules/home-manager/purpose/development/languages`](../../../../modules/home-manager/purpose/development/languages)
- **Factories and helpers**: `mkLanguage.nix`, `lib.nix`
- **Editor modules**: [`modules/home-manager/purpose/development/editors`](../../../../modules/home-manager/purpose/development/editors)

## Architecture / Services / Scope

### Language modules

Each language is a module created by `mkLanguage.nix`.
A module exposes:

- `enable` — toggle support for the language.
- `treesitterPackages` — grammars, with an automatic `tree-sitter-grammars.tree-sitter-<name>` default.
- `extraPackages` — tools that are not LSP servers or formatters.
- `lsp` — LSP server descriptors.
- `formatters` — formatter descriptors.
- `editors` — language-level editor metadata such as extension names and language identifiers.
- `allPackages` — read-only union of every package the language contributes.

`languages.common` is enabled by default and owns the shared servers and formatters for config formats, markup, shell,
containers, SQL, and infrastructure files (Markdown, JSON, YAML, TOML, CSS, HTML, XML, Dockerfile, Docker Compose, Bash, Terraform, SQL, and spelling).

### Descriptors

Every descriptor is self-describing, so editors never hard-code language knowledge:

```nix
{
  name = "nixd";              # editor-facing server identifier
  package = pkgs.nixd;        # package placed on PATH
  binary = "nixd";            # optional binary name when it differs from `name`
  args = [ ];                 # launch arguments
  filetypes = [ ".nix" ];     # extensions/globs
  languages = [ "nix" ];      # canonical language ids
  initializationOptions = { };
  settings = { };
  env = { };
  editors = { };              # per-editor overrides, keyed by editor name
  providesFormatting = false;  # server also formats; see below
}
```

### Servers that format

An LSP descriptor may set `providesFormatting = true` to declare that the server formats the language.
Renderers that support language-server formatting then use that server instead of an external formatter descriptor:

- Zed emits `formatter = { language_server = { name = <server>; }; }`.
- Helix sets `auto-format = true` and omits `formatter`, so Helix formats with the server.
- OpenCode has no language-server formatting and keeps using the external formatter descriptor.

This keeps formatting aligned with the server's own project knowledge, such as the crate edition rust-analyzer passes to `rustfmt`.
A language therefore keeps its external formatter descriptor for editors that cannot format through a server.
Capability is always declared explicitly; never inferred from a server's presence, because many servers (`pyright`, `marksman`, `autocorrect`) do not format.

Servers that currently opt in: `rust-analyzer`, `clangd`, `gopls`, `nil`, `taplo`, `yaml-language-server`, and `bash-language-server`.
Each of these formats with the same engine as the language's external formatter,
so opting in does not change formatting output, except `bash-language-server`, which passes editor indent and `.editorconfig` to `shfmt`.

### Editor renderers

Renderers live beside the editor they serve and flatten descriptors across every enabled language:

- `editors/zed/render.nix` — `lsp` settings, `languages.*.language_servers`, per-language formatters, extensions, and wrapper packages.
- `editors/helix/render.nix` — `languages.toml` `language-server`, `language`, and formatter entries.
- `editors/vscode/render.nix` — extension lists and settings grouped by profile.
- `editors/ai/render.nix` — OpenCode `lsp` and `formatter` sections.

The `editors.<name>` field on a descriptor is the escape hatch for editor quirks (custom commands, formatter flags, language identifiers).
Language names are otherwise derived from the canonical id
via [`languages/names.nix`](../../../../modules/home-manager/purpose/development/languages/names.nix),
so modules only declare `languages = [ "csharp" ]`, never `"C#"` and `"c-sharp"` separately.

### Editors

- **Zed** — `purpose.development.editors.zed`.
- **Helix** — `purpose.development.editors.helix`.
- **VSCode** — `purpose.development.editors.vscode`.
- **OpenCode** — `purpose.development.editors.ai`.

### Version control

`purpose.development.vcs` configures git and Jujutsu from the user identity declared once, and signs commits with `core.profile.identity.publicKey`.

- **Entry point**: [`modules/home-manager/purpose/development/vcs.nix`](../../../../modules/home-manager/purpose/development/vcs.nix)
- **Enabled by default**: `purpose.development.vcs.enable` defaults to `purpose.development.enable`; set it to false to keep the language tooling without version control.
- **`user.email` is required**: it has no default, and evaluation fails while the module is enabled without it.
- **`user.name`** defaults to the Home-Manager username with the first letter capitalised.
- **`user.publicKey`** defaults to the contents of `core.profile.identity.publicKey`; when that file is missing the option stays `null` and signing is skipped instead of failing the build.
- **`primaryVCS`** selects the installed tool set: `jujutsu` (the default) adds `jjui`, `jj-pre-push`, `watchman` and uses `meld` as the diff and merge editor, while `git` adds `gitui`.
  Both variants install `gh`, `gh-dash` and `delta`.
- **Signing** — when a key is available, git signs by default with the SSH key and verifies against a generated allowed-signers file; Jujutsu signs at push time only (`git.sign-on-push`) with the same key and the same allowed-signers file.
- **`enableJJDescWrapper`** installs a `jj-desc` wrapper that supplies `LLM_MODEL`, `LLM_PROVIDER` and the `OPENROUTER_API_KEY` SOPS secret; the secret must be declared or the build fails.

### Options

#### Version control

{{#include ../../../generated/purpose-development-vcs-options.md}}

#### Zed

{{#include ../../../generated/purpose-development-editors-zed-options.md}}

#### Helix

{{#include ../../../generated/purpose-development-editors-helix-options.md}}

#### VSCode

{{#include ../../../generated/purpose-development-editors-vscode-options.md}}

#### OpenCode

{{#include ../../../generated/purpose-development-editors-ai-options.md}}

## Operational Notes / Assumptions

- Binaries resolve from `PATH` by default.
  Hard-coding `binary.path` in Zed bypasses direnv; descriptors therefore add packages to the editor environment instead of pinning store paths.
- Launch arguments are shared across editors.
  Use `editors.<name>` when an editor needs different flags, for example formatter write flags in OpenCode.
- A server marked `providesFormatting` takes precedence over external formatter descriptors in Zed and Helix.
  Keep the external formatter declared for OpenCode.
- Zed settings merge recursively.
  `userSettings` values take precedence over the module defaults.
- `languages.common` is enabled with `purpose.development.enable`; disable it explicitly when a host should not receive the shared config-format tooling.

## References

- [Zed configuration](https://zed.dev/docs/configuring-zed)
- [Helix languages](https://docs.helix-editor.com/languages.html)
- [OpenCode configuration](https://opencode.ai/docs/)
