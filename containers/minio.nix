# { containers, ... }:
# let
#   image = "";
#   dataDir = "${containers.storage.dataDir}/minio";

# in rec {
#   virtualisation.oci-containers.containers.minio = {
#     user = "1000:1000";
#     image = "${image}";

#     dependsOn = lib.mkIf containers.reverse-proxy.enable [
#       "reverse-proxy"
#     ];

#     volumes = [
#       "${dataDir}:/data"
#     ];
#   }
# }
let
  dataDir = "/persist/container/minio/data";
  configDir = "/persist/container/minio/config";
  hostAddress = "10.100.100.2";
in rec {
  system.activationScripts.minio = ''
  mkdir -p ${dataDir}
  mkdir -p ${configDir}
  chown -R 280:280 ${dataDir}
  chown -R 280:280 ${configDir}
  '';

  containers.minio = {
    autoStart = true;
    ephemeral = true;

    # privateNetwork = true;
    # inherit hostAddress;
    # localAddress = "${hostAddress}";
    
    forwardPorts = [
      {
        protocol = "tcp";
        hostPort = 9000;
        containerPort = 9000;
      }
      {
        protocol = "tcp";
        hostPort = 9001;
        containerPort = 9001;
      }
    ];

    bindMounts = {
      "/var/lib/minio/data" = {
        hostPath = dataDir;
        isReadOnly = false;
      };
      "/var/lib/minio/config" = {
        hostPath = configDir;
        isReadOnly = false;
      };
    };

    config = { config, pkgs, ... }: {
      services.minio = {
        enable = true;
        package = pkgs.minio;
      };

      networking.firewall.allowedTCPPorts = [ 9000 9001 ];

      system.stateVersion = "23.05";
    };
  };
}