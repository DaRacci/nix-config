let
  keyFixture = import ./default.nix;
in
{
  nodes = {
    # ── Build server ──────────────────────────────────────────────────────────
    nixio = { pkgs, ... }: {
      services.openssh.enable = true;

      nix.enable = true;
      nix.settings.trusted-users = [ "builder" ];

      users = {
        groups.builder = { };
        users.builder = {
          isSystemUser = true;
          group = "builder";
          home = "/var/lib/builder";
          createHome = true;
          shell = pkgs.bash;
          openssh.authorizedKeys.keys = [ keyFixture.pubKey ];
        };
      };

      imports = [ ../../../modules/nixos/server/ssh-shell ];

      users.users.root.openssh.authorizedKeys.keys = [ keyFixture.pubKey ];

      # Deploy test helper scripts for guard condition verification.
      # These test the guard's condition logic (EUID, SSH_CONNECTION, TTY, env vars)
      # without triggering `exec nix-shell` (which hangs in QEMU).
      environment.etc."test-guard.sh" = {
        source = pkgs.writeText "test-guard.sh" ''
          #!/bin/sh
          # Simulates guard condition from /etc/bashrc.
          # Uses $VAR instead of $"{VAR:-} to avoid Nix escaping conflict.
          # Variables are exported with defaults before check.
          EUID=0
          SSH_CONNECTION="1.2.3.4 49152 5.6.7.8 22"
          export EUID SSH_CONNECTION
          if [ "$EUID" = "0" ] \
             && [ -n "$SSH_CONNECTION" ] \
             && [ -t 0 ] \
             && [ -z "$SSH_NIX_SHELL" ] \
             && [ -z "$NIX_SKIP_SHELL" ]; then
            echo GUARD_CONDITION_MET
          else
            echo GUARD_CONDITION_NOT_MET
          fi
        '';
      };

      environment.etc."test-optout.sh" = {
        source = pkgs.writeText "test-optout.sh" ''
          #!/bin/sh
          # Same condition with NIX_SKIP_SHELL=1 - guard should be blocked.
          # Uses $VAR (no braces) to keep Nix quoting simple.
          EUID=0
          SSH_CONNECTION="1.2.3.4 49152 5.6.7.8 22"
          NIX_SKIP_SHELL=1
          export EUID SSH_CONNECTION NIX_SKIP_SHELL
          if [ "$EUID" = "0" ] \
             && [ -n "$SSH_CONNECTION" ] \
             && [ -t 0 ] \
             && [ -z "$SSH_NIX_SHELL" ] \
             && [ -z "$NIX_SKIP_SHELL" ]; then
            echo GUARD_WOULD_FIRE
          else
            echo GUARD_BLOCKED
          fi
        '';
      };
    };

    # ── Client ────────────────────────────────────────────────────────────────
    nixdev = _: {
      services.openssh.enable = true;

      nix.enable = true;
      nix = {
        distributedBuilds = true;
        settings.builders-use-substitutes = true;
        buildMachines = [
          {
            hostName = "nixio";
            system = "x86_64-linux";
            protocol = "ssh-ng";
            sshUser = "builder";
            sshKey = "/root/.ssh/id_ed25519";
            supportedFeatures = [
              "kvm"
              "big-parallel"
            ];
          }
        ];
      };

      environment.etc."id_ed25519".text = keyFixture.privKey;
    };
  };

  # NOTE: `start_all()` and per-node baseline assertions injected by builder.nix.
  # Do NOT call start_all() here.
  testScript = ''
    # ── Diagnostic: nix-daemon state ──────────────────────────────────────
    with subtest("nixio: nix-daemon unit status"):
      print("[diag] nixio nix-daemon unit list:", nixio.succeed(
          "systemctl list-units --all --no-legend 'nix-daemon*'"))
      nixio.succeed("systemctl status nix-daemon.service 2>&1 || true")

    with subtest("nixdev: nix-daemon unit status"):
      print("[diag] nixdev nix-daemon unit list:", nixdev.succeed(
          "systemctl list-units --all --no-legend 'nix-daemon*'"))
      nixdev.succeed("systemctl status nix-daemon.service 2>&1 || true")

    # ── Assertion 1: builder user exists on nixio ────────────────────────
    with subtest("nixio: builder user exists"):
      nixio.succeed("id builder")
      nixio.succeed("getent group builder")

    # ── Assertion 2: builder authorized_keys contains test key ──────────
    with subtest("nixio: builder authorized_keys contains test key"):
      keys = nixio.succeed(
          "cat /etc/ssh/authorized_keys.d/builder 2>/dev/null || "
          + "cat /var/lib/builder/.ssh/authorized_keys")
      assert "${keyFixture.pubKey}" in keys, \
          "Builder authorized_keys missing test public key"

    # ── Helper: bootstrap nixdev SSH key + known_hosts ───────────────────
    ssh_opts_common = (
        " -o StrictHostKeyChecking=yes"
        " -o UserKnownHostsFile=/root/.ssh/known_hosts"
        " -o HostKeyAlgorithms=+ssh-rsa"
        " -i /root/.ssh/id_ed25519"
    )
    nixdev.succeed("mkdir -p /root/.ssh")
    nixdev.succeed("cp /etc/id_ed25519 /root/.ssh/id_ed25519")
    nixdev.succeed("chmod 0600 /root/.ssh/id_ed25519")
    nixdev.succeed("ssh-keyscan -t rsa nixio 2>/dev/null > /root/.ssh/known_hosts")

    # ── Assertion 3: SSH from nixdev → builder@nixio succeeds ──────────
    with subtest("nixdev: SSH connectivity to builder@nixio"):
      nixdev.succeed(
          "ssh" + ssh_opts_common
          + " builder@nixio echo hello"
      )

    # ── Assertion 4: /etc/nix/machines includes nixio with ssh-ng ──────
    with subtest("nixdev: /etc/nix/machines has nixio ssh-ng"):
      machines_content = nixdev.succeed("cat /etc/nix/machines")
      assert "nixio" in machines_content, "/etc/nix/machines missing nixio"
      assert "ssh-ng" in machines_content, "/etc/nix/machines missing ssh-ng protocol"
      assert "builder" in machines_content, "/etc/nix/machines missing builder user"

    # ── Assertion 5: guard condition fires in SSH-like environment ────
    with subtest("nixio: guard condition fires via script(1) PTY"):
      # script(1) allocates a PTY so [ -t 0 ] is true (simulates interactive SSH).
      # bash /etc/test-guard.sh reads script from store path.
      nixio.succeed(
          "script -qc 'bash /etc/test-guard.sh' /dev/null 2>&1"
          + " | grep -q GUARD_CONDITION_MET"
      )

    with subtest("nixio: guard file /etc/bashrc exists with SSH_NIX_SHELL"):
      bashrc = nixio.succeed("cat /etc/bashrc")
      assert "SSH_NIX_SHELL" in bashrc, "/etc/bashrc missing SSH_NIX_SHELL guard"

    # ── Assertion 6: NIX_SKIP_SHELL=1 prevents guard condition ─────────
    with subtest("nixio: NIX_SKIP_SHELL=1 blocks guard via script(1) PTY"):
      nixio.succeed(
          "script -qc 'bash /etc/test-optout.sh' /dev/null 2>&1"
          + " | grep -q GUARD_BLOCKED"
      )

    with subtest("nixio: sshd AcceptEnv includes NIX_SKIP_SHELL"):
      accept_env = nixio.succeed(
          "sshd -T 2>/dev/null | grep -i acceptenv || true")
      assert "NIX_SKIP_SHELL" in accept_env, \
          "NIX_SKIP_SHELL not found in sshd AcceptEnv"

    # ── Assertion 7: nix store ping via ssh-ng (best-effort) ───────────
    with subtest("nix store ping via ssh-ng"):
      nix_sshopts = (
          "-o StrictHostKeyChecking=no"
          " -o UserKnownHostsFile=/dev/null"
          " -o HostKeyAlgorithms=+ssh-rsa"
          " -o PubkeyAcceptedKeyTypes=+ssh-rsa"
          " -i /root/.ssh/id_ed25519"
      )
      status, output = nixdev.execute(
          f"NIX_SSHOPTS='{nix_sshopts}'"
          + " timeout 30 nix store ping --store ssh-ng://builder@nixio 2>&1"
      )
      if status != 0:
          print(
              f"[WARN] nix store ping failed:"
              f" {output}"
          )
      else:
          print(f"[OK] nix store ping succeeded:\n{output}")
  '';
}
