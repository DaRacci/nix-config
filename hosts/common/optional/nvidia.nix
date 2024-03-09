{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ nvtop ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl.enable = true;

    nvidia = {
      # package = config.boot.kernelPackages.nvidiaPackages.stable;
      open = true;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      modesetting.enable = true;
      forceFullCompositionPipeline = true;
      powerManagement = {
        enable = true;
      };
    };
  };

  boot.kernelParams = [ "nvidia.NVreg_EnableResizableBar=1" "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];
}
