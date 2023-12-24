{ config, ... }:
let
  hmUsers = builtins.filter (user: (builtins.hasAttr user config.home-manager.users)) (builtins.attrNames config.users.users);
  hasPackage = pkg: username: builtins.elem pkg config.home-manager.users.${username}.home.packages;
  usersWithPackage = pkg: builtins.filter (username: hasPackage pkg username) hmUsers;

  opGuiUsers = builtins.length (usersWithPackage "_1password-gui");
  opCliUsers = builtins.length (usersWithPackage "_1password");
in
{
  programs._1password.enable = opCliUsers > 0;
  programs._1password-gui = {
    enable = opGuiUsers > 0;
    polkitPolicyOwners = (builtins.attrNames config.users.users);
  };
}
