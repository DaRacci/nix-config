# TODO - Look into TPM2
# TODO - Look into SELinux
{
  security = {
    lockKernelModules = false;
    protectKernelImage = true;

    rtkit.enable = true;

    polkit.enable = true;
  };
}
