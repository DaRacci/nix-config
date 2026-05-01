{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkBefore
    mkAfter
    mkMerge
    mkIf
    optionalAttrs
    stringAfter
    ;
  inherit (lib.types) str;

  cfg = config.core.wsl;
  hasWslModule = options ? wsl;
in
{
  options.core.wsl = {
    enable = mkEnableOption "WSL specific configurations, optimisations, and fixes";

    user = mkOption {
      type = str;
      description = "The default user to use for WSL.";
    };
  };

  config = mkIf cfg.enable (
    {
      users.allowNoPasswordLogin = true;

      environment.systemPackages = [ pkgs.wslu ];

      programs.nix-ld = {
        enable = true;
        libraries = [
          # Required by NodeJS installed by VS Code's Remote WSL extension
          pkgs.stdenv.cc.cc
        ];
      };

      environment.sessionVariables = mkMerge [
        {
          EXTRA_CCFLAGS = "-I/usr/include";
          LD_LIBRARY_PATH = mkBefore [
            "/usr/lib/wsl/lib"
            "/run/opengl-driver/lib"
          ];
          NIX_LD_LIBRARY_PATH_x86_64_linux = [
            "/usr/lib/wsl/lib"
            "/run/opengl-driver/lib"
          ];
        }
        (mkIf config.hardware.graphics.hasNvidia {
          CUDA_PATH = "${pkgs.cudatoolkit}";
          EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11_latest}/lib";
          LD_LIBRARY_PATH = mkAfter [ "${pkgs.linuxPackages.nvidia_x11_latest}/lib" ];
        })
      ];

      hardware.graphics = {
        enable = true;
        extraPackages = [
          config.hardware.graphics.package
          config.hardware.graphics.package32
          pkgs.libvdpau-va-gl
        ];
      };
    }
    // optionalAttrs hasWslModule {
      wsl = {
        enable = true;
        defaultUser = cfg.user;
        startMenuLaunchers = true;
        useWindowsDriver = true;

        interop.register = true;
        wslConf.interop.enabled = true;
        wslConf.interop.appendWindowsPath = true;

        # Fixes VSCode not being able to run.
        extraBin = [
          # Required by VS Code's Remote WSL extension
          { src = "${pkgs.coreutils}/bin/dirname"; }
          { src = "${pkgs.coreutils}/bin/readlink"; }
          { src = "${pkgs.coreutils}/bin/uname"; }
        ];
      };

      # Fixes Home-Manager applications not appearing in Start Menu
      system.activationScripts.copy-user-launchers = stringAfter [ ] ''
        for x in applications icons; do
          echo "setting up /usr/share/''${x}..."
          target="/etc/profiles/per-user/${config.wsl.defaultUser}/share/$x/."

          if [ -d "/etc/profiles/per-user/${config.wsl.defaultUser}/share/$x" ]; then
            mkdir -p "/usr/share/$x"
            ${pkgs.rsync}/bin/rsync -ar --delete-after "$target" "/usr/share/$x"
          else
            rm -rf "/usr/share/$x"
          fi
        done
      '';

    }
  );
}
