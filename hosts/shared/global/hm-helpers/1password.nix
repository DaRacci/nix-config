{
  anyoneHasPackage,
  usersWithPackage,
  ...
}:
{
  pkgs,
  lib,
  ...
}:
{
  programs = {
    _1password.enable = anyoneHasPackage pkgs._1password-cli;
    _1password-gui =
      let
        withPackage = usersWithPackage pkgs._1password-gui;
      in
      {
        enable = builtins.length withPackage > 0;
        polkitPolicyOwners = withPackage;
      };
  };

  environment.etc."1password/custom_allowed_browsers" =
    lib.mkIf (anyoneHasPackage pkgs._1password-gui)
      {
        mode = "755";
        text = ''
          floorp
        '';
      };
}
