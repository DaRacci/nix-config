{ pkgs, ... }: let coolercontrol = pkgs.unstable.coolercontrol; in {
  environment.systemPackages = with coolercontrol; [
    coolercontrol-gui
  ];

  systemd = {
    packages = with coolercontrol; [
      coolercontrol-liqctld
      coolercontrold
    ];
    services = {
      coolercontrol-liqctld.wantedBy = [ "multi-user.target" ];
      coolercontrold.wantedBy = [ "multi-user.target" ];
    };
  };

  host.persistence.directories = [
    "/etc/coolercontrol"
  ];
}
