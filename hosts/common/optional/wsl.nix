{
  wsl.enable = true;
  wsl.defaultUser = "racci";
  wsl.startMenuLaunchers = true;
  wsl.nativeSystemd = true;
  users.allowNoPasswordLogin = true;

  # wsl.wslConf.automount.mountFsTab = true;
  # wsl.wslConf.boot.command = ''/mnt/c/Windows/system32/schtasks.exe /run /tn "mount-wsl-disks"'';
  wsl.wslConf.interop.enabled = false;
  wsl.wslConf.interop.appendWindowsPath = false;

}
