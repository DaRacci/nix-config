{ inputs, lib, config, outputs, pkgs, ... }:

let
  colourScheme = inputs.nix-colours.colorSchemes.onedark;
in {
  imports = [
    #? TODO :: Globalise
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-colours.homeManagerModules.default
    ./nix.nix
    ./features/cli
    ./features/daemons
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # TODO :: Globalise?
  programs.home-manager.enable = true;
  programs.git.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home = {
    username = lib.mkDefault "racci";
    homeDirectory = lib.mkDefault "/home/racci";
    stateVersion = lib.mkDefault "23.05";
    sessionPath = [ "$HOME/.local/bin" ];

    persistence."/persist/home/racci" = {
      directories = [
        "Documents"
        "Downloads"
        "Pictures"
        "Videos"
        "Music"
        "Templates"
        ".local/share/keyrings"
      ];

      allowOther = true;
    };

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

  colorscheme = lib.mkDefault colourScheme;
}
