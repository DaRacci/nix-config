{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  inherit (types) int str;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.voice = {
    enable = mkEnableOption "voice input and output using the TTS and STT";

    wyoming-stt = {
      enable = mkEnableOption "use existing Wyoming faster-whisper server for STT instead of running a separate Whisper instance";

      host = mkOption {
        type = str;
        default = "localhost";
        description = "The host of the Wyoming faster-whisper server.";
      };

      port = mkOption {
        type = int;
        default = 10300;
        description = "The port of the Wyoming faster-whisper server.";
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && cfg.voice.enable) {
      services.ai-agent.settings = {
        voice.auto_tts = false;

        stt = {
          provider = "local";
          local.model = "large-v3";
        };

        tts = {
          provider = "neutts";
          neutts = {
            ref_audio = "";
            ref_text = "";
            model = "neuphonic/neutts-air-q4-gguf";
            device = "gpu";
          };
        };
      };
    })

    (mkIf (cfg.enable && cfg.voice.enable && cfg.voice.wyoming-stt.enable) {
      services.hermes-agent = {
        environment = {
          HERMES_LOCAL_STT_COMMAND =
            let
              cmd = "${
                inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wyoming-transcribe-client
              }/bin/wyoming-transcribe";
            in
            "${cmd} {input_path} --output-dir {output_dir} --model {model} --language {language} --host ${cfg.voice.wyoming-stt.host} --port ${toString cfg.voice.wyoming-stt.port}";
        };
      };
    })
  ];
}
