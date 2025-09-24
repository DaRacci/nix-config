{
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets = {
    "MCP/API_TOKEN" = { };
    "MCP/PROTON_USER" = { };
    "MCP/PROTON_PASS" = { };
  };

  services.mcpo =
    let
      inherit (config.sops) placeholder;
    in
    {
      enable = true;
      apiTokenFile = config.sops.secrets."MCP/API_TOKEN".path;

      environment = {
        BRIDGE_IMAP_HOST = "127.0.0.1";
        BRIDGE_IMAP_PORT = "1143";
        BRIDGE_SMTP_HOST = "127.0.0.1";
        BRIDGE_SMTP_PORT = "1025";
        PROTON_EMAIL = placeholder."MCP/PROTON_USER";
        PROTON_BRIDGE_PASSWORD = placeholder."MCP/PROTON_PASS";
      };

      configuration =
        let
          inherit (config.services.mcpo) helpers;
        in
        {
          proton-mcp.command = lib.getExe pkgs.proton-mcp;
          desktop-commander = helpers.npxServer "@wonderwhy-er/desktop-commander@latest";
        };
    };

  user.persistence.directories = [
    ".claude-server-commander"
  ];
}
