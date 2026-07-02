# AI Editors & Assistants — AI-Assisted Development Tooling

## Purpose

The `purpose.development.editors.ai` Home-Manager module configures editor and agent tooling for AI-assisted development, centered around OpenCode and shared skill directories.

## Entry Point

- **Main file**: [`modules/home-manager/purpose/development/editors/ai/default.nix`](../../../../modules/home-manager/purpose/development/editors/ai/default.nix)
- **Supporting files**: module-local `skills/` directory containing the default skills

## Architecture / Services / Scope

When enabled, the module:

- Ensures a shared AI filesystem directory exists at activation time.
- Adds useful global git ignores (e.g. editor workspace and tool-state directories).
- Configures Zed to expose an `OpenCode` agent server.
- Enables and configures `programs.opencode` with:
  - plugins
  - Nix formatter integration
  - LSP integrations across Nix, config formats, and general-purpose languages
  - command permissions policy
  - a local MCP server (e.g. `mcp-nixos` via `uvx`)
- Writes OpenCode config files (e.g. `~/.config/opencode/oh-my-opencode.json`, `opencode-notifier.json`).
- Registers AI skills under `~/.agents/skills/<name>` via `home.file`.
- Persists OpenCode state directories so they survive reboots on impermanence-based systems.

##### Options

{{#include ../../../generated/purpose-development-editors-ai-options.md}}

### Usage Example

```nix
{ self, inputs, ... }: {
  purpose.development.editors.ai = {
    enable = true;
    includeDefaults = true;

    skills = [
      "${inputs.my-skill-repo}/skills/my-skill"
      "${self}/skills/another-skill"
    ];
  };
}
```

## Operational Notes / Assumptions

- Skill links are generated under `~/.agents/skills/<basename>`.
- Default skills are discovered automatically from the module's local `skills/` directory when `includeDefaults = true`.
- The module currently defines default agent discovery as well, but only skill link materialization is active in `home.file` output.
