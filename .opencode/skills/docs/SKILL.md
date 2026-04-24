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
   - When documenting module options, prefer build-time generated option fragments via `{{#include}}` from `docs/src/generated/*.md` instead of hand-maintained option tables or client-side widgets.
   - Keep the prose focused on behavior, architecture, usage examples, and operational notes; let generated fragments provide the exhaustive option reference.
4. **Update Summary**: Ensure new files are registered in `docs/src/SUMMARY.md` to maintain the book structure.
5. **Verify**: Check that Nix code examples are valid and build commands are accurate.

## Guardrails
- **Location**: Documentation must live under `docs/src`.
- **Option Documentation**: Avoid hand-documenting every single module option. For documented modules, prefer build-time generated option fragments included with `{{#include}}`; use prose only for special explanation, caveats, or examples.
- **Scope**: Do not document user-only modules (e.g., anything under `home/racci/features/cli/`). Focus on shared modules and system-wide configurations.
- **Filenames**: Always use underscores (`_`) instead of hyphens (`-`) for documentation filenames.
- **Style**: Keep explanations concise. Focus on *why* something is configured a certain way rather than just *what* the code does.

## Examples

### Adding a new module doc
1. Create `docs/src/modules/my_service.md` with:
   - a short overview,
   - the module entry point,
   - usage examples,
   - operational notes if needed,
   - and an option reference section that includes a generated fragment.

2. Generate the option fragment at build time from the module's `options.json` and include it in the page with `{{#include}}`, for example from `docs/src/generated/my-service-options.md`.

3. Update `docs/src/SUMMARY.md`:
   - register the new page in the book structure,
   - and ensure any generated-option workflow changes are reflected in the docs build if needed.

4. Prefer this pattern for future module docs:
   - prose in the page,
   - exhaustive option reference in a generated include,
   - no manually maintained option tables unless there is a very specific reason.

### Updating host documentation
If a host configuration changes significantly:
- Update the relevant host file in `docs/src/hosts/`.
- Ensure hardware-specific details or special manual steps are documented.
