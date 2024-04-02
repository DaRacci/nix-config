{ config, pkgs, ... }:
let
  hmUsers = builtins.filter (user: (builtins.hasAttr user config.home-manager.users)) (builtins.attrNames config.users.users);
  hasPackage = pkg: username: builtins.elem pkg config.home-manager.users.${username}.home.packages;
  usersWithPackage = pkg: builtins.filter (username: hasPackage pkg username) hmUsers;

  opGuiUsers = usersWithPackage pkgs._1password-gui;
  opCliUsers = usersWithPackage pkgs._1password;
in
{
  programs._1password.enable = (builtins.length opCliUsers) > 0;
  programs._1password-gui = {
    enable = (builtins.length opGuiUsers) > 0;
    polkitPolicyOwners = opGuiUsers;
  };
}
