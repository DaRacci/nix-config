_: {
  imports = [
    ./ai-agent.nix
    ./backend.nix
    ./mnemosyne.nix
    ./voice.nix
    ./web.nix
  ];

  server.dashboard = {
    name = "NixAI";
    icon = "sh-ollama";
  };
}
