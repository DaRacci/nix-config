---
title: Capability & Sandbox Debugging Workflow
description: Systematic procedure for identifying which systemd hardening options break a service, derived from real debugging of fuse-overlayfs in unprivileged Proxmox LXC.
---

# Capability & Sandbox Debugging Workflow

When a hardened systemd service fails, isolate the breaking option(s) methodically rather than guessing or stripping all hardening.

## Step 1: Confirm service runs without any hardening

Run the service command directly via `systemd-run` with zero hardening to establish a baseline:

```sh
systemctl kill test-service.service 2>/dev/null; systemctl reset-failed test-service.service 2>/dev/null
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  <command>
```

If this fails, service has a non-hardening problem. Fix that first.

## Step 2: Add back hardening options incrementally

Add options in batches, testing each batch with `systemd-run`. Avoid testing one option at a time — batch 3-5 options per invocation to converge faster.

### Tier 1: Universal

```sh
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  --property=NoNewPrivileges=true \
  --property=ProtectClock=true \
  --property=ProtectHostname=true \
  --property=ProtectKernelModules=true \
  --property=ProtectKernelLogs=true \
  --property=ProtectKernelTunables=true \
  --property=RestrictRealtime=true \
  --property=RestrictSUIDSGID=true \
  --property=LockPersonality=true \
  <command>
```

### Tier 2: Isolation

```sh
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  --property=PrivateDevices=true \
  --property=PrivateTmp=true \
  --property=PrivateMounts=true \
  --property=ProtectHome=true \
  --property=ProtectSystem=strict \
  --property=RestrictNamespaces=true \
  <command>
```

### Tier 3: Capabilities + Seccomp

```sh
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  --property=CapabilityBoundingSet= \
  --property=SystemCallFilter='@system-service' \
  --property=SystemCallArchitectures=native \
  --property=SystemCallErrorNumber=EPERM \
  --property=MemoryDenyWriteExecute=true \
  <command>
```

## Step 3: Narrow breaking batch

When a batch fails, split it in half and test each half. Continue binary search until single culprit is isolated.

### Binary search procedure:

```sh
# Test first half of failing batch
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  --property=Option1=true \
  --property=Option2=true \
  <command>

# Test second half
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  --property=Option3=true \
  --property=Option4=true \
  <command>
```

Repeat with halves until one option is identified.

## Step 4: Verify fix

Re-run full hardened config with only the breaking option(s) removed:

```sh
systemd-run --service-type=simple --unit=test-service --wait --pipe \
  --property=User=nobody \
  --property=CapabilityBoundingSet="CAP_NET_BIND_SERVICE" \
  --property=SystemCallFilter='@system-service' \
  ...all options that passed tests, omit only the breaker... \
  <command>
```

If working, apply to permanent unit configuration.

## Known breakers by service type

### FUSE daemons (fuse-overlayfs, sshfs, s3fs, etc.)

Options that break FUSE filesystem daemons:

| Option                        | Why it breaks                                                      | Fix                                                                |
| ----------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `ProtectKernelModules=true`   | Blocks `/proc/modules` access needed by `fusermount3`              | Set `false`                                                        |
| `ProtectKernelLogs=true`      | Blocks `/dev/kmsg` access used by FUSE                             | Set `false`                                                        |
| `ProtectKernelTunables=true`  | Blocks `/sys` access for FUSE setup                                | Set `false`                                                        |
| `SystemCallErrorNumber=EPERM` | `fusermount3` calls `mount(2)` via setuid — seccomp EPERM kills it | Omit `SystemCallErrorNumber`; allow `@mount` in `SystemCallFilter` |
| `PrivateMounts=true`          | Isolates mount namespace — FUSE mount invisible to host            | Set `false` for host-visible mounts                                |
| `ProtectSystem=strict`        | `/dev/fuse` may not be accessible                                  | Set `false` or use `DeviceAllow=/dev/fuse`                         |
| `PrivateDevices=true`         | Blocks `/dev/fuse` device                                          | Set `false`                                                        |

Safe for FUSE daemons (verified working):

| Option                                            | Notes                                                       |
| ------------------------------------------------- | ----------------------------------------------------------- |
| `User`/`Group`                                    | Run as non-root user                                        |
| `ProtectClock=true`                               | No effect on FUSE                                           |
| `ProtectHostname=true`                            | No effect on FUSE                                           |
| `RestrictRealtime=true`                           | No effect on FUSE                                           |
| `RestrictSUIDSGID=true`                           | FUSE doesn't create setuid files                            |
| `LockPersonality=true`                            | No effect on FUSE                                           |
| `MemoryDenyWriteExecute=true`                     | FUSE daemons typically don't JIT                            |
| `SystemCallFilter=[ "@system-service" "@mount" ]` | Required — `@mount` allows `fusermount3` to call `mount(2)` |

### Kernel overlay mounts (`mount -t overlay`)

| Option                     | Why it breaks                             | Fix                 |
| -------------------------- | ----------------------------------------- | ------------------- |
| `RestrictNamespaces=true`  | May interfere with overlay internals      | Set `false`         |
| `PrivateMounts=true`       | Mount invisible outside service namespace | Set `false`         |
| `CapabilityBoundingSet=""` | No `CAP_SYS_ADMIN` → mount fails          | Add `CAP_SYS_ADMIN` |

### Nix daemon

| Option                        | Why it breaks                                      | Fix                                                  |
| ----------------------------- | -------------------------------------------------- | ---------------------------------------------------- |
| `RestrictNamespaces=true`     | Blocks user namespaces needed for sandboxed builds | Set `false`                                          |
| `SystemCallErrorNumber=EPERM` | Blocks `clone(2)` with namespace flags             | Omit `SystemCallErrorNumber` or relax syscall filter |

## FUSE-specific capability requirements

All FUSE daemons run as non-root user but need:

- `CAP_SYS_ADMIN` for **cleanup/unmount** — the FUSE daemon itself runs without it, but `preStop`/`ExecStop` tasks like `umount` need it because unmounting a FUSE mount as non-root user requires this capability.
- `@mount` in `SystemCallFilter` — `fusermount3` is setuid but seccomp still applies; `mount(2)` must be explicitly allowed.

The process is:

1. Daemon starts as `User` (no caps needed) → `fusermount3` setuid binary performs `mount(2)` with kernel privilege
1. Runtime: daemon is a normal user process serving FUSE requests over `/dev/fuse`
1. Stop: `preStop`/`ExecStop` called as same `User`, so `umount` needs `CAP_SYS_ADMIN`

## Common pitfalls

### FUSE start-before-ready race

`Type=simple` FUSE daemons are considered "started" by systemd immediately on fork, before the filesystem actually responds to lookups. This causes dependent services to start with an empty mount.

**Fix:** Add `ExecStartPost` polling loop to mount service that checks for a known file through the mount before returning success:

```nix
ExecStartPost = [
  (pkgs.writeShellScript "wait-fuse-ready" ''
    set -euo pipefail
    for i in $(seq 1 15); do
      entry="$(ls "${storeRealDir}" 2>/dev/null | head -1 || true)"
      if [ -n "$entry" ] && [ -e "${mountpoint}/$entry" ]; then
        exit 0
      fi
      sleep 1
    done
    echo "Timed out waiting for fuse overlay to become responsive"
    exit 1
  '')
];
```

### Layered sandbox effects

Some hardening options have compound effects. For example, `ProtectKernelModules=true` + `ProtectKernelTunables=true` + `PrivateDevices=true` together break FUSE, but removing just one may not be enough if another still blocks a different path. Always test incrementally.

### setuid + seccomp interaction

Setuid binaries like `fusermount3` or `pkexec` temporarily raise privileges, but **seccomp filters are inherited across exec**. If `SystemCallErrorNumber=EPERM` is set, the setuid child still gets EPERM on blocked syscalls. This means:

- `SystemCallFilter = [ "@system-service" ]` blocks `mount(2)` even from setuid helper
- **Fix:** add `@mount` to filter, or drop `SystemCallErrorNumber` so blocked syscall causes process death (which setuid helper may handle better)
