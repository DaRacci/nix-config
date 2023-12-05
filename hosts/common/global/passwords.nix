{ config, ... }:
let
  opGuiUsers = builtins.length (builtins.map (user: builtins.elem "_1password-gui" user.home-manager.programs) (builtins.attrValues config.users.users));
  opCliUsers = builtins.length (builtins.map (user: builtins.elem "_1password" user.home-manager.programs) (builtins.attrValues config.users.users));
in
{
  programs._1password.enable = opCliUsers > 0;
  programs._1password-gui = {
    enable = opGuiUsers > 0;
    polkitPolicyOwners = (builtins.attrNames config.users.users);
  };
}
