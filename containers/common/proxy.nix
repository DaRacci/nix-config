_: {
  service = {
    dependsOn = [ "caddy" ];
    networks = [ "proxy" ];
  };
}
