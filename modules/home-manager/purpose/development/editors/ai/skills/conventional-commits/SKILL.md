---
name: conventional-commits
description: 'Write and review Conventional Commits commit messages (v1.0.0) for semantic versioning and changelogs. Use when drafting git commit messages, PR titles, release notes, or enforcing conventional commit format like `type(scope): subject`, `BREAKING CHANGE`, footers, and `revert`.'
---

# Conventional Commits (v1.0.0)

Use Conventional Commits spec to keep commit messages consistent and easy for changelog and semantic-versioning tools to parse.

## Commit message format (canonical)

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

Rules:

- Separate **header**, **body**, and **footers** with blank line
- Keep **header** on one line
- Put `!` right before `:` to mark breaking change, like `feat!: ...` or `refactor(api)!: ...`

## Choose type

Spec allows any type, but these are common and widely supported:

- `feat`: new user-facing feature
- `fix`: user-facing bug fix
- `docs`: docs-only change
- `refactor`: refactor with no feature and no bug fix
- `perf`: performance improvement
- `test`: add or adjust tests
- `build`: build system or dependency change
- `ci`: CI config or scripts
- `chore`: maintenance work
- `style`: formatting only, like whitespace or missing semicolons
- `revert`: revert earlier commit

Default choice when unsure:

- If users get new behavior → `feat`
- If users get corrected behavior → `fix`
- Otherwise → `chore` or more specific maintenance type like `refactor`, `build`, or `ci`

## Optional scope

Use scope when it makes impacted area clearer.

Format:

```text
type(scope): description
```

Guidelines:

- Use short noun: `api`, `auth`, `ui`, `db`, `cli`, `deps`, `docs`
- In monorepo, use repo, module, or package name if useful
- If scope adds no clarity, leave it out

## Description (subject)

Write description as short summary of what change does.

Guidelines:

- Use **imperative** mood: `add`, `fix`, `remove`, `update`
- No ending punctuation
- Be specific; avoid vague words like `stuff`, `changes`, `update things`

Examples:

```text
feat(auth): add passwordless login
fix(api): handle empty pagination cursor
chore(deps): bump react to 18.3.0
```

## Body (optional)

Use body for motivation, constraints, or high-level implementation notes.

Guidelines:

- Prefer complete sentences
- If useful, include:
  - why change was needed
  - what approach you chose
  - notable trade-offs

Example:

```text
refactor(parser): simplify tokenisation

Replace regex pipeline with small state machine to reduce backtracking.
```

## Footers (optional)

Footers are key/value-like lines at end. Use them for:

- breaking change details
- issue references
- tooling metadata

Examples:

```text
Refs: #123
Closes: #456
Co-authored-by: Name <email@example.com>
```

## Breaking changes

Mark breaking changes in one or both ways:

1. Add `!` in header:

```text
feat(api)!: remove deprecated v1 endpoints
```

2. Add `BREAKING CHANGE:` footer. Best when change needs explanation:

```text
feat(api): remove deprecated v1 endpoints

BREAKING CHANGE: /v1/* endpoints are removed; migrate to /v2/*.
```

## Reverts

Use `revert` type when undoing earlier change.

Example:

```text
revert: feat(auth): add passwordless login

This reverts commit 1a2b3c4.
```

## Semantic versioning mapping (typical)

Common automated version-bump mapping:

- `fix` → patch
- `feat` → minor
- any breaking change (`!` or `BREAKING CHANGE:`) → major

## When asked to “write commit message”

Collect missing inputs fast:

- What changed? (1–2 sentences)
- Scope or module? (optional)
- User-facing? (feature vs fix vs chore)
- Breaking? (yes/no; migration note if yes)
- Any issue IDs to reference?

Then produce:

1. Conventional header
1. Optional body, only if it adds clarity
1. Optional footers like `Refs:`, `Closes:`, `BREAKING CHANGE:`

## Ready-to-use templates

Minimal:

```text
<type>: <description>
```

With scope:

```text
<type>(<scope>): <description>
```

Breaking change with explanation:

```text
<type>(<scope>): <description>

BREAKING CHANGE: <what breaks and how to migrate>
```
