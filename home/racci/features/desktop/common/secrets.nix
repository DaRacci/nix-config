{ pkgs, ... }: {
  home.packages = with pkgs; [
    gnome-secrets
    _1password-gui
    _1password
  ];

  user.persistence = {
    directories = [
      ".config/1Password/settings"
    ];

    files = [
      ".config/1Password/1password.sqlite"
    ];
  };
}
