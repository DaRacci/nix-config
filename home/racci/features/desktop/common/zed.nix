{ pkgs, ... }: {
  programs.zed-editor = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      nil
      shellcheck
      shfmt
    ];
  };

  user.persistence.directories = [
    ".config/zed"
    ".local/share/zed"
    ".config/github-copilot" # Contains the copilot auth token
  ];
}
