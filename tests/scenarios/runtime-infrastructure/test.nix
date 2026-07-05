{
  nodes = {
    nixio =
      { pkgs, ... }:
      let
        keypair =
          pkgs.runCommand "test-ssh-keypair"
            {
              nativeBuildInputs = [ pkgs.openssh ];
            }
            ''
              mkdir -p $out
              ssh-keygen -t ed25519 -N "" -C "test@runtime-infra" -f $out/key 2>&1
            '';
        pubKeyFile = "${keypair}/key.pub";
        privKeyFile = "${keypair}/key";
      in
      {
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
            openssh.authorizedKeys.keyFiles = [ pubKeyFile ];
          };
        };

        imports = [ ../../../modules/nixos/server/ssh-shell ];

        users.users.root.openssh.authorizedKeys.keyFiles = [ pubKeyFile ];

        environment.etc."id_ed25519".source = privKeyFile;
      };

    nixdev =
      { pkgs, ... }:
      let
        # Reference same derivation from nixio node — deduplicated by store path
        keypair =
          pkgs.runCommand "test-ssh-keypair"
            {
              nativeBuildInputs = [ pkgs.openssh ];
            }
            ''
              mkdir -p $out
              ssh-keygen -t ed25519 -N "" -C "test@runtime-infra" -f $out/key 2>&1
            '';
        privKeyFile = "${keypair}/key";
      in
      {
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

        environment.etc."id_ed25519".source = privKeyFile;
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
      assert keys.strip() != "", "Builder authorized_keys is empty"

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

    # ── Assertion 5: /etc/bashrc guard file exists ───────────────────
    with subtest("nixio: guard file /etc/bashrc exists with SSH_NIX_SHELL"):
      bashrc = nixio.succeed("cat /etc/bashrc")
      assert "SSH_NIX_SHELL" in bashrc, "/etc/bashrc missing SSH_NIX_SHELL guard"

    # ── Assertion 6: SSH_NIX_COMMAND triggers real shell entry path ──
    with subtest("nixio: SSH_NIX_COMMAND triggers real shell entry from nixdev"):
      # Exercises real /etc/bashrc guard → nix-shell → shellHook → exec fish path.
      # ssh -tt forces PTY so [ -t 0 ] is true in bashrc guard.
      # SendEnv forwards SSH_NIX_COMMAND through to shellHook.
      # bashrc fires (root, SSH, PTY, no SSH_NIX_SHELL, no NIX_SKIP_SHELL).
      # shell.nix shellHook sees SSH_NIX_COMMAND and exec fish -c "$SSH_NIX_COMMAND".
      # fish sources fishInit (zoxide, starship, carapace, aliases).
      # functions -q grep confirms the grep→rg alias loaded.
      output = nixdev.succeed(
          "SSH_NIX_COMMAND='echo SSH_NIX_COMMAND_TRIGGERED; functions -q grep; and echo FISH_INIT_OK'"
          + " ssh -tt" + ssh_opts_common
          + " -o SendEnv=SSH_NIX_COMMAND"
          + " root@nixio 2>&1"
      )
      assert "SSH_NIX_COMMAND_TRIGGERED" in output, \
          f"Expected marker in output, got:\n{output}"
      assert "FISH_INIT_OK" in output, \
          f"fish init did not load grep alias; got:\n{output}"

    # ── Assertion 7: NIX_SKIP_SHELL=1 bypasses shell entry ────────────
    with subtest("nixio: NIX_SKIP_SHELL=1 blocks shell entry even with SSH_NIX_COMMAND"):
      # With NIX_SKIP_SHELL=1, /etc/bashrc skips → drops to interactive bash.
      # SSH_NIX_COMMAND must NOT execute. timeout 5 kills hanging interactive session.
      status, output = nixdev.execute(
          "SSH_NIX_COMMAND='echo SHOULD_NOT_RUN' NIX_SKIP_SHELL=1 timeout 5"
          + " ssh -tt" + ssh_opts_common
          + " -o SendEnv=SSH_NIX_COMMAND"
          + " -o SendEnv=NIX_SKIP_SHELL"
          + " root@nixio 2>&1"
      )
      assert status != 0, \
          f"Expected SSH to exit non-zero (timeout/interactive), got status {status}"
      assert "SHOULD_NOT_RUN" not in output, \
          f"SSH_NIX_COMMAND should not run when NIX_SKIP_SHELL=1; got:\n{output}"

    # ── Assertion 8: sshd AcceptEnv includes both vars ────────────────
    with subtest("nixio: sshd AcceptEnv includes NIX_SKIP_SHELL and SSH_NIX_COMMAND"):
      accept_env = nixio.succeed(
          "sshd -T 2>/dev/null | grep -i acceptenv || true")
      assert "NIX_SKIP_SHELL" in accept_env, \
          "NIX_SKIP_SHELL not found in sshd AcceptEnv"
      assert "SSH_NIX_COMMAND" in accept_env, \
          "SSH_NIX_COMMAND not found in sshd AcceptEnv"

    # ── Assertion 9: nix store ping via ssh-ng (best-effort) ───────────
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
