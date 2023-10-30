{ config, pkgs, lib, ... }: with builtins; with lib; {
  wsl.enable = true;
  wsl.defaultUser = "racci";
  wsl.startMenuLaunchers = true;
  wsl.nativeSystemd = true;
  users.allowNoPasswordLogin = true;

  wsl.wslConf.interop.enabled = true;
  wsl.wslConf.interop.appendWindowsPath = true;

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
