{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ ./features/cli ];

  home.packages = [ inputs.nix-alien.packages.${pkgs.stdenv.hostPlatform.system}.nix-alien ];

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

  user.persistence.directories = [ ".config/goa-1.0" ];

  user.backup.enable = true;
}
