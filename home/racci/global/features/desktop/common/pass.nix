{ pkgs, ...}: {
  # home.packages = with pkgs; [
  #   _1password-gui
  # ];

  home.persistence."/persist/home/racci" = {
    directories = [
      ".config/1Password/settings"
    ];

    files = [
      # TODO Is this the corrent item?
      ".config/1Password/1password.sqlite"
    ];
  };
}