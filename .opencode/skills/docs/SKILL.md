---
name: docs
description: Writes and maintains project documentation based on code changes and implementations
---

# Documentation

## Purpose
Maintain clear, accurate, and synchronized documentation for the entire repository. This ensures that system configurations, user environments, and custom modules are understandable and maintainable.

## When to Use
- After implementing new features or modules.
- When existing configuration behavior or options change.
- When adding new hosts or user configurations.
- To improve clarity of existing documentation.

## Workflow
1. **Analyze Changes**: Review implementation commits or code to understand the scope of changes.
2. **Identify Impact**: Determine which files in `docs/src` need creation or updates.
3. **Draft Content**:
   - Create or update Markdown files in `docs/src`.
   - Use underscore filenames (e.g., `my_new_feature.md`).
   - For modules, provide a high-level overview and link to relevant code or external resources.
4. **Update Summary**: Ensure new files are registered in `docs/src/SUMMARY.md` to maintain the book structure.
5. **Verify**: Check that Nix code examples are valid and build commands are accurate.

## Guardrails
- **Location**: Documentation must live under `docs/src`.
- **Option Documentation**: Avoid documenting every single module option. Use the options search functionality unless the configuration is particularly complex or requires special explanation.
- **Scope**: Do not document user-only modules (e.g., anything under `home/racci/features/cli/`). Focus on shared modules and system-wide configurations.
- **Filenames**: Always use underscores (`_`) instead of hyphens (`-`) for documentation filenames.
- **Style**: Keep explanations concise. Focus on *why* something is configured a certain way rather than just *what* the code does.

## Examples

### Adding a new module doc
1. Create `docs/src/modules/my_service.md`:
```markdown
# My Service

Overview of what this service does and why it is included in the configuration.

## Usage
Link to implementation: [modules/nixos/services/my-service.nix](../../modules/nixos/services/my-service.nix)

```nix
{
  services.myService.enable = true;
}
```
```

2. Update `docs/src/SUMMARY.md`:
```markdown
# Summary

- [Introduction](README.md)
- [Modules](modules/overview.md)
  - [My Service](modules/my_service.md)
```

### Updating host documentation
If a host configuration changes significantly:
- Update the relevant host file in `docs/src/hosts/`.
- Ensure hardware-specific details or special manual steps are documented.
