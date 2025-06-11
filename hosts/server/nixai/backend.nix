{
  pkgs,
  ...
}:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
  };
}
