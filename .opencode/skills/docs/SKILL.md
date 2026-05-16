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
   - For modules, provide a high-level overview and link to relevant code or external resources
   - When documenting module options, prefer build-time generated option fragments via `{{#include}}` from `docs/src/generated/*.md` instead of hand-maintained option tables or client-side widgets
   - Keep the prose focused on behavior, architecture, usage examples, and operational notes; let generated fragments provide the exhaustive option reference
4. **Update Summary**: Make new files are added to `docs/src/SUMMARY.md` so book structure stays correct.
5. **Verify**: Check that Nix code examples are valid and build commands are accurate

## Guardrails
- **Location**: Documentation must live under `docs/src`.
- **Option Documentation**: Avoid hand-documenting every single module option. For documented modules, prefer build-time generated option fragments included with `{{#include}}`; use prose only for special explanation, caveats, or examples.
- **Scope**: Do not document user-only modules (e.g., anything under `home/racci/features/cli/`). Focus on shared modules and system-wide configurations.
- **Filenames**: Always use underscores (`_`) instead of hyphens (`-`) for documentation filenames.
- **Style**: Keep explanations concise. Focus on *why* something is configured a certain way rather than just *what* the code does.

## Examples

### Adding new module doc
1. Create `docs/src/modules/my_service.md`:
   - a short overview,
   - the module entry point,
   - usage examples,
   - operational notes if needed,
   - and an option reference section that includes a generated fragment.

2. Generate option fragment at build time from module's `options.json`, include it in page with `{{#include}}`, for example `docs/src/generated/my-service-options.md`.

3. Update `docs/src/SUMMARY.md`:
   - register new page in book structure,
   - ensure generated-option workflow changes are reflected in docs build if needed.

4. Prefer this pattern for future module docs:
   - prose in page,
   - exhaustive option reference in a generated include,
   - no manually maintained option tables unless there is a very specific reason.

### Updating host documentation
If host config changes significant:
- Update relevant host file in `docs/src/hosts/`
- Make sure hardware-specific details or special manual steps are documented
