---
name: docs
description: Writes and maintains project documentation based on code changes and implementations
---

# Documentation

## Purpose

Keep docs clear, accurate, and synced with repo.
Goal: make system configs, user environments, and shared modules easier to understand and maintain.

## When to Use

- After adding new feature or module
- When config behavior or options change
- When adding new hosts or user configs
- When improving clarity of existing docs

## Workflow

1. **Analyze Changes**: Review implementation commits or code to understand change scope
2. **Identify Impact**: Determine which files in `docs/src` need to create or update
3. **Format Standard**: All Component, Host, and Module reference documentation MUST adhere to the appropriate reference template (see [Reference Templates](#reference-templates)). Other documentation (guides, index files) may vary but should remain consistent.
4. **Configuration Drift**: Do not copy-paste exact configuration values (like IPs, specific package versions, or port numbers) into the documentation unless they are an immutable part of the architecture. Instead, describe the _intent_ or point to the code/generated docs. Configuration values drift over time and break documentation.
5. **Draft Content**:
   - Create or update Markdown files in `docs/src`
   - Use underscore filenames like `my_new_feature.md`
   - For modules, provide a high-level overview and link to relevant code or external resources
6. **Update Summary**: Make sure new files are added to `docs/src/SUMMARY.md` so book structure stays correct.
7. **Verify**: Check that Nix code examples are valid and build commands are accurate

## Guardrails

- **Location**: Documentation must live under `docs/src`.
- **Option Documentation**: NEVER hand-document every single module option. For documented modules, you MUST use build-time generated option fragments included with `{{#include}}`; use prose only for special explanation, caveats, or examples.
- **Configuration Drift**: Never hardcode configuration values (IPs, versions) if they are subject to change. Explain how it works instead of what exact value is currently set.
- **Scope**: Do not document user-only modules (e.g., anything under `home/racci/features/cli/`). Focus on shared modules and system-wide configurations.
- **Filenames**: Always use underscores (`_`) instead of hyphens (`-`) for documentation filenames.
- **Style**: Keep explanations concise. Focus on _why_ something is configured a certain way rather than just _what_ the code does. Follow the appropriate reference template strictly for components, hosts, and modules.

## Reference Templates

All Component, Host, and Module reference documentation in `docs/src/` must follow the appropriate reference template. Select the template that matches the doc type and fill in the relevant sections, omitting sections only if they genuinely do not apply (e.g., no secrets). Using dedicated reference templates keeps each doc type flexible instead of forcing every page into a single rigid structure.

- [Host Template](references/host-template.md)
- [Module Template](references/module-template.md)

Both templates share a common base (`Purpose`, `Entry Point`, `Architecture / Services / Scope`, `Secrets`, `Operational Notes / Assumptions`, `References`) but allow doc-type-specific structure:

- **Hosts**: emphasize services and hardware, coordinator dependencies, and per-host secrets.
- **Modules**: emphasize the module's options (via generated fragments), behavior, and how it integrates with the rest of the system.

**Coordinator references**: When a page refers to another host in the cluster, refer to it by its generic role name (e.g. "IO Coordinator", "Database Coordinator", "Identity Coordinator") rather than its hostname, and add a link to the coordinator's host page in the `References` section.

## Examples

### Adding new module doc

1. Start from the [Module Template](references/module-template.md) and create `docs/src/modules/my_service.md`:
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

If host config changes significantly:

- Update relevant host file in `docs/src/hosts/` using the [Host Template](references/host-template.md)
- Make sure hardware-specific details or special manual steps are documented
- Refer to other hosts by their generic coordinator role name (e.g. "Database Coordinator") rather than their hostname, and link to their page in `References`
