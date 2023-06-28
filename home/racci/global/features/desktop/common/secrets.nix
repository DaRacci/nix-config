{ pkgs, ...}: {
  home.packages = with pkgs; [
    gnome-secrets
  ];

  home.persistence."/persist/home/racci" = {
    directories = [
      ".config/1Password/settings"
    ];

    files = [
      ".config/1Password/1password.sqlite"
    ];
  };
}