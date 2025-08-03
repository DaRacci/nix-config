{
  config,
  pkgs,
  lib,
  ...
}:
let
  mcpo = with pkgs.python3Packages; toPythonApplication (pkgs.mcpo);
  npx = lib.getExe' pkgs.nodejs "npx";
  uvx = lib.getExe' pkgs.uv "uvx";

  mkNpxServer = package: {
    command = npx;
    args = [
      "-y"
      package
    ];
  };
  mkNpxServerWithArgs =
    package: args:
    let
      base = mkNpxServer package;
    in
    base
    // {
      args = base.args ++ args;
    };

  mkUvxServer = package: {
    command = uvx;
    args = [ package ];
  };
  mkUvxServerWithArgs =
    package: args:
    let
      base = mkUvxServer package;
    in
    base
    // {
      args = base.args ++ args;
    };
in
{
  sops = {
    secrets = {
      "MCP/HASSIO_TOKEN" = { };
      "MCP/GITHUB_TOKEN" = { };
    };

    templates = {
      mcpoConfig = {
        content =
          let
            placeholder = config.sops.placeholder;
          in
          builtins.toJSON {
            mcpServers = {
              memory = mkNpxServer "@modelcontextprotocol/server-memory";
              time = mkUvxServerWithArgs "mcp-server-time" [
                "--local-timezone=${config.time.timeZone}"
              ];
              nixos = mkUvxServer "mcp-nixos";
              context7 = mkNpxServer "@upstash/context7-mcp";
              sequential-thinking = {
                command = lib.getExe pkgs.mcp-sequential-thinking;
              };
              git = mkUvxServer "mcp-server-git";
              fetch = mkUvxServer "mcp-server-fetch";
              diff = mkNpxServer "diff-mcp";
              filesystem = mkNpxServerWithArgs "@modelcontextprotocol/server-filesystem" [
                "/var/lib/mcpo/filesystem"
              ];
              hassio = {
                type = "sse";
                url = "https://hassio.racci.dev/mcp_server/sse";
                headers = {
                  Authorization = "Bearer ${placeholder."MCP/HASSIO_TOKEN"}";
                };
              };
              github = {
                type = "streamable-http";
                url = "https://api.githubcopilot.com/mcp";
                headers = {
                  Authorization = "Bearer ${placeholder."MCP/GITHUB_TOKEN"}";
                };
              };
            };
          };
      };
    };
  };

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
      diffutils
      gh
    ];

    serviceConfig = {
      ExecStart = "${lib.getExe mcpo} --config \${CREDENTIALS_DIRECTORY}/config.json --hot-reload";
      WorkingDirectory = "/var/lib/mcpo";
      StateDirectory = "mcpo";
      RuntimeDirectory = "mcpo";
      DynamicUser = true;

      NoNewPrivileges = true;
      ProtectClock = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LoadCredential = [ "config.json:${config.sops.templates.mcpoConfig.path}" ];
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
