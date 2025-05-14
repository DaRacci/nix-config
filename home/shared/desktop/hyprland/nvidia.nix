{
  osConfig,
  config,
  lib,
  ...
}:
{
  xdg.configFile."uwsm/env".text = lib.mkIf osConfig.hardware.graphics.hasNvidia (
    config.lib.shell.exportAll {
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      LIBVA_DRIVER_NAME = "nvidia";
      __GL_GSYNC_ALLOWED = 1;
      __GL_VRR_ALLOWED = 1;
    }
  );
}
