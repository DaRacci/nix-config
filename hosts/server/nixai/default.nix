{
  config,
  ...
}:
{
  imports = [
    ./backend.nix
    ./voice.nix
    ./web.nix
  ];

  server.proxy.virtualHosts = {
    ai.extraConfig = ''
      reverse_proxy http://${config.services.open-webui.host}:${toString config.services.open-webui.port}
    '';
  };
}
