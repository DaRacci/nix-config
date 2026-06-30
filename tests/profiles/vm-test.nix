# VM Test Profile
# Centralized policy for QEMU VM tests. Disables services, overrides options,
# generates proper sops-encrypted dummy secrets. Injected into every test node.
{ pkgs, lib, ... }:
let

  # Every sops secret name declared across all hosts/modules.
  # Sops validates that every declared secret has a corresponding key in the
  # encrypted file. If a new secret is added elsewhere but not listed here, the
  # test build will fail with "key not found" — add it.
  allSecretNames = [
    # --- core ---
    "SSH_PRIVATE_KEY"
    "CACHE_PUSH_KEY"
    "TAILSCALE_AUTH_KEY"
    "wireguard"

    # --- home (racci) ---
    "LOCATION"
    "OPENROUTER_API_KEY"
    "MCP/API_TOKEN"
    "MCP/PROTON_USER"
    "MCP/PROTON_PASS"
    "MCP/ANILIST_TOKEN"
    "MCP/GITHUB_TOKEN"
    "MCP/HASSIO_TOKEN"

    # --- nixio (database host) ---
    "COUCHDB_SETTINGS"
    "PGADMIN_PASSWORD"
    "MINIO_ROOT_CREDENTIALS"
    "CF_CERT"
    "CF_CREDS"
    "CLOUDFLARE/EMAIL"
    "CLOUDFLARE/DNS_API_TOKEN"
    "CLOUDFLARE/ZONE_API_TOKEN"
    "REDIS/PASSWORD"
    "IO_GUARDIAN_PSK"

    # --- nixio: postgres user passwords ---
    "POSTGRES/IMMICH_PASSWORD"
    "POSTGRES/N8N_PASSWORD"
    "POSTGRES/NEXTCLOUD_PASSWORD"
    "POSTGRES/ATTIC_PASSWORD"
    "POSTGRES/HOMEBOX_PASSWORD"
    "POSTGRES/CODER_PASSWORD"
    "POSTGRES/HASSIO_PASSWORD"
    "POSTGRES/HASSIO_AGENT_PASSWORD"
    "POSTGRES/OPEN_WEBUI_PASSWORD"
    "POSTGRES/POSTGRES_PASSWORD"

    # --- nixcloud hosts ---
    "IMMICH/ENV"
    "NEXTCLOUD/admin-password"
    "SEARXNG_ENVIRONMENT"
    "HOMEBOX_ENV"
    "HACOMPANION_ENV"
    "ATTIC_ENVIRONMENT"
    "UPGRADE_STATUS_ID"
    "KANIDM/ADMIN_PASSWORD"
    "KANIDM/IDM_ADMIN_PASSWORD"
    "KANIDM/PROVISIONING_JSON"
    "KANIDM/OAUTH2/IMMICH_SECRET"
    "KANIDM/OAUTH2/HASSIO_SECRET"
    "KANIDM/OAUTH2/NEXTCLOUD_SECRET"

    # --- nixdev hosts ---
    "REDIS_PASSWORD"
    "N8N/ENCRYPTION_KEY"
    "N8N/RUNNER_AUTH_TOKEN"
    "POSTGRES/WOODPECKER_PASSWORD"
    "GITHUB_TOKEN"
    "REGISTRY/HTPASSWD"
    "REGISTRY/S3_ACCESS_KEY"
    "REGISTRY/S3_SECRET_KEY"
    "REGISTRY/SECRET"

    # --- nixdev: woodpecker ---
    "WOODPECKER/AGENT_SECRET"
    "WOODPECKER/CODEBERG_CLIENT"
    "WOODPECKER/CODEBERG_SECRET"
    "WOODPECKER/GITHUB_CLIENT"
    "WOODPECKER/GITHUB_SECRET"
    "WOODPECKER/GRPC_SECRET"

    # --- monitoring ---
    "MONITORING/GRAFANA/SECRET_KEY"
    "MONITORING/GRAFANA/OAUTH_SECRET"
    "MONITORING/HOME_ASSISTANT/WEBHOOK_URL"
    "MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL"

    # --- seaweedfs TLS & JWT ---
    "SEAWEEDFS/JWT/MASTER"
    "SEAWEEDFS/JWT/MASTER_READ"
    "SEAWEEDFS/JWT/FILER"
    "SEAWEEDFS/JWT/FILER_READ"
    "SEAWEEDFS/TLS/CA"
    "SEAWEEDFS/TLS/MASTER_CRT"
    "SEAWEEDFS/TLS/MASTER_KEY"
    "SEAWEEDFS/TLS/VOLUME_CRT"
    "SEAWEEDFS/TLS/VOLUME_KEY"
    "SEAWEEDFS/TLS/FILER_CRT"
    "SEAWEEDFS/TLS/FILER_KEY"
    "SEAWEEDFS/TLS/CLIENT_CRT"
    "SEAWEEDFS/TLS/CLIENT_KEY"
    "SEAWEEDFS/TLS/ADMIN_CRT"
    "SEAWEEDFS/TLS/ADMIN_KEY"
    "SEAWEEDFS/TLS/WORKER_CRT"
    "SEAWEEDFS/TLS/WORKER_KEY"

    # --- proxy api keys ---
    "PROXY_AUTH/WEBHOOKS_API_KEY"
    "PROXY_AUTH/API_API_KEY"

    # --- s3fs auth ---
    "S3FS_AUTH/IMMICH"
    "S3FS_AUTH/LOKI"
    "S3FS_AUTH/NEXTCLOUD"

    # --- home-assistant ---
    "home-assistant-secrets.yaml"

    # --- USER_PASSWORD — one per host user, racci is the common one ---
    "USER_PASSWORD/racci"
  ];

  # Valid SSH ed25519 key for sops age conversion — ssh-to-age only supports
  # ed25519 keys. Lix's openssh doesn't support ed25519 host keys, so sshd gets
  # a separate RSA key via hostKeys + tmpfiles + oneshot service.
  dummySshKey =
    pkgs.runCommand "dummy-ssh-key"
      {
        nativeBuildInputs = [ pkgs.openssh ];
      }
      ''
        ssh-keygen -t ed25519 -N "" -f key 2>&1
        cp key $out
      '';

  # Build nested attrset from slash-separated secret names.
  # sops-nix interprets / in secret names as YAML path traversal, so
  # "CLOUDFLARE/DNS_API_TOKEN" becomes YAML key CLOUDFLARE → DNS_API_TOKEN.
  nestedSecrets =
    let
      setNested =
        attrs: parts: value:
        let
          key = builtins.head parts;
          rest = builtins.tail parts;
        in
        if rest == [ ] then
          attrs // { "${key}" = value; }
        else
          attrs // { "${key}" = setNested (attrs.${key} or { }) rest value; };
    in
    builtins.foldl' (
      acc: name: setNested acc (lib.splitString "/" name) "dummy-${builtins.hashString "sha256" name}"
    ) { } (builtins.filter (n: n != "SSH_PRIVATE_KEY") allSecretNames);

  # Nested attrs → JSON file (built at eval time).
  secretsJson = pkgs.writeText "secrets.json" (builtins.toJSON nestedSecrets);

  # Encrypted YAML with dummy values for every known secret.
  # Generated at eval time so test builds are hermetic (no external key needed).
  # Derivation outputs encrypted file at $out — a path, not a string-with-store-ref.
  dummySopsFile =
    pkgs.runCommand "dummy-sops-secrets"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.openssh
          pkgs.sops
          pkgs.yq-go
          pkgs.ssh-to-age
        ];
      }
      ''
        # Derive age public key from the test SSH key — same key sops-nix will
        # convert back via sshKeyPaths at boot. This keeps encryption and
        # decryption in sync without managing a separate age key.
        PUBLIC_KEY=$(ssh-keygen -y -f ${dummySshKey} | ssh-to-age)
        SSH_KEY_CONTENT=$(<${dummySshKey})

        # Convert nested JSON to YAML
        cat ${secretsJson} | yq -p json -o yaml > secrets.yaml

        # SSH_PRIVATE_KEY needs the real key content, appended as a block scalar
        {
          echo "SSH_PRIVATE_KEY: |-"
          echo "$SSH_KEY_CONTENT" | sed 's/^/  /'
        } >> secrets.yaml

        sops --encrypt \
          --age "$PUBLIC_KEY" \
          secrets.yaml > $out
      '';
in
{
  config = {
    # --- SOPS: use test bundle instead of production secrets ---
    sops = {
      validateSopsFiles = lib.mkForce false;
      defaultSopsFile = lib.mkForce dummySopsFile;
      age.sshKeyPaths = lib.mkForce [ "/etc/ssh/dummy-host-key" ];
    };

    # Place the test SSH key where sops-nix can find it via sshKeyPaths.
    # sops-install-secrets converts it to an age key at boot for decryption.
    environment.etc."ssh/dummy-host-key".source = dummySshKey;

    # Declare secrets that are referenced by modules but never declared in any
    # `sops.secrets = { ... }` block. Without declaration, config.sops.secrets.FOO
    # is missing at eval time.
    sops.secrets.CACHE_PUSH_KEY = { };

    # --- NIXPKGS: clear overlays (test pkgs has read-only overlays, conflicts with project overlays) ---
    nixpkgs.overlays = lib.mkForce [ ];

    # --- ENABLED: required by baseline assertions ---
    # --- BOOT: mkForce disable systemd-boot (VM uses init-script builder) ---
    boot.loader.systemd-boot.enable = lib.mkForce false;

    # Ensure initrd is built for qemu-vm
    boot.initrd.enable = true;

    services.openssh = {
      enable = true;
      # Production maps SSH_PRIVATE_KEY to /etc/ssh/ssh_host_ed25519_key, but
      # Lix's openssh doesn't support ed25519 — use RSA instead. The RSA key is
      # generated by a tmpfiles + oneshot service below, not via sops.
      hostKeys = lib.mkForce [
        {
          type = "rsa";
          bits = 4096;
          path = "/etc/ssh/ssh_host_rsa_key";
        }
      ];
      settings = {
        PermitRootLogin = lib.mkForce "yes";
        PasswordAuthentication = lib.mkForce true;
      };
    };

    # Generate RSA host key for sshd (ed25519 unsupported in Lix's openssh).
    # Not using sops for this — it's ephemeral per test run.
    systemd.tmpfiles.rules = [
      "d /etc/ssh 0755 root root -"
    ];
    systemd.services.generate-ssh-host-key = {
      description = "Generate SSH RSA Host Key";
      before = [ "sshd.service" ];
      wantedBy = [ "sshd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -N "" -f /etc/ssh/ssh_host_rsa_key
        fi
      '';
    };

    # --- DISABLED: needs real external credentials ---
    services.tailscale.enable = lib.mkForce false; # Needs real auth key / OAuth client.
    services.mcpo.enable = lib.mkForce false; # Needs GitHub, AniList tokens.

    # --- DISABLED: needs GPU ---
    services.ollama.enable = lib.mkForce false; # No GPU in QEMU.

    # --- DISABLED: needs real CF credentials ---
    services.cloudflared.enable = lib.mkForce false;
    # Override sopsFile to use our dummy — production files encrypted with real keys
    sops.secrets.CF_CERT = {
      sopsFile = lib.mkForce dummySopsFile;
      format = lib.mkForce "yaml";
    };
    sops.secrets.CF_CREDS = {
      sopsFile = lib.mkForce dummySopsFile;
      format = lib.mkForce "yaml";
    };

    # Override sopsFile for secrets that point to production encrypted files
    # encrypted with real age keys. Dummy file encrypted with test key.
    sops.secrets."IO_GUARDIAN_PSK".sopsFile = lib.mkForce dummySopsFile;
    sops.secrets.TAILSCALE_AUTH_KEY.sopsFile = lib.mkForce dummySopsFile;
    sops.secrets.HACOMPANION_ENV.sopsFile = lib.mkForce dummySopsFile;

    # --- DISABLED: needs redis-password sops secret ---
    services.prometheus.exporters.redis.enable = lib.mkForce false;

    # --- POSTGRESQL: disable JIT (needs LLVM at runtime), add trust auth ---
    services.postgresql = {
      enableJIT = lib.mkForce false;
      authentication = lib.mkOverride 1500 ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';
    };

    systemd.services.caddy.after = lib.mkForce [ "network.target" ];
    systemd.services.caddy.wants = lib.mkForce [ ];

    # --- PGADMIN: keep enabled for user/group/sops references, but dont start ---
    systemd.services.pgadmin = lib.mkForce { };

    # --- DISABLED: sshd-keygen would overwrite tmpfiles-generated host key ---
    systemd.services.sshd-keygen.enable = lib.mkForce false;

    # --- DISABLED: needs network (no DNS in QEMU) ---
    systemd.services.attic-watch-store.enable = lib.mkForce false;

    # --- OVERRIDDEN: conflicts with QEMU test driver ---
    # services.mcpo is declared by modules/nixos.
    # QEMU test driver may override networking/hostname at runtime.
  };

}
