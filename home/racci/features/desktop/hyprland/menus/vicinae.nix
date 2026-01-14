{
  inputs,
  ...
}:
{
  imports = [ inputs.vicinae.homeManagerModules.default ];

  services.vicinae = {
    enable = true;
    systemd.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    layerrule = [
      "blur, vicinae"
      "ignorealpha 0, vicinae"
    ];
    bind = [
      "CTRL_ALT, SPACE, exec, vicinae toggle"
      "SUPER, V, exec, vicinae vicinae://extensions/vicinae/clipboard/history"
    ];
  };

  user.persistence.directories = [
    ".config/vicinae"
    ".local/share/vicinae"
  ];
}
