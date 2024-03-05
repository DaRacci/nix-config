{ pkgs, ... }: {
  environment.systemPackages = with pkgs.coolercontrol; [
    coolercontrol-gui
  ];

  systemd = {
    packages = with pkgs.coolercontrol; [
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
