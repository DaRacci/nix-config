{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.extras.browser =
    mkEnableOption "headless browser for web scraping and automation";

  config = mkIf (cfg.enable && cfg.extras.browser) {
    services = {
      hermes-agent.environment.LIGHTPANDA_DISABLE_TELEMETRY = "true";
      ai-agent = {
        settings.plugins.enabled = [ "web-browser" ];
        containerPostStart = ''
          BIN_PATH="$HOME/.local/bin"
          EXEC_PATH="$BIN_PATH/lightpanda"
          TEMP_DIR=$(mktemp -d)
          TEMP_FILE="$TEMP_DIR/lightpanda"

          curl -L -o "$TEMP_FILE" https://github.com/lightpanda-io/browser/releases/latest/download/lightpanda-x86_64-linux
          chmod a+x "$TEMP_FILE"

          mkdir -p "$BIN_PATH"
          mv "$TEMP_FILE" "$EXEC_PATH"
          rm -rf "$TEMP_DIR"

          echo "[post-start] lightpanda installed to $EXEC_PATH"
        '';
      };
    };
  };
}
