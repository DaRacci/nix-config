{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ ./features/cli ];

  home.packages = [ inputs.nix-alien.packages.${pkgs.system}.nix-alien ];

  # nixput = {
  #   enable = false;
  #   keybinds = {
  #     NewLine = "Enter";
  #     NewLineAbove = "Ctrl+Shift+Enter";
  #     NewLineBelow = "Ctrl+Enter";
  #     SelectLine = "Ctrl+L";
  #   };
  # };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      uris = [ "qemu:///system" ];
      autoconnect = [ "qemu:///system" ];
    };
  };

  user.persistence.directories = [ ".config/goa-1.0" ];
}
