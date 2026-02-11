{
  anyoneHasPackage,
  usersWithPackage,
  ...
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkEnableOption
    literalExpression
    ;

  cfg = config.custom.hm-helper;
  opCfg = cfg._1password;
in
{
  options.custom.hm-helper._1password = {
    enableGUI = mkEnableOption "Enable 1Password GUI support" // {
      default = anyoneHasPackage pkgs._1password-gui;
      defaultText = literalExpression "anyoneHasPackage pkgs._1password-gui";
    };
    enableCli = mkEnableOption "Enable 1Password Cli support" // {
      default = anyoneHasPackage pkgs._1password-cli;
      defaultText = literalExpression "anyoneHasPackage pkgs._1password-cli";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf opCfg.enableCli {
      programs._1password.enable = true;
    })

    (mkIf opCfg.enableGUI {
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = usersWithPackage pkgs._1password-gui;
      };

      environment.etc."1password/custom_allowed_browsers" = {
        mode = "755";
        text = ''
          floorp
        '';
      };
    })
  ]);
}
