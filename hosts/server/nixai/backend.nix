{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  mcpo = with pkgs.python3Packages; toPythonApplication (callPackage inputs.mcpo { });
  npx = lib.getExe' pkgs.nodejs "npx";
  uvx = lib.getExe' pkgs.uv "uvx";

  mcpoConfig = pkgs.writers.writeJSON "mcpo-config" {
    mcpServers = {
      memory = {
        command = npx;
        args = [
          "-y"
          "@modelcontextprotocol/server-memory"
        ];
      };
      time = {
        command = uvx;
        args = [
          "mcp-server-time"
          "--local-timezone=${config.time.timeZone}"
        ];
      };
      nixos = {
        command = uvx;
        args = [ "mcp-nixos" ];
      };
      context7 = {
        command = npx;
        args = [
          "-y"
          "@upstash/context7-mcp"
        ];
      };
    };
  };
in
{
  # Runs like shit because iGPU ROCM doesn't work
  # Waiting for https://github.com/ollama/ollama/issues/2033 so it can run under vulkan
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    loadModels = [
      "gemma3n:e4b"
    ];
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "-1";
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_FLASH_ATTENTION = "1";
    };
  };

  systemd.services.mcpo = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      HOME = "/var/lib/mcpo";
    };

    path = with pkgs; [
      bash
      nodejs
      uv
      git
    ];

    serviceConfig = {
      ExecStart = "${lib.getExe mcpo} --config ${mcpoConfig}";
      WorkingDirectory = "/var/lib/mcpo";
      StateDirectory = "mcpo";
      RuntimeDirectory = "mcpo";
      DynamicUser = true;
    };
  };

  server.proxy.virtualHosts.mcpo = {
    ports = [ 8000 ];
    extraConfig = ''
      rewrite {
        if {path} is /
        to /docs
      }

      reverse_proxy http://localhost:8000
    '';
  };
}
