{
  config,
  ...
}:
let
  hmUserAttrs = builtins.attrValues config.home-manager.users;
  hmUsers = builtins.filter (user: (builtins.hasAttr user config.home-manager.users)) (
    builtins.attrNames config.users.users
  );
  hasPackage = pkg: username: builtins.elem pkg config.home-manager.users.${username}.home.packages;
  usersWithPackage = pkg: builtins.filter (username: hasPackage pkg username) hmUsers;
  anyoneHasPackage = pkg: builtins.length (usersWithPackage pkg) > 0;
  anyoneHasOption = userFilter: builtins.length (builtins.filter userFilter hmUserAttrs) > 0;

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
}
