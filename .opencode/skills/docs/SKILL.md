---
name: docs
description: Writes and maintains project documentation based on code changes and implementations
---

# Documentation

## Purpose
Keep docs clear, accurate, and synced with repo. Goal: make system configs, user environments, and shared modules easier to understand and maintain.

## When to Use
- After adding new feature or module
- When config behavior or options change
- When adding new hosts or user configs
- When improving clarity of existing docs

## Workflow
1. **Analyze Changes**: Review implementation commits or code to understand change scope
2. **Identify Impact**: Determine which files in `docs/src` need create or update
3. **Draft Content**:
   - Create or update Markdown files in `docs/src`
   - Use underscore filenames like `my_new_feature.md`
   - For modules, give high-level overview and link to relevant code or external resources
4. **Update Summary**: Make sure new files are added to `docs/src/SUMMARY.md` so book structure stays correct
5. **Verify**: Check Nix code examples are valid and build commands are accurate

## Guardrails
- **Location**: Documentation must live under `docs/src`
- **Option Documentation**: Do not document every single module option. Use options search unless config is complex or needs special explanation
- **Scope**: Do not document user-only modules like anything under `home/racci/features/cli/`. Focus on shared modules and system-wide configs
- **Filenames**: Always use underscores (`_`), not hyphens (`-`)
- **Style**: Keep explanations concise. Focus on *why* config exists, not only *what* code does

## Examples

### Adding new module doc
1. Create `docs/src/modules/my_service.md`:
````markdown
# My Service

Overview of what service does and why it is included in config.

## Usage
Link to implementation: [modules/nixos/services/my-service.nix](../../modules/nixos/services/my-service.nix)

```nix
{
  services.myService.enable = true;
}
```

2. Update `docs/src/SUMMARY.md`:

```markdown
# Summary

- [Introduction](README.md)
- [Modules](modules/overview.md)
  - [My Service](modules/my_service.md)
````

### Updating host documentation
If host config changes in significant way:
- Update relevant host file in `docs/src/hosts/`
- Make sure hardware-specific details or special manual steps are documented
