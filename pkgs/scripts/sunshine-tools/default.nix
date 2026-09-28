{
  writeShellApplication,
  hyprland,
  iproute2,
  jq,
  symlinkJoin,
  systemd,
}:
let
  proxyScript = writeShellApplication {
    name = "sunshine-proxy-wrapper";
    runtimeInputs = [
      iproute2
      systemd
    ];
    text = builtins.readFile ./sunshine-proxy-wrapper.sh;
  };

  disableMonitorsScript = writeShellApplication {
    name = "hyprland-disable-other-monitors-pre-sunshine";
    runtimeInputs = [
      hyprland
      jq
    ];
    text = builtins.readFile ./hyprland-disable-other-monitors-pre-sunshine.sh;
  };

  restoreMonitorsScript = writeShellApplication {
    name = "hyprland-restore-disabled-monitors-post-sunshine";
    runtimeInputs = [
      hyprland
      jq
    ];
    text = builtins.readFile ./hyprland-restore-disabled-monitors-post-sunshine.sh;
  };
in
symlinkJoin {
  name = "sunshine-tools";
  paths = [
    proxyScript
    disableMonitorsScript
    restoreMonitorsScript
  ];
}
