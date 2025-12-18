_: {
  imports = [
    ./backend.nix
    ./voice.nix
    ./web.nix
  ];

  server.dashboard = {
    name = "NixAI";
    icon = "sh-ollama";
  };
}
