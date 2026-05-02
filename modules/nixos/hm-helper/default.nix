{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkOption
    mkEnableOption
    types
    ;
  inherit (types) listOf str;
  inherit (builtins)
    attrNames
    attrValues
    elem
    filter
    length
    ;

  hmConfigUsers = config.home-manager.users or { };
  nixosUsers = config.users.users or { };

  hmUserAttrs = attrValues hmConfigUsers;
  hmUsers = filter (user: hmConfigUsers ? ${user}) (attrNames nixosUsers);
  hasPackage = pkg: username: elem pkg hmConfigUsers.${username}.home.packages;
  usersWithPackage = pkg: filter (username: hasPackage pkg username) hmUsers;

  anyoneHasPackage = pkg: length (usersWithPackage pkg) > 0;
  anyoneHasOption = userFilter: length (filter userFilter hmUserAttrs) > 0;

  importWithExtras = path: {
    _file = toString path;
    imports = [
      (import path {
        inherit
          hasPackage
          usersWithPackage
          anyoneHasPackage
          anyoneHasOption
          ;
      })
    ];
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

    hmUsers = mkOption {
      type = listOf str;
      default = hmUsers;
      readOnly = true;
      description = "List of Home Manager users that also exist in config.users.users.";

    };
  };
}
