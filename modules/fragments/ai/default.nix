{
  optionPath ? [ "ai" ],
}:
{
  imports = [
    (import ./aliases.nix { optionPath = optionPath ++ [ "aliases" ]; })
    (import ./models/default.nix { optionPath = optionPath ++ [ "models" ]; })
  ];
}
