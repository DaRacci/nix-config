{
  config,
  lib,
  ...
}:
let
  cfg = config.purpose;
in
{
  imports = [
    ./printing.nix
  ];

  options.purpose.diy = {
    enable = lib.mkEnableOption "diy";
  };

  config = lib.mkIf cfg.diy.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = ''
          You have enabled diy but not the purpose module itself, which is required.
          Ensure that `purpose.enable` is set to true.
        '';
      }
    ];
  };
}
