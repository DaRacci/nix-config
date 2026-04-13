# Home-Manager: AI Editors & Assistants

This page documents the Home-Manager module at:

- `modules/home-manager/purpose/development/editors/ai/default.nix`

It configures editor/agent tooling for AI-assisted development, centered around OpenCode and shared skill directories.

______________________________________________________________________

## What this module sets up

When enabled, the module:

- Ensures `~/Projects/AIFS` exists at activation time.
- Adds useful global git ignores:
  - `.workspace`
  - `.sisyphus`
- Configures Zed to expose an `OpenCode` agent server (`opencode acp`).
- Enables and configures `programs.opencode` with:
  - plugins
  - Nix formatter integration
  - Nix LSP integrations (`nixd`, `nil`)
  - command permissions policy
  - local MCP server (`mcp-nixos` via `uvx`)
- Writes:
  - `~/.config/opencode/oh-my-opencode.json`
  - `~/.config/opencode/opencode-notifier.json`
- Registers AI skills under `~/.agents/skills/<name>` via `home.file`.
- Persists OpenCode state directories:
  - `.local/share/opencode`
  - `.local/state/opencode`

______________________________________________________________________

## Options

### `purpose.development.editors.ai.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `false` |

Enable AI tools and assistant/editor integrations for the user profile.

______________________________________________________________________

### `purpose.development.editors.ai.includeDefaults`

| | |
|---|---|
| Type | `bool` |
| Default | `true` |

Whether to include the module’s built-in skills and agents from:

- `modules/home-manager/purpose/development/editors/ai/skills`
- `modules/home-manager/purpose/development/editors/ai/agents`

Set to `false` for a minimal setup with only base OpenCode configuration.

______________________________________________________________________

### `purpose.development.editors.ai.skills`

| | |
|---|---|
| Type | `list of string` |
| Default | `[]` |

Additional skill source paths to register globally under `~/.agents/skills`.

Each entry should point to a skill directory (for example from a flake input or from this repository). The basename of each source path is used as the destination directory name.

Example:

- `"${inputs.my-skill-repo}/skills/my-skill"`
- `"${self}/skills/another-skill"`

______________________________________________________________________

## Usage example

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

______________________________________________________________________

## Notes

- Skill links are generated under `~/.agents/skills/<basename>`.
- Default skills are discovered automatically from the module’s local `skills/` directory when `includeDefaults = true`.
- The module currently defines default agent discovery as well, but only skill link materialization is active in `home.file` output.
