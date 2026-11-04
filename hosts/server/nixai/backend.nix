{
  pkgs,
  ...
}:
{
  services = {
    # Runs like shit because iGPU ROCM doesn't work
    # Waiting for https://github.com/ollama/ollama/issues/2033 so it can run under vulkan
    ollama = {
      enable = true;
      rocmOverrideGfx = "10.3.0";
      loadModels = [
        "gemma3:1b"
        "qwen3:1.7b"
        "nomic-embed-text-v2-moe:latest"
      ];
      environmentVariables = {
        HCC_AMDGPU_TARGET = "gfx1031";
        OLLAMA_KEEP_ALIVE = "-1";
        OLLAMA_MAX_LOADED_MODELS = "2";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_VULKAN = "1";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];
}
