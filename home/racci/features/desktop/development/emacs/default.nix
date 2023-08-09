{ pkgs, inputs, ... }: {
  imports = [ inputs.nix-doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    doomPrivateDir = ./doom.d;

    emacsPackage = pkgs.emacs;
    extraPackages = with pkgs; [
      # Grammer & Spell Checking
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
      # (with fenix.packages.${system}; combine [
      #   targets.${system}.latest.rust-std
      #   (complete.withComponents [
      #     "rust-src"
      #     "rust-analyzer"
      #     "clippy-preview"
      #     "rustfmt-preview"
      #   ])
      # ])
    ];
  };

  services.emacs.enable = true;
}
