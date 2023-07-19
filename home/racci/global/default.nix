{ config, inputs, lib, pkgs, modulesPath, ... }:

let
  colourScheme = inputs.nix-colours.colorSchemes.onedark;
  inherit (config.home) username;
in
{
  imports = [
    (modulesPath + "/home/${username}/features/cli")
    (modulesPath + /home/${username}/features/daemons)
  ];

  home = {
    file.".colorscheme".text = colourScheme.slug;

    # TODO :: Can i do this globally?
    file.".config/pipewire/pipewire.conf.d/99-noise-suppression.conf".text = ''
          context.modules = [
      {   name = libpipewire-module-filter-chain
          args = {
              node.description =  "Noise Canceling source"
              media.name =  "Noise Canceling source"
              filter.graph = {
                  nodes = [
                      {
                          type = ladspa
                          name = rnnoise
                          plugin = ${pkgs.noise-supression}/lib/ladspa/librnnoise_ladspa.so
                          label = noise_suppressor_stereo
                          control = {
                              "VAD Threshold (%)" 50.0
                              "VAD Grace Period (ms)" 200
                              "Retroactive VAD Grace (ms)" 0
                          }
                      }
                  ]
              }
              capture.props = {
                  node.name =  "capture.rnnoise_source"
                  node.passive = true
                  audio.rate = 48000
              }
              playback.props = {
                  node.name =  "rnnoise_source"
                  media.class = Audio/Source
                  audio.rate = 48000
              }
          }
      }
      ]
    '';
  };

  colorscheme = lib.mkDefault
    colourScheme;
}
