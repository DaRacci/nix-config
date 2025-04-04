{
  osConfig,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.settings =
    lib.mkIf (osConfig.hardware.graphics.manufacturer == "nvidia")
      {
        env = [
          "GBM_BACKEND,nvidia-drm"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "LIBVA_DRIVER_NAME,nvidia"
          "__GL_GSYNC_ALLOWED,1"
          "__GL_VRR_ALLOWED,1"
        ];
      };
}
