{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  hmUsers = builtins.filter (user: (builtins.hasAttr user config.home-manager.users)) (
    builtins.attrNames config.users.users
  );
  hasPackage = pkg: username: builtins.elem pkg config.home-manager.users.${username}.home.packages;
  usersWithPackage = pkg: builtins.filter (username: hasPackage pkg username) hmUsers;
  anyoneHasPackage = pkg: builtins.length (usersWithPackage pkg) > 0;
in
{
  services.gnome.sushi.enable = anyoneHasPackage pkgs.sushi;
  environment.pathsToLink = mkIf (anyoneHasPackage pkgs.nautilus) [ "/share/nautilus-python/extensions" ];

  programs = {
    _1password.enable = anyoneHasPackage pkgs._1password-cli;
    _1password-gui = let
      withPackage = usersWithPackage pkgs._1password-gui;
    in {
      enable = builtins.length withPackage > 0;
      polkitPolicyOwners = withPackage;
    };
  };
}
