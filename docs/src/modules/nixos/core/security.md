# Security

Applies shared host security defaults.

- **Entry point**: [security.nix](../../../../../modules/nixos/core/security.nix)

---

## Overview

This module enables baseline security features such as `sudo-rs`, TPM2 support, Polkit, kernel protection flags, and open-file limits for users.

---

## Options

{{#include ../../../../generated/core-security-options.md}}

---

## Behaviour

When enabled, module:

- sets `security.protectKernelImage = true`,
- enables `security.polkit`,
- disables classic `sudo` and enables `security.sudo-rs.execWheelOnly`,
- enables `security.tpm2`,
- sets PAM `nofile` limit for all users to `core.security.userLimit`,
- sets `systemd.user.extraConfig = "DefaultLimitNOFILE=<limit>"`, and
- sets kernel sysctl `fs.file-max = 65536`.

---

## Usage Example

```nix
{ ... }: {
  core.security = {
    enable = true;
    userLimit = 65536;
  };
}
```

---

## Operational Notes

- Module leaves `security.lockKernelModules = false` even while enabling other hardening defaults.
- `userLimit` affects both PAM sessions and user systemd services, keeping file descriptor limits aligned.
