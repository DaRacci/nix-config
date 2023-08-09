{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ gwe nvtop ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl.enable = true;

    nvidia = {
      # package = config.boot.kernelPackages.nvidiaPackages.stable;
      open = true; # TODO :: Set to true once all features are present!
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      modesetting.enable = true;
      forceFullCompositionPipeline = true;
      powerManagement = {
        enable = true;
        # finegrained = true;
      };
    };
  };

  boot.kernelParams = [ "nvidia.NVreg_EnableResizableBar=1" ];
}
