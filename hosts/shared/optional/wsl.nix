{ flake, config, pkgs, lib, ... }: with builtins; with lib; {
  wsl.enable = true;
  wsl.defaultUser = "racci";
  wsl.startMenuLaunchers = true;
  wsl.nativeSystemd = true;
  users.allowNoPasswordLogin = true;

  wsl.interop.register = true;
  wsl.wslConf.interop.enabled = true;
  wsl.wslConf.interop.appendWindowsPath = true;

  # Fixes VSCode not being able to run.
  wsl.extraBin = [
    # Required by VS Code's Remote WSL extension
    { src = "${pkgs.coreutils}/bin/dirname"; }
    { src = "${pkgs.coreutils}/bin/readlink"; }
    { src = "${pkgs.coreutils}/bin/uname"; }
  ];

  environment.systemPackages = with pkgs; [ wslu ];

  programs.nix-ld = {
    enable = true;
    libraries = [
      # Required by NodeJS installed by VS Code's Remote WSL extension
      pkgs.stdenv.cc.cc
    ];

    # Use `nix-ld-rs` instead of `nix-ld`, because VS Code's Remote WSL extension launches a non-login non-interactive shell, which is not supported by `nix-ld`, while `nix-ld-rs` works in non-login non-interactive shells.
    package = flake.inputs.nix-ld-rs.packages.${pkgs.system}.nix-ld-rs;
  };

  # Fixes Home-Manager applications not appearing in Start Menu
  system.activationScripts.copy-user-launchers = stringAfter [ ] ''
    for x in applications icons; do
      echo "setting up /usr/share/''${x}..."
      targets=()
      if [[ -d "/home/${config.wsl.defaultUser}/.nix-profile/share/$x" ]]; then
        targets+=("/home/${config.wsl.defaultUser}/.nix-profile/share/$x/.")
      fi

      if (( ''${#targets[@]} != 0 )); then
        mkdir -p "/usr/share/$x"
        ${pkgs.rsync}/bin/rsync -ar --delete-after "''${targets[@]}" "/usr/share/$x"
      else
        rm -rf "/usr/share/$x"
      fi
    done
  '';
}
