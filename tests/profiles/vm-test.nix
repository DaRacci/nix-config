# VM Test Profile Module
# Injected into every VM test node (auto-discovered and scenario-based).
# This module contains the centralized policy for disabling services,
# overriding options, and generating deterministic secrets in QEMU VM tests.
#
# Service disablement categories:
#   DISABLED (mkForce false) — need real external API keys or auth:
#     - services.tailscale.enable (needs real auth key / OAuth client)
#     - services.mcpo.enable (needs GitHub/AniList OAuth tokens)
#     - services.ollama.enable (needs GPU passthrough unavailable in QEMU)
#   OVERRIDDEN (mkForce false) — conflicts with QEMU test driver:
#     - proxmoxLXC.manageNetwork (QEMU test driver manages networking)
#     - proxmoxLXC.manageHostName (QEMU test driver manages hostname)
#   GENERATED (tmpfiles) — deterministic secrets from key path hash:
#     - All sops.secrets.<name> get content "test-${hashString "sha256" name}"
#     - Written at config.sops.secrets.<name>.path via systemd.tmpfiles.rules
#
# mkForce collision constraint:
#   No other module may use mkForce on services.tailscale.enable,
#   services.mcpo.enable, or services.ollama.enable. Doing so will
#   cause a hard NixOS module evaluation error.
{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    # --- SERVICES NEEDING EXTERNAL API KEYS (DISABLED) ---
    # Tailscale needs a real auth key or OAuth client to join the tailnet.
    # Without real credentials it will fail to authenticate and pollute logs.
    services.tailscale.enable = lib.mkForce false;

    # MCPO needs GitHub, AniList, and other OAuth tokens to operate.
    # These tokens are per-user secrets unavailable in CI.
    services.mcpo.enable = lib.mkForce false;

    # --- GPU-DEPENDENT SERVICES (DISABLED) ---
    # Ollama requires GPU passthrough (ROCm/CUDA) which is not available
    # in QEMU VMs. Running without acceleration is impractically slow.
    services.ollama.enable = lib.mkForce false;

    # --- ProxmoxLXC CONFLICTS (OVERRIDDEN) ---
    # QEMU test driver manages networking and hostname configuration.
    # Enabling proxmoxLXC management would conflict with the test harness.
    proxmoxLXC.manageNetwork = lib.mkForce false;
    proxmoxLXC.manageHostName = lib.mkForce false;

    # --- SOPS-NIX: DISABLE REAL DECRYPTION ---
    # /dev/null satisfies sops-nix's eval-time assertion that at least
    # one key source is configured, while providing no real keys.
    sops.age.keyFile = "/dev/null";
    sops.age.sshKeyPaths = [ ];
    sops.gnupg.home = null;
    sops.gnupg.sshKeyPaths = [ ];

    # Prevent build-time errors from missing/unreadable .sops files.
    sops.validateSopsFiles = false;

    # --- DETERMINISTIC SECRET GENERATION ---
    # systemd-tmpfiles creates secret files at boot BEFORE any sops-dependent
    # services start. File content is hex-encoded SHA-256 of the secret name,
    # so the same key path produces identical content across all test nodes.
    systemd.tmpfiles.rules = lib.mapAttrsToList (
      name: secret:
      let
        content = "test-${builtins.hashString "sha256" name}";
      in
      "f ${secret.path} ${secret.mode} ${secret.owner} ${secret.group} - ${content}"
    ) config.sops.secrets;
  };
}
