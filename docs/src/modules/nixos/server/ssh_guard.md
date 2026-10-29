# SSH Guard — Read-Only Observer Account

## Purpose

Gives the `sysops` bot a bounded way onto every LXC server.
A dedicated SSH account's session is forced through [ssh-guard][ssh-guard], which matches the requested command against a rule tree and only runs it on a match.
Anything outside the tree is denied and audited.

The account is an **observer**: it reads logs and inspects unit state, and nothing in the rule set can start, stop, reload, enable or write anything.
It holds no sudo and is deliberately kept out of every group that would be equivalent to root.

## Entry Points

- **Module**: `modules/nixos/server/ssh-guard/default.nix`
- **Rule set**: `modules/nixos/server/ssh-guard/rules.nix`
- **Authorised key**: `modules/nixos/server/ssh-guard/authorized-key.pub`
- **Upstream**: `flake/nixos/flake.nix` -> `ssh-guard` input

#### Options

{{#include ../../../../generated/server-ssh-guard-options.md}}

## Architecture

### How access is granted

Per-host settings live in that host's own `hosts/server/<host>/default.nix`.

The upstream module generates a single `/etc/ssh_guard/config.toml` and appends a `Match User` block to `services.openssh.extraConfig`.

### Group membership

The account is added to `systemd-journal`.
Without it `journalctl` shows only the account's own units, which makes log reading useless.
It is a read-only group.

Hosts may add more groups through `server.sshGuard.extraGroups`.
Any group listed here must be read-only, `docker` and `wheel` are root-equivalent and would defeat the account.

### What the rule set allows

By defualt all hosts allow the following:

| Command | Allowed forms |
| --- | --- |
| `systemctl` | `status`, `is-active`, `is-enabled`, `is-failed`, `show --property=<p>`, `list-units --state=<s>`, `list-timers` |
| `journalctl` | `-u <unit>`, `-n <lines>`, `-p <priority>`, `--since <when>`, `-b`, `--disk-usage`, `--list-boots`, `--utc` |
| `df` | `-h`, `-H`, `-i`, `-T` |
| `free` | `-h`, `-m`, `-g`, `-w` |
| `ps` | `-e`, `-f`, `-ef`, `-A`, `-eF` |
| `uptime` | `-p`, `-s` |
| `ss` | `-t`, `-u`, `-l`, `-n`, `-a`, `-s`, `-4`, `-6` |
| `systemd-analyze` | `blame`, `critical-chain`, `time` |
| `curl` | exact URLs from the host's `endpoints` list |
| `tail` | files under `tailRoots` |
| `ls` | directories under `lsRoots` |
| `cat` | files under `catRoots` |

Hosts can add their own commands through `extraRules`.

Units are **not** restricted to an enum.
A read-only `status` on any unit is *mostly* harmless, and a fixed list would blind the operator to whatever a later deploy adds.
The subcommand whitelist is the real boundary, `show` requires a unit argument and accepts only state properties, so it cannot dump a unit's `Environment` block.

`ls` has its own root set and `cat` has `catRoots`, so listing `/var/lib` does not let `cat` read it.

## Operational Notes

### Scope boundaries

This module does not grant the ability to fix anything.
Restart, reload and rebuild are intentionally absent.

[ssh-guard]: https://codeberg.org/Racci/ssh-guard

## References

- [ssh-guard configuration reference](https://codeberg.org/Racci/ssh-guard/src/branch/master/docs/CONFIG.md)
- [ssh-guard NixOS setup](https://codeberg.org/Racci/ssh-guard/src/branch/master/docs/NIXOS_SETUP.md)
- [OpenSSH `sshd_config` — ForceCommand](https://man.openbsd.org/sshd_config#ForceCommand)
