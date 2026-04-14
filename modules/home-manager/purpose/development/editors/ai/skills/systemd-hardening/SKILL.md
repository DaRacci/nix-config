---
name: systemd-hardening
description: Hardens systemd services against security issues using sandboxing, capability restriction, and syscall filtering. Use when creating or modifying systemd services, writing NixOS modules with systemd.services, reviewing service security, or whenever a serviceConfig block is involved. Ensures services follow defense-in-depth principles with minimal privilege.
---

# Systemd Service Hardening

When creating or modifying systemd services in NixOS, harden every service by default. Unhardened service runs with far more privilege than it needs, so any vulnerability can become foothold for lateral movement, privilege escalation, or data exfiltration.

Goal is simple: give each service minimum access it needs to function, and deny everything else.

## Hardening Tiers

Apply hardening incrementally. Start with Tier 1 (safe for almost all services), then add more tiers as service allows. If service breaks after adding tier, back off that specific option instead of removing whole tier.

### Tier 1: Universal (apply to every service)

These options almost never break service and should always be present:

```nix
serviceConfig = {
  NoNewPrivileges = true;
  ProtectClock = true;
  ProtectHostname = true;
  ProtectKernelModules = true;
  ProtectKernelLogs = true;
  ProtectKernelTunables = true;
  RestrictRealtime = true;
  RestrictSUIDSGID = true;
  LockPersonality = true;
};
```

**Why each matters:**

| Option                  | What it prevents                                                                                 	 |
| ----------------------- | ------------------------------------------------------------------------------------------------ 	 |
| `NoNewPrivileges`       | Process or children gaining new privileges through setuid/setgid binaries or filesystem capabilities |
| `ProtectClock`          | Modifying system clock (only NTP daemons need this)                                       		 |
| `ProtectHostname`       | Changing system hostname or NIS domain                                                       	 |
| `ProtectKernelModules`  | Loading or unloading kernel modules                                                              	 |
| `ProtectKernelLogs`     | Accessing the kernel log ring buffer                                                             	 |
| `ProtectKernelTunables` | Writing to `/proc/sys`, `/sys`, or similar kernel tunables                                       	 |
| `RestrictRealtime`      | Acquiring real-time scheduling policies (prevents CPU starvation attacks)                        	 |
| `RestrictSUIDSGID`      | Creating setuid/setgid files                                                                     	 |
| `LockPersonality`       | Changing execution personality (prevents running non-native binaries)                        	 |

### Tier 2: Isolation (safe for most services)

These create filesystem and device isolation. Most services do not need direct device access or write access to system directories:

```nix
serviceConfig = {
  PrivateDevices = true;
  PrivateTmp = true;
  PrivateMounts = true;
  ProtectHome = true;
  ProtectSystem = "strict";
  RestrictNamespaces = true;
};
```

| Option               | What it does                                                           | When to relax                                                                                     |
| -------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `PrivateDevices`     | Hides `/dev` device nodes (only pseudo-devices remain)                 | Service needs raw device access (for example GPU or USB)                                                  |
| `PrivateTmp`         | Gives service its own `/tmp` and `/var/tmp`                            | Rarely needs relaxing                                                                             |
| `PrivateMounts`      | Isolates mount namespace                                               | Service creates mount points                                                                      |
| `ProtectHome`        | Makes `/home`, `/root`, `/run/user` inaccessible                       | Service reads user home directories                                                               |
| `ProtectSystem`      | Makes filesystem read-only (`"strict"`) or mostly read-only (`"full"`) | Use `"full"` if service writes to `/etc`; pair `"strict"` with `ReadWritePaths` for specific dirs |
| `RestrictNamespaces` | Blocks creating new namespaces                                         | Service uses containers or sandboxing internally                                                  |

**`ProtectSystem` levels:**

- `"strict"` — Entire filesystem hierarchy is read-only. Use `StateDirectory`, `RuntimeDirectory`, `CacheDirectory`, `LogsDirectory` for writable paths (preferred).
- `"full"` — Like `true` but also makes `/etc` read-only. Use when service doesn't need to write to `/etc`.
- `true` — Makes `/usr` and `/boot` read-only.

### Tier 3: User isolation (for services that don't need root)

Most services should not run as root. NixOS gives several approaches:

```nix
serviceConfig = {
  # Option A: DynamicUser (preferred for stateless services)
  DynamicUser = true;
  StateDirectory = "myservice";   # Creates /var/lib/myservice owned by dynamic user
  RuntimeDirectory = "myservice"; # Creates /run/myservice owned by dynamic user
  CacheDirectory = "myservice";   # Creates /var/cache/myservice owned by dynamic user

  # Option B: Dedicated user (for services needing stable uid/gid)
  User = "myservice";
  Group = "myservice";

  PrivateUsers = true;
};
```

| Option         | What it does                                                          | When to use                                                            |
| -------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `DynamicUser`  | Allocates a temporary uid/gid that is released when the service stops | Stateless services, no persistent file ownership needed                |
| `User`/`Group` | Run as a specific pre-created user                                    | Services needing stable uid (e.g., for file ownership across restarts) |
| `PrivateUsers` | Isolates user/group databases                                         | Most services; breaks if service needs to look up other system users   |

**Choosing between DynamicUser and User/Group:**

- `DynamicUser = true` is simpler and more secure — prefer it unless service needs persistent file ownership or other users can see its files.
- If using `DynamicUser`, always pair it with `StateDirectory`/`RuntimeDirectory` for writable paths.
- If service needs to interact with files owned by static user (for example database data directories), use `User`/`Group` instead.

### Tier 4: Capability and syscall restriction (strongest, requires testing)

This tier gives tightest sandbox but is most likely to need per-service tuning:

```nix
serviceConfig = {
  # Drop all capabilities, then add back only what's needed
  CapabilityBoundingSet = [
    # Common capabilities - include only those your service needs:
    # "CAP_NET_BIND_SERVICE"  # Bind to ports < 1024
    # "CAP_CHOWN"             # Change file ownership
    # "CAP_DAC_OVERRIDE"      # Bypass file permission checks
    # "CAP_SETUID"            # Change process UID
    # "CAP_SETGID"            # Change process GID
    # "CAP_SYS_CHROOT"        # Use chroot
  ];

  # Syscall filtering
  SystemCallFilter = [
    "@system-service"          # Base set for most services
    # Add individual syscalls if @system-service isn't enough:
    # "chroot"
    # "~@mount"                # Prefix with ~ to deny a set
    # "~@privileged"           # Deny privileged syscalls
  ];
  SystemCallArchitectures = "native";  # Block non-native syscall ABIs
  SystemCallErrorNumber = "EPERM";     # Return permission error instead of killing

  MemoryDenyWriteExecute = true;  # Prevent W^X violations (JIT needs this off)
};
```

**Capability reference (common services):**

(??)| Capability | Purpose | Typical services |
| --------------------------- | ------------------------------------- | ------------------------------------------- |
(??)| `CAP_NET_BIND_SERVICE` | Bind to privileged ports (< 1024) | Web servers, DNS |
(??)| `CAP_CHOWN` | Change file ownership | Services managing files for multiple users |
(??)| `CAP_DAC_OVERRIDE` | Bypass file read/write/execute checks | Backup services, file managers |
(??)| `CAP_SETUID` / `CAP_SETGID` | Change process UID/GID | Services that drop privileges after startup |
(??)| `CAP_SYS_CHROOT` | Use chroot(2) | Mail servers, FTP servers |
(??)| `CAP_NET_RAW` | Use raw sockets | Ping, network monitoring |
(??)| `CAP_NET_ADMIN` | Network administration | VPN, firewall management |

**SystemCallFilter sets:**

- `@system-service` — Covers most system service needs (file I/O, networking, memory management)
- `@privileged` — Syscalls requiring elevated privileges (usually deny with `~@privileged`)
- `@mount` — Mount/unmount operations
- `@network-io` — Network socket operations
- `@debug` — Debugging syscalls (ptrace, etc.)

**`MemoryDenyWriteExecute`** prevents creating memory regions that are both writable and executable. This blocks most exploit techniques but also breaks JIT compilation (`Node.js`, `Java`, `.NET`). Disable it for JIT-dependent services.

## NixOS-Specific Patterns

### Using StateDirectory and friends (preferred over manual paths)

Instead of manually creating directories and setting permissions, use systemd managed directories. These are created automatically, owned by service user, and cleaned up:

```nix
serviceConfig = {
  StateDirectory = "myservice";     # /var/lib/myservice
  RuntimeDirectory = "myservice";   # /run/myservice
  CacheDirectory = "myservice";     # /var/cache/myservice
  LogsDirectory = "myservice";      # /var/log/myservice
  ConfigurationDirectory = "myservice"; # /etc/myservice
};
```

These work with both `DynamicUser` and static `User`/`Group`.

### Using LoadCredential for secrets (preferred over EnvironmentFile)

Instead of exposing secrets through environment variables (visible in `/proc`), use systemd credentials:

```nix
serviceConfig = {
  LoadCredential = [
    "api-key:${config.sops.secrets."SERVICE/API_KEY".path}"
  ];
};

# Access in ExecStart via: ${CREDENTIALS_DIRECTORY}/api-key
```

This is more secure than `EnvironmentFile` because credentials are stored in private directory accessible only to service process.

### Using ReadWritePaths with ProtectSystem strict

When service needs write access to specific paths under read-only filesystem:

```nix
serviceConfig = {
  ProtectSystem = "strict";
  ReadWritePaths = [
    "/var/lib/myservice"
    "/run/myservice"
  ];
  # Or better, use StateDirectory/RuntimeDirectory which implicitly allows writes
};
```

### Hardened service template

Complete example combining all tiers for typical network service:

```nix
systemd.services.myservice = {
  description = "My Hardened Service";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];

  serviceConfig = {
    ExecStart = lib.getExe cfg.package;

    # Tier 1: Universal
    NoNewPrivileges = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectKernelTunables = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;

    # Tier 2: Isolation
    PrivateDevices = true;
    PrivateTmp = true;
    PrivateMounts = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    RestrictNamespaces = true;

    # Tier 3: User isolation
    DynamicUser = true;
    StateDirectory = "myservice";
    RuntimeDirectory = "myservice";
    PrivateUsers = true;

    # Tier 4: Capability and syscall restriction
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    SystemCallFilter = [ "@system-service" ];
    SystemCallArchitectures = "native";
    SystemCallErrorNumber = "EPERM";
    MemoryDenyWriteExecute = true;

    # Secrets via credentials
    LoadCredential = [
      "config:${config.sops.secrets."MYSERVICE/CONFIG".path}"
    ];
  };
};
```

## Troubleshooting

When hardened service fails to start, isolate which option caused failure:

1. Start with all hardening enabled
1. If service fails, check `journalctl -u myservice.service` for errors
1. Look for common failure patterns:

| Error pattern                            | Likely cause                                | Fix                                                        |
| ---------------------------------------- | ------------------------------------------- | ---------------------------------------------------------- |
| `Permission denied` on filesystem paths  | `ProtectSystem` too strict                  | Add `ReadWritePaths` or use `StateDirectory`               |
| `Operation not permitted` on device      | `PrivateDevices = true`                     | Set to `false` or add specific `DeviceAllow` entries       |
| `Permission denied` on port bind         | Missing `CAP_NET_BIND_SERVICE`              | Add to `CapabilityBoundingSet`                             |
| `Protocol not supported` / socket errors | `RestrictAddressFamilies` too restrictive   | Add required `AF_*` families                               |
| Segfault or JIT failure                  | `MemoryDenyWriteExecute = true`             | Set to `false` for JIT-dependent services                  |
| `Operation not permitted` on syscall     | `SystemCallFilter` missing required syscall | Add syscall or filter set; use `SystemCallLog` to identify |
| Service can't find users/groups          | `PrivateUsers = true`                       | Set to `false` if service needs system user lookups        |
| `Failed to set hostname`                 | `ProtectHostname = true`                    | Set to `false` (rare — most services don't set hostname)   |

### Using systemd-analyze security

Check the hardening score of a service:

```bash
systemd-analyze security myservice.service
```

This produces score from 0 (fully hardened) to 10 (no hardening). Aim for below 5 for most services, below 3 for sensitive ones.

## Decision Checklist

Before finalizing service definition, verify:

- [ ] All Tier 1 options are present (no valid reason to omit these)
- [ ] Tier 2 options are present unless service has a documented need to bypass
- [ ] Service runs as non-root (DynamicUser or dedicated User/Group) unless it genuinely needs root
- [ ] Capabilities are restricted to only what's needed (empty set if possible)
- [ ] SystemCallFilter is set (at minimum `@system-service`)
- [ ] Secrets use `LoadCredential` or `EnvironmentFile` with sops, not plaintext
- [ ] Writable paths use `StateDirectory`/`RuntimeDirectory` rather than manual mkdir
- [ ] `MemoryDenyWriteExecute` is enabled unless service uses JIT

## References

- [How to harden a systemd service unit](https://linux-audit.com/systemd/how-to-harden-a-systemd-service-unit/) — Step-by-step hardening guide with introspection methods
- [systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html) — Full reference for execution environment options
- [NixOS systemd.services options](https://search.nixos.org/options?channel=unstable&query=systemd.services) — NixOS option declarations
