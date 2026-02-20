---
name: contributing
description: Create commits and pull requests following conventions
---

# Contributing

## Pre-Submission Checklist

Before submitting changes:

- [ ] Run `nix fmt` to format code
- [ ] Run `nix flake check` (with devenv-root override)
- [ ] Test at least one affected host configuration
- [ ] Test at least one affected home configuration (if applicable)
- [ ] Verify commit message follows conventions

## Commit Message Format

Use conventional commit format:

```
type(scope): brief summary

Optional body explaining why the change was made.
```

### Types

| Type | Use For |
|------|---------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `chore` | Maintenance, dependencies |
| `refactor` | Code restructuring without behavior change |
| `build` | Build system changes |
| `ci` | CI/CD changes |
| `style` | Formatting, whitespace |

### Scopes

Scope should be the common directory path:

| Scope | Example |
|-------|---------|
| `home/racci` | Changes to racci's home config |
| `hosts/server` | Changes affecting server hosts |
| `hosts/server/nixdev` | Changes specific to nixdev |
| `modules/nixos` | NixOS module changes |
| `modules/home-manager` | Home-Manager module changes |
| `pkgs` | Package changes |
| `lib` | Library function changes |

### Examples

```
feat(hosts/server/nixdev): add woodpecker CI runner

fix(modules/nixos/services): correct tailscale firewall rules

chore(flake): update nixpkgs input

refactor(lib/builders): simplify mkSystem arguments
```

## Pull Request Guidelines

- Title should mirror the commit header
- Link related issues: `Closes #123` or `Fixes #123`
- Describe changes and reasoning in the PR body
- Ensure CI passes before requesting review

## PR Description Template

```markdown
## Summary

Brief description of what this PR does and why.

## Changes

- Change 1
- Change 2

## Testing

- Tested on: <hostname>
- Home config tested: <user>@<host>

Closes #<issue>
```
