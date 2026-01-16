---
name: secrets
description: Manage encrypted secrets with sops-nix
---

# Secrets

## Overview

This repository uses **sops-nix** with **age** encryption. Secrets are organized hierarchically with different access levels.

## Secret Locations

| Location | Scope |
|----------|-------|
| `hosts/secrets.yaml` | Global - all hosts |
| `hosts/server/secrets.yaml` | All server hosts |
| `hosts/<type>/<hostname>/secrets.yaml` | Single host |
| `home/<username>/secrets.yaml` | Single user |

## Adding New Secrets

### Step 1: Determine scope

Choose the appropriate secrets file based on who needs access.

### Step 2: Update .sops.yaml (if new path)

If creating a new secrets file, add a rule to `.sops.yaml`:

```yaml
- path_regex: hosts/server/newhost/
  key_groups:
    - age:
        - age1...  # newhost's SSH key as age
        - age187xlhmks2...  # admin key
```

Convert SSH key to age key:
```bash
ssh-to-age < hosts/server/newhost/ssh_host_ed25519_key.pub
```

### Step 3: Add the secret

```bash
# Edit existing file
sops hosts/server/myhost/secrets.yaml

# Or create new file
sops hosts/server/newhost/secrets.yaml
```

Add secrets in YAML format:

```yaml
MY_SECRET: "secret-value"

# Or nested
SERVICE:
  API_KEY: "key-value"
  PASSWORD: "password-value"
```

### Step 4: Declare in Nix

```nix
sops.secrets = {
  "SERVICE/API_KEY" = { };
  "SERVICE/PASSWORD" = {
    owner = "myservice";
  };
};
```

### Step 5: Use the secret

```nix
services.myservice = {
  apiKeyFile = config.sops.secrets."SERVICE/API_KEY".path;
};
```

## Common Patterns

### Simple secret declaration

```nix
sops.secrets = {
  "CLOUDFLARE/EMAIL" = { };
  "CLOUDFLARE/API_TOKEN" = { };
};
```

### Custom permissions

```nix
sops.secrets."DATABASE_PASSWORD" = {
  owner = "postgres";
  group = "postgres";
  mode = "0400";
};
```

### Using templates

Combine multiple secrets into a config file:

```nix
sops = {
  secrets = {
    "DB/USER" = { };
    "DB/PASS" = { };
  };

  templates.db-env.content = ''
    DB_USER=${config.sops.placeholder."DB/USER"}
    DB_PASS=${config.sops.placeholder."DB/PASS"}
  '';
};

services.myapp.environmentFile = config.sops.templates.db-env.path;
```

### Restart services on secret change

```nix
sops.secrets."API_KEY" = {
  restartUnits = [ "myservice.service" ];
};
```

### Use entire file as secret

```nix
sops.secrets."config-file" = {
  sopsFile = ./secrets.yaml;
  key = "";  # Empty key = entire file
  path = "/etc/myservice/config.yaml";
};
```

## Key Management

### Age key sources

1. **Host SSH keys**: Converted to age format
2. **User SSH keys**: In `home/<user>/id_ed25519.pub`
3. **Admin key**: Shared admin access

### Converting SSH to age

```bash
# Public key to age public key
ssh-to-age < ~/.ssh/id_ed25519.pub

# Private key to age private key
ssh-to-age --private-key -i ~/.ssh/id_ed25519
```

## Accessing Secrets in Config

| What | How |
|------|-----|
| Secret file path | `config.sops.secrets."NAME".path` |
| Template file path | `config.sops.templates."NAME".path` |
| Placeholder in template | `config.sops.placeholder."NAME"` |
