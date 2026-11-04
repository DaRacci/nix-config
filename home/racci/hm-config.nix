{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = [
    inputs.nix-alien.packages.${pkgs.stdenv.hostPlatform.system}.nix-alien
  ];

  sops.secrets.LOCATION = { };

  # nixput = {
  #   enable = false;
  #   keybinds = {
  #     NewLine = "Enter";
  #     NewLineAbove = "Ctrl+Shift+Enter";
  #     NewLineBelow = "Ctrl+Enter";
  #     SelectLine = "Ctrl+L";
  #   };
  # };

  core.profile = {
    avatar.path = "/home/racci/.face";
    wallpaper.directory = "/home/racci/Pictures/Wallpapers";
    location.secret = "LOCATION";
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      uris = [ "qemu:///system" ];
      autoconnect = [ "qemu:///system" ];
    };
  };

  programs.gh-dash.settings.repoPaths = {
    "DaRacci/nix-config" = "/persist/nix-config";
    "DaRacci/*" = "~/Projects/Coding/*";
    "AMTSupport/*" = "~/Projects/Coding/AMT/*";
    "NixOS/*" = "~/Projects/Coding/nix/*";
  };

  purpose.development.vcs.user.email = "me@racci.dev";

  user.persistence.directories = [ ".config/goa-1.0" ];

  user.backup.enable = true;
}
