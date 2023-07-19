{ config, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl.enable = true;

    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      open = false; # TODO :: Set to true once all features are present!
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
}
