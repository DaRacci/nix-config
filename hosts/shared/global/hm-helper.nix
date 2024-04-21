{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf;

  hmUsers = builtins.filter (user: (builtins.hasAttr user config.home-manager.users)) (builtins.attrNames config.users.users);
  hasPackage = pkg: username: builtins.elem pkg config.home-manager.users.${username}.home.packages;
  usersWithPackage = pkg: builtins.filter (username: hasPackage pkg username) hmUsers;
  anyoneHasPackage = pkg: builtins.length (usersWithPackage pkg) > 0;

  enableSushi = anyoneHasPackage pkgs.gnome.sushi;
  enableNautilus = anyoneHasPackage pkgs.gnome.nautilus;
in
{
  services.gnome.sushi.enable = enableSushi;
  environment.pathsToLink = mkIf enableNautilus [
    "/share/nautilus-python/extensions"
  ];
}
