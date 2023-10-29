{ config, ... }: {
  programs._1password.enable = true; # TODO - Only enable if a user has 1Password installed;
  programs._1password-gui = {
    enable = true; # TODO - Only enable if a user has 1Password installed;
    # Allow all users to use polkit for 1Password;
    polkitPolicyOwners = (builtins.attrNames config.users.users);
  };
}
