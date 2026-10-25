{
  lib,
  ...
}:
let
  inherit (lib) mkForce;
in
{
  purpose.development.editors.zed.enable = true;
  programs.zed-editor.userSettings = {
    theme = mkForce "Tokyo Night";
    ui_font_size = mkForce 24;

    icon_theme = {
      mode = "dark";
      dark = "Catppuccin Latte";
      light = "Catppuccin Mocha";
    };

    language_models = {
      ollama.api_url = "http://localhost:11434";
    };

    edit_predictions.ollama = {
      max_output_tokens = 256;
      prompt_format = "zeta2";
      api_url = "http://localhost:11434";
      model = "hf.co/bluevoid-pl/zeta2-GUFF:Q8_0";
    };

    agent_servers = {
      Hermes = {
        type = "custom";
        command = "ssh";
        args = [
          "-p2222"
          "-T"
          "-o"
          "BatchMode=yes"
          "hermes@nixai"
          "HERMES_HOME=/data/.hermes exec hermes -p coder acp"
        ];
      };
    };
  };
}
