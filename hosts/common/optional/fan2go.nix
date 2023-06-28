{ pkgs, lib, ... }: {
  boot.kernelModules = [ "nct6775" ];

  environment.systemPackages = with pkgs; [
    fan2go
    lm_sensors
  ];

  systemd.services.fan2god = {
    description = "Fan2Go Daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      LimitNOFILE = 8192;
      ExecStart = "${pkgs.fan2go}/bin/fan2go -c /etc/fan2go/fan2go.yaml --no-style";
      Restart = "always";
      RestartSec = "1s";
      StandardOutput = "null";
    };
    environment = {
      PATH = lib.mkForce "${pkgs.procps}/bin";
    };
  };

  environment.persistence."/persist".directories = [
    "/etc/fan2go"
  ];
}