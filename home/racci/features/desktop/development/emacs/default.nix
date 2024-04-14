{ config, pkgs, inputs, ... }: {
  imports = [ inputs.nix-doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    doomPrivateDir = ./doom.d;

    emacsPackage = pkgs.emacs-gtk;

    extraPackages = with pkgs; [
      # Grammar & Spell Checking
      (aspellWithDicts
        (dicts: with dicts; [ en en-computers en-science ]))
      languagetool

      # Forgot
      ripgrep
      sqlite
      wordnet

      # Language Support
      gdtoolkit
      gopls
      gore
      texlive.combined.scheme-medium
      (with inputs.fenix.packages.${builtins.currentSystem}; combine [
        (complete.withComponents [
          "rust-src"
          "rust-analyzer"
          "clippy-preview"
          "rustfmt-preview"
        ])
      ])
    ] ++ (builtins.map (profile: profile.package) (with config.fontProfiles; [ monospace regular emoji ]));

    extraConfig =
      let inherit (config.fontProfiles) monospace regular emoji;
      in ''
        (setq doom-font (font-spec :family "${monospace.family}" :size ${builtins.toString monospace.size} :style 'regular)
              doom-big-font (font-spec :family "${monospace.family}" :size ${builtins.toString (monospace.size + 6)} :style 'regular)
              doom-variable-pitch-font (font-spec :family "${regular.family}" :size ${builtins.toString regular.size} :style 'regular))

        (setq emojify-emoji-set "${emoji.family}")
      '';
  };

  services.emacs.enable = true;

  user.persistence = {
    files = [
      # Undo/Redo History
      ".local/share/doom/transient/history"
      # Saved Projects
      ".cache/doom/projectile.projects"
    ];

    directories = [ ".cache/doom/autosaves" ];
  };
}
