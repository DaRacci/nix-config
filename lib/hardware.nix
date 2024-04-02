{ lib }: {
  /*
    Check if the system is running on an Nvidia GPU.
  */
  isNvidia = super:
    let
      videoDrivers = super.services.xserver.videoDrivers or [ ];
    in
    builtins.elem "nvidia" videoDrivers;
}
