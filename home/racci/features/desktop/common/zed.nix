{ pkgs, ... }: {
  programs.zed-editor = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      nil
      shellcheck
      shfmt
      nerd-fonts.jetbrains-mono
    ];

    # TODO - Define config here, until then doing it inside zed so i can quickly revise it.
  };

  user.persistence.directories = [
    ".config/zed"
    ".local/share/zed"
    ".config/github-copilot" # Contains the copilot auth token
  ];
}
