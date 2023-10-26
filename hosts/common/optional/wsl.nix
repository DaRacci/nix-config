{
  wsl.enable = true;
  wsl.defaultUser = "racci";

  wsl.wslConf.boot.command = ''/mnt/c/Windows/system32/schtasks.exe /run /tn "mount-wsl-disks"'';
}
