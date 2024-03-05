{ config, ... }:
let
  persistDir = "/persist/container/minio/data";
  image = "minio/minio:latest";
in
rec {
  services.minio = {
    # inherit (import ../common);

    service = {
      inherit image;

      volumes = [ "${persistDir}:/data" ];

      expose = [ "9000" "9001" ];
      command = ''server --console-address ":9001" https://s3.home/data'';

      healthcheck = {
        test = [ "CMD" "curl" "-f" "http://localhost:9000/minio/health/live" ];
        interval = "30s";
        timeout = "20s";
        retries = 3;
      };
      # environment = {
      #   MINIO_ROOT_USER = "admin";
      #   MINIO_ROOT_PASSWORD = "admin"; # TODO :: generate random password
      # };
    };
  };
}
