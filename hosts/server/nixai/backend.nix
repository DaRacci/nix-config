{
  pkgs,
  ...
}:
{
  # Runs like shit because iGPU ROCM doesn't work
  # Waiting for https://github.com/ollama/ollama/issues/2033 so it can run under vulkan
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
  };
}
