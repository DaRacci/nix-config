{
  osConfig ? null,
  pkgs,
  lib,
  ...
}:
lib.mkIf (osConfig == null || osConfig.host.device.role != "server") {
  home.packages = with pkgs; [
    # Processes Info
    lsof

    # System Info
    inxi
    pciutils
    xorg.xdpyinfo
    hyfetch
  ];
}
