# VM Test Profile
# Centralized policy for QEMU VM tests. Disables services, overrides options,
# generates proper sops-encrypted dummy secrets. Injected into every test node.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Valid SSH ed25519 key for sops age conversion — ssh-to-age only supports
  # ed25519 keys. This key is only used as the sops age identity, NOT as the
  # sshd host key (see below).
  dummySshKey =
    pkgs.runCommand "dummy-ssh-key"
      {
        nativeBuildInputs = [ pkgs.openssh ];
      }
      ''
        ssh-keygen -t ed25519 -N "" -f key 2>&1
        cp key $out
      '';

  # Classify secret by name pattern and return context-appropriate dummy value.
  # Placeholder prefixes (GEN_CERT_, GEN_KEY_, GEN_CA) get replaced with real PEM
  # content at derivation build time. All others are deterministic hash-based strings
  # that won't crash parsers.
  mkSecretValue =
    name:
    if lib.hasSuffix "_CRT" name then
      "GEN_CERT_${name}" # Replaced with real PEM at build time
    else if lib.hasSuffix "_KEY" name then
      "GEN_KEY_${name}" # Replaced with real PEM key at build time
    else if name == "SEAWEEDFS/TLS/CA" then
      "GEN_CA" # Replaced with real CA PEM at build time
    else if lib.hasPrefix "SEAWEEDFS/JWT/" name then
      "jwt-dummy-${builtins.hashString "sha256" name}"
    else if lib.hasInfix "/OAUTH2/" name || lib.hasInfix "/OAUTH" name then
      "oauth-dummy-${builtins.hashString "sha256" name}"
    else if lib.hasSuffix "_PASSWORD" name || lib.hasSuffix "_SECRET" name then
      "password-dummy-${builtins.hashString "sha256" name}"
    else if lib.hasInfix "/REGISTRY/" name then
      "registry-dummy-${builtins.hashString "sha256" name}"
    else if name == "SSH_PRIVATE_KEY" then
      null # Handled separately with real key
    else
      "dummy-${builtins.hashString "sha256" name}";

  # Build nested attrset from slash-separated secret names.
  # sops-nix interprets / in secret names as YAML path traversal, so
  # "CLOUDFLARE/DNS_API_TOKEN" becomes YAML key CLOUDFLARE → DNS_API_TOKEN.
  mkNestedSecrets =
    secretNames:
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
    builtins.foldl' (acc: name: setNested acc (lib.splitString "/" name) (mkSecretValue name)) { } (
      builtins.filter (n: n != "SSH_PRIVATE_KEY") secretNames
    );

  # Encrypted YAML with dummy values for every known secret.
  # Generated at eval time so test builds are hermetic.
  # Derivation outputs encrypted file at $out — a path, not a string-with-store-ref.
  mkDummySopsFile =
    secretNames:
    let
      nestedSecrets = mkNestedSecrets secretNames;
      secretsJson = pkgs.writeText "secrets.json" (builtins.toJSON nestedSecrets);
    in
    pkgs.runCommand "dummy-sops-secrets"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.openssh
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.openssl
          (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
        ];
      }
      ''
        # Derive age public key from the test SSH key, same key sops-nix will
        # convert back via sshKeyPaths at boot. This keeps encryption and
        # decryption in sync without managing a separate age key.
        PUBLIC_KEY=$(ssh-keygen -y -f ${dummySshKey} | ssh-to-age)

        # Generate test TLS credentials for SEAWEEDFS secrets.
        # All TLS secrets share one CA+server cert: tests don't need unique certs
        # per service, just valid PEM that won't crash parsers.
        openssl req -x509 -newkey rsa:2048 -keyout ca-key.pem -out ca.pem \
          -days 365 -nodes -subj "/CN=Test CA" 2>/dev/null
        openssl req -new -newkey rsa:2048 -keyout test-key.pem -out test.csr \
          -nodes -subj "/CN=seaweedfs.test.local" 2>/dev/null
        openssl x509 -req -in test.csr -CA ca.pem -CAkey ca-key.pem \
          -set_serial 1 -days 365 -out test-cert.pem 2>/dev/null

        export CA_PEM="$(cat ca.pem)"
        export CERT_PEM="$(cat test-cert.pem)"
        export KEY_PEM="$(cat test-key.pem)"
        export SSH_KEY_CONTENT="$(<${dummySshKey})"

        # Use Python+PyYAML to read JSON, replace cert/key placeholders with
        # real PEM content, and write the complete YAML output.
        python3 << 'PYEOF'
        import json, yaml, os

        with open('${secretsJson}') as f:
            secrets = json.load(f)

        ca_pem = os.environ['CA_PEM']
        cert_pem = os.environ['CERT_PEM']
        key_pem = os.environ['KEY_PEM']
        ssh_key = os.environ['SSH_KEY_CONTENT']

        def replace_vals(d):
            for k, v in list(d.items()):
                if isinstance(v, dict):
                    replace_vals(v)
                elif isinstance(v, str):
                    if v.startswith('GEN_CERT_'):
                        d[k] = cert_pem
                    elif v == 'GEN_CA':
                        d[k] = ca_pem
                    elif v.startswith('GEN_KEY_'):
                        d[k] = key_pem

        replace_vals(secrets)
        secrets['SSH_PRIVATE_KEY'] = ssh_key

        with open('secrets.yaml', 'w') as f:
            yaml.dump(secrets, f, default_flow_style=False, allow_unicode=True)
        PYEOF

        sops --encrypt \
          --age "$PUBLIC_KEY" \
          secrets.yaml > $out
      '';
in
{
  config =
    let
      # Discover all declared sops secrets dynamically from the merged module tree.
      # No hardcoded list to maintain — every `sops.secrets.<NAME> = { ... }` in any
      # imported module is picked up automatically.
      # This is NOT circular: builtins.attrNames only reads key names, not sub-option
      # values (like sopsFile). The sops-nix module's attrsOf submodule handles the
      # merge before we read attrNames, so all declared secrets are visible here.
      allSecretNames = builtins.attrNames config.sops.secrets;
      dummySopsFile = mkDummySopsFile allSecretNames;
    in
    {
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

      # Override sopsFile for secrets that point to production encrypted files
      # (encrypted with real age keys, not our test key).
      # CF_CERT format is "binary" and CF_CREDS format is "json" in production;
      # they share the same dummySopsFile YAML as all other secrets.
      sops.secrets.CF_CERT = {
        sopsFile = lib.mkForce dummySopsFile;
        format = lib.mkForce "yaml";
      };
      sops.secrets.CF_CREDS = {
        sopsFile = lib.mkForce dummySopsFile;
        format = lib.mkForce "yaml";
      };
      sops.secrets."IO_GUARDIAN_PSK".sopsFile = lib.mkForce dummySopsFile;
      sops.secrets.TAILSCALE_AUTH_KEY.sopsFile = lib.mkForce dummySopsFile;
      sops.secrets.HACOMPANION_ENV.sopsFile = lib.mkForce dummySopsFile;

      # --- NIXPKGS: clear overlays (test pkgs has read-only overlays, conflicts with project overlays) ---
      nixpkgs.overlays = lib.mkForce [ ];

      # --- ENABLED: required by baseline assertions ---
      # --- BOOT: mkForce disable systemd-boot (VM uses init-script builder) ---
      boot.loader.systemd-boot.enable = lib.mkForce false;

      # Ensure initrd is built for qemu-vm
      boot.initrd.enable = true;

      services.openssh = {
        enable = true;
        # Use RSA host key (ed25519 generates fine via ssh-keygen but fails at
        # runtime with "error in libcrypto: unsupported" — OpenSSL 3.6.x + OpenSSH
        # 10.3p1 PEM loading path can't handle Ed25519 private keys from the sshd
        # process. This is a nixpkgs openssh/openssl interaction issue, NOT a Lix
        # limitation. Production avoids this by loading the key via sops-install-secrets
        # which writes the file through a different code path.
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

      # Generate RSA host key for sshd. A boot-time ssh-keygen avoids the
      # sops encryption/decryption round-trip which truncates OpenSSH private
      # key trailing newlines through YAML block scalars.
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
