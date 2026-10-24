_: {
  imports = [
    ./ai-agent.nix
    ./backend.nix
    ./mnemosyne.nix
    ./voice.nix
  ];

  server.sshGuard.endpoints = [
    "http://127.0.0.1:11434/api/version"
    "http://127.0.0.1:11434/api/ps"
    "http://127.0.0.1:11434/api/tags"
  ];

  server.dashboard = {
    name = "NixAI";
    icon = "sh-ollama";
  };
}
