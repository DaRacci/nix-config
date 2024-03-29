{ config, pkgs, ... }: {
  home.packages = [ config.services.easyeffects.package ];

  services.easyeffects = {
    enable = true;
    package = pkgs.easyeffects;
  };

  # home.file.".config/pipewire/pipewire.conf.d/99-noise-suppression.conf".text = ''
  #   context.modules = [{
  #     name = libpipewire-module-filter-chain
  #     args = {
  #       node.description =  "Noise Canceling source"
  #       media.name =  "Noise Canceling source"
  #       filter.graph = {
  #         nodes = [{
  #           type = ladspa
  #           name = rnnoise
  #           plugin = ${pkgs.noise-supression}/lib/ladspa/librnnoise_ladspa.so
  #           label = noise_suppressor_stereo
  #           control = {
  #             "VAD Threshold (%)" 50.0
  #             "VAD Grace Period (ms)" 200
  #             "Retroactive VAD Grace (ms)" 0
  #           }
  #         }]
  #       }
  #       capture.props = {
  #         node.name =  "capture.rnnoise_source"
  #         node.passive = true
  #         audio.rate = 48000
  #       }
  #       playback.props = {
  #         node.name =  "rnnoise_source"
  #         media.class = Audio/Source
  #         audio.rate = 48000
  #       }
  #     }
  #   }]
  # '';

  user.persistence.directories = [
    ".config/easyeffects"
  ];
}
