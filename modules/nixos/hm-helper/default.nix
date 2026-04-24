{
  config,
  lib,
  ...
}:
let
  inherit (lib) literalExpression mkEnableOption;
  inherit (builtins)
    attrNames
    attrValues
    elem
    filter
    length
    ;

  hmUserAttrs = attrValues config.home-manager.users;
  hmUsers = filter (user: elem user (attrNames config.home-manager.users)) (
    attrNames config.users.users
  );

  hasPackage = pkg: username: elem pkg config.home-manager.users.${username}.home.packages;
  usersWithPackage = pkg: filter (username: hasPackage pkg username) hmUsers;
  anyoneHasPackage = pkg: length (usersWithPackage pkg) > 0;
  anyoneHasOption = userFilter: length (filter userFilter hmUserAttrs) > 0;

  importWithExtras =
    path:
    import path {
      inherit
        hasPackage
        usersWithPackage
        anyoneHasPackage
        anyoneHasOption
        ;
    };
in
{
  imports = [
    (importWithExtras ./1password.nix)
    (importWithExtras ./kde-connect.nix)
    (importWithExtras ./mpv.nix)
    (importWithExtras ./nautilus.nix)
  ];

  options.core.hm-helper = {
    enable = mkEnableOption "Home Manager helper functions" // {
      default = config ? home-manager;
      defaultText = literalExpression "config ? home-manager";
    };
  };
}
