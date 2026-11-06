{
  pkgs,
  lib,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  stateDir = "/var/lib/woodpecker-nix";
  bash = "${pkgs.bashInteractive}/bin/bash";
  busybox = "${pkgs.pkgsStatic.busybox}";

  # Minimal image: the test executes bash from the shared store, so the image only needs a rootfs.
  # The marker under /nix proves the mount shadows it.
  testImage = pkgs.dockerTools.buildImage {
    name = "registry.racci.dev/lix-woodpecker-test";
    tag = "latest";
    copyToRoot = pkgs.runCommand "woodpecker-test-rootfs" { } ''
      mkdir -p $out/tmp $out/root $out/etc/nix $out/nix/store
      chmod 1777 $out/tmp
      echo 'experimental-features = nix-command flakes' > $out/etc/nix/nix.conf
      touch $out/nix/store/image-marker
    '';
  };

  machineConfig =
    { config, ... }:
    {
      imports = [ ../../modules/nixos/services/woodpecker-nix.nix ];

      nix.package = pkgs.lix;
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      boot.kernelModules = [ "overlay" ];

      virtualisation = {
        memorySize = 4096;
        cores = 2;
        diskSize = 10240;

        docker = {
          enable = true;
          daemon.settings.storage-driver = "overlayfs";
        };
      };

      services.woodpeckerNix = {
        enable = true;

        isolatedStore = {
          enable = true;
          # a dynamic bash in a raw derivation has no declared glibc dependency in the sandbox.
          bootstrapPackages = [ pkgs.pkgsStatic.busybox ];

          #FIXME:Kernel overlayfs currently rejects chmod on store paths created by non-root in this test kernel.
          overlayfs.enable = false;
        };

        cache = "git";
        cachePopulate = [ ];

        woodpecker.agents = [ "local" ];
      };

      # we test the same container invocation directly, without needing a Woodpecker server.
      services.woodpecker-agents.agents.local = {
        enable = false;
        extraGroups = [ "docker" ];

        environment = {
          WOODPECKER_SERVER = "127.0.0.1:9000";
          WOODPECKER_BACKEND = "docker";
          WOODPECKER_AGENT_SECRET = "vm-test-agent-secret";
          WOODPECKER_MAX_WORKFLOWS = "2";
        };
      };

      assertions = [
        {
          assertion =
            config.services.woodpecker-agents.agents.local.environment.WOODPECKER_BACKEND_DOCKER_VOLUMES
            == lib.concatStringsSep "," config.services.woodpeckerNix.woodpecker.extraVolumes;
          message = "agent docker volumes drifted from services.woodpeckerNix.woodpecker.extraVolumes";
        }
        {
          assertion =
            config.services.woodpecker-agents.agents.local.environment.WOODPECKER_ENVIRONMENT
            == lib.concatStringsSep "," (
              lib.mapAttrsToList (k: v: "${k}:${v}") config.services.woodpeckerNix.woodpecker.extraEnvironment
            );
          message = "agent environment drifted from services.woodpeckerNix.woodpecker.extraEnvironment";
        }
      ];
    };
in
pkgs.testers.runNixOSTest (
  { config, ... }:
  {
    name = "vm-test-woodpecker-store";
    node.specialArgs = { inherit lib; };
    nodes.machine = machineConfig;

    testScript =
      let
        machine = config.nodes.machine;
        volumes = machine.services.woodpeckerNix.woodpecker.extraVolumes;
        environment = machine.services.woodpeckerNix.woodpecker.extraEnvironment;
        nixHost = "${machine.nix.package}/bin/nix";
        daemonStore = "unix://${stateDir}/nix/var/nix/daemon-socket/socket";

        dockerVolumes = lib.concatMapStringsSep " " (
          volume: "--volume ${lib.escapeShellArg volume}"
        ) volumes;
        dockerEnvironment = lib.concatStringsSep " " (
          lib.mapAttrsToList (key: value: "--env ${lib.escapeShellArg "${key}=${value}"}") environment
        );
        dockerPrefix = "docker run --rm --network none ${dockerVolumes} ${dockerEnvironment}";
      in
      ''
        import shlex

        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("woodpecker-nix-daemon.service")
        machine.wait_for_unit("docker.service")

        machine.succeed("test -f ${stateDir}/.bootstrap-hash")
        machine.succeed("grep -q '^sandbox = true$' ${stateDir}/etc/nix/nix.conf")
        machine.succeed("grep -q '^sandbox-fallback = false$' ${stateDir}/etc/nix/nix.conf")
        machine.succeed("test -S ${stateDir}/nix/var/nix/daemon-socket/socket")
        machine.succeed("${nixHost} --extra-experimental-features 'nix-command' store ping --store ${daemonStore}")

        runtime_env = machine.succeed("readlink -f ${stateDir}/nix/var/nix/profiles/default-1-link").strip()
        runtime_name = runtime_env.rsplit("/", 1)[-1]
        machine.succeed(f"test -d ${stateDir}/nix/store/{runtime_name}")

        machine.succeed("docker load -i ${testImage}")
        image_ref = "registry.racci.dev/lix-woodpecker-test:latest"

        def container(script):
            return "${dockerPrefix} " + image_ref + " " + shlex.quote("${bash}") + " -c " + shlex.quote(script)

        def run_container(script):
            return machine.succeed(container(script))

        probe = f"""
        set -eu
        test "$NIX_REMOTE" = daemon
        test ! -e /nix/store/image-marker
        case "$(command -v nix)" in /nix/store/*) ;; *) echo "nix is not from the shared store: $(command -v nix)"; exit 1 ;; esac
        test -f {runtime_env}/etc/ssl/certs/ca-bundle.crt
        test -d /root/.cache/nix/gitv3
        nix store ping
        nix path-info {runtime_env}
        cat > /tmp/probe.nix <<'PROBE'
        derivation {{
          name = "ci-store-probe";
          system = "${system}";
          builder = builtins.storePath "${busybox}/bin/busybox";
          args = [ "touch" (builtins.placeholder "out") ];
        }}
        PROBE
        nix build --impure --offline --option substitute false --option sandbox-fallback false --no-link --print-out-paths -f /tmp/probe.nix
        """

        out = run_container(probe).strip().splitlines()[-1]
        assert out.startswith("/nix/store/"), out
        out_name = out.rsplit("/", 1)[-1]

        machine.succeed(f"test -e ${stateDir}/nix/store/{out_name}")
        machine.succeed(f"test ! -e /nix/store/{out_name}")

        persist = f"""
        set -eu
        nix path-info {out}
        """
        run_container(persist)

        escape = """
        set -eu
        cat > /tmp/escape.nix <<'ESCAPE'
        derivation {
          name = "sandbox-escape-probe";
          system = "${system}";
          builder = builtins.storePath "${busybox}/bin/busybox";
          args = [ "cp" "/etc/hostname" (builtins.placeholder "out") ];
        }
        ESCAPE
        nix build --impure --offline --option substitute false --option sandbox-fallback false --no-link --print-out-paths -f /tmp/escape.nix
        """
        machine.fail(container(escape))

        concurrent = """
        set -eu
        cat > /tmp/concurrent.nix <<'CONC'
        derivation {
          name = "ci-store-concurrent";
          system = "${system}";
          builder = builtins.storePath "${busybox}/bin/busybox";
          args = [ "touch" (builtins.placeholder "out") ];
        }
        CONC
        nix build --impure --offline --option substitute false --option sandbox-fallback false --no-link --print-out-paths -f /tmp/concurrent.nix
        """
        machine.succeed(f"( {container(concurrent)} > /tmp/c1 2>&1 ) & ( {container(concurrent)} > /tmp/c2 2>&1 ) & wait")
        c1 = machine.succeed("cat /tmp/c1").strip().splitlines()[-1]
        c2 = machine.succeed("cat /tmp/c2").strip().splitlines()[-1]
        assert c1 == c2, (c1, c2)

        machine.fail("journalctl -u woodpecker-nix-daemon --no-pager | grep -i 'auto-disabling sandboxing'")
        machine.fail("journalctl -u woodpecker-nix-daemon --no-pager | grep -i 'sandbox-fallback'")
      '';
  }
)
