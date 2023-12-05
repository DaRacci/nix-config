{ pkgs, ... }: {
  home.packages = with pkgs; [
    gnome-secrets
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
