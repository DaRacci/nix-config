<!-- TODO -->
# Installation

## Windows Subsystem for Linux (WSL)

  1. Install WSL 2
  2. Setup NixOS for WSL via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
  3. Edit `$HOST/.wslconfig` on your windows user to include the following:
    ```conf
    [wsl2]
    kernelCommandLine = cgroup_no_v1=all
    ```
