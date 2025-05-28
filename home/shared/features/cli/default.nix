{ pkgs, ... }:
{
  imports = [
    ./atuin.nix
    ./bat.nix
    ./carapace.nix
    ./direnv.nix
    ./files.nix
    ./fish.nix
    ./info.nix
    ./micro.nix
    ./nushell.nix
    ./ripgrep.nix
    ./starship.nix
    ./sys.nix
    ./zoxide.nix
  ];

  programs.bash = {
    enable = true;
    profileExtra = ''
      PROFILE_D_ROOTS=("''${HOME}" ''${NIX_PROFILES[@]})

      for profile in "''${PROFILE_D_ROOTS[@]}"; do
        if [ -d "$profile/etc/profile.d" ]; then
          for i in "$profile/etc/profile.d/"*.sh; do
            if [ -r "$i" ]; then
              . "$i"
            fi
          done
        fi
      done
    '';
  };

  home.packages = with pkgs; [
    fd
    du-dust
    duf
    procs
    doggo
  ];
}
