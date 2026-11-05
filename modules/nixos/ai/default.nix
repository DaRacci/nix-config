_: {
  imports = [
    (import ../../fragments/ai/default.nix { })
    ./agents
    ./services
  ];
}
