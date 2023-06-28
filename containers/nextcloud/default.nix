{ pkgs, ... }: {
  containers.nextcloud = {
    inherit (import ../common);

    config = { ... }: {
      services.nextcloud = {
        enable = true;
        hostName = "localhost";
        config.adminpassFile = "${pkgs.writeText "adminpass" "admin"}";
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 80 443 ];
      };

      system.stateVersion = "23.05";
    };
  };
}