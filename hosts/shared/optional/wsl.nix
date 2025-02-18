{
  config,
  pkgs,
  lib,
  ...
}:
with builtins;
with lib;
let
  user = "racci";
in
{
  wsl = {
    enable = true;
    defaultUser = user;
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

  users.allowNoPasswordLogin = true;

  environment.systemPackages = with pkgs; [ wslu ];

  programs.nix-ld = {
    enable = true;
    libraries = [
      # Required by NodeJS installed by VS Code's Remote WSL extension
      pkgs.stdenv.cc.cc
    ];
  };

  # Fixes Home-Manager applications not appearing in Start Menu
  system.activationScripts.copy-user-launchers = stringAfter [ ] ''
    for x in applications icons; do
      echo "setting up /usr/share/''${x}..."
      targets=()
      if [[ -d "/etc/profiles/per-user/${config.wsl.defaultUser}/share/$x" ]]; then
        targets+=("/etc/profiles/per-user/${config.wsl.defaultUser}/share/$x/.")
      fi

      if (( ''${#targets[@]} != 0 )); then
        mkdir -p "/usr/share/$x"
        ${pkgs.rsync}/bin/rsync -ar --delete-after "''${targets[@]}" "/usr/share/$x"
      else
        rm -rf "/usr/share/$x"
      fi
    done
  '';

  virtualisation.docker.enableNvidia = mkForce false;
}
