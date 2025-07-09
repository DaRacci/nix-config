{
  osConfig,
  pkgs,
  lib,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      ctop
      iotop-c
      sysstat
    ]
    ++ lib.optionals osConfig.hardware.graphics.hasAcceleration [
      nvtopPackages.full
    ];

  programs = {
    btop = {
      enable = true;
      package = pkgs.btop;
      settings = {
        update_ms = 300;
        proc_per_core = true;
        proc_info_smaps = true;
        proc_filter_kernel = true;
        use_fstab = false;
        swap_disk = false;
        io_mode = true;
      };
    };

    bottom = {
      enable = true;
      package = pkgs.bottom;
      settings = { };
    };
  };
}
