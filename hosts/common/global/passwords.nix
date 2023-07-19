{ config, ... }: {
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Allow all users to use polkit for 1Password;
    polkitPolicyOwners = (builtins.attrNames config.users.users);
  };
}
