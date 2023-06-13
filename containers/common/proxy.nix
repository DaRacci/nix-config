{ lib, ... }: {
  service = {
    dependsOn = [ "caddy" ];
    networks = [ "proxy" ];
  };
}