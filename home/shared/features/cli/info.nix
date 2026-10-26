{
  osConfig ? null,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs)
    hyfetch
    inxi
    lsof
    pciutils
    xdpyinfo
    ;
in
lib.mkIf (osConfig == null || osConfig.host.device.role != "server") {
  home.packages = [
    # Processes Info
    lsof

    # System Info
    inxi
    pciutils
    xdpyinfo
    hyfetch
  ];
}
