{ pkgs, ... }: {
  # TODO : Maybe auto run proton-rs?
  # home.packages = with pkgs; [
  #   protonup-rs
  # ];

  home.persistence."/persist/home/racci" = {
    directories = [ ".local/share/Steam" ];
  };
}