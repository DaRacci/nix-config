{
  osConfig ? null,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.programs.list-ephemeral;
  homeDir = config.home.homeDirectory;
  homePrefix = removePrefix "/" homeDir;
  configPrefix = "${homePrefix}/.config";
  sharePrefix = "${homePrefix}/.local/share";

  baseExcludes = [
    "etc/passwd"
    "etc/NIXOS"
    "etc/group"
    "etc/machine-id"
    "etc/resolve.conf"
    "etc/ssh"
    "etc/shadow"
    "etc/subgid"
    "etc/subuid"
    "etc/sudoers"

    "var/lib/libvirt/{qemu.conf,nwfilter,dnsmasq}"
    "var/cache"
    "var/.updated"
    "var/lib/NetworkManager/timestamps"
    "var/lib/dhcpcd"

    "**/*logs"
    "**/*log"

    "tmp"

    "${homePrefix}/.cache"

    "${homePrefix}/.npm"
    "${homePrefix}/.cargo"
    "${homePrefix}/.mozilla/firefox/*/cache2/entries"
    "${homePrefix}/.steam"
    "${homePrefix}/.pki"
    "${homePrefix}/.pulse-cookie"
    "${homePrefix}/.local/state/wireplumber"
    "${sharePrefix}/vulkan/implicit_layer.d"
    "${configPrefix}/BambuStudio"
    "${configPrefix}/**/com.1password.1password.json"
    "${configPrefix}/opencode/node_modules"
  ];

  electronApps = [
    "${configPrefix}/Code"
    "${configPrefix}/SideQuest"
    "${configPrefix}/1Password"
    "${configPrefix}/1Password/Partitions/1password"
  ];

  electronRelativePaths = [
    "Cache"
    "Code Cache"
    "CachedData"
    "GPUCache"
    "Session Storage"
    "Shared Dictionary"
    "DawnGraphiteCache"
    "DawnWebGPUCache"
    "Crashpad"
    "SharedStorage"
    "Trust Tokens"
    "Trust Tokens-journal"
    "Local Storage"
    "Cookies"
    "Cookies-journal"
    "Dictionaries"
    "Network Persistent State"
    "Preferences"
    "TransportSecurity"
  ];

  electronExcludes = lib.concatMap (
    app: map (path: "${app}/${path}") electronRelativePaths
  ) electronApps;

  toDir = entry: if isAttrs entry then entry.directory else entry;
  toFile = entry: if isAttrs entry then entry.file else entry;

  hostCfg = if osConfig != null && (osConfig ? host) then osConfig.host else null;
  hostPersistEnabled = hostCfg != null && (hostCfg ? persistence) && hostCfg.persistence.enable;

  userDirs = map toDir config.user.persistence.directories;
  userFiles = config.user.persistence.files;
  hostDirs = if hostPersistEnabled then map toDir hostCfg.persistence.directories else [ ];
  hostFiles = if hostPersistEnabled then map toFile hostCfg.persistence.files else [ ];

  toAbsolute =
    path:
    if hasPrefix "/" path then
      path
    else if path == "~" then
      homeDir
    else if hasPrefix "~/" path then
      "${homeDir}/${removePrefix "~/" path}"
    else
      "${homeDir}/${path}";

  persistedDirs = map toAbsolute userDirs ++ hostDirs;
  persistedFiles = map toAbsolute userFiles ++ hostFiles;

  programNames = lib.unique (map lib.getName config.home.packages);
in
{
  options.programs.list-ephemeral = {
    enable = mkEnableOption "list-ephemeral helper" // {
      default = hostPersistEnabled || config.user.persistence.enable;
    };

    extraExcludes = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ "home/*/.local/share/Trash" ];
      description = "Additional exclude patterns for list-ephemeral.";
    };

    extraIncludes = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        ".config/my-app"
        "/var/lib/my-app"
      ];
      description = "Additional paths to always include as candidates.";
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."list-ephemeral/config.json".text = builtins.toJSON {
      excludes = baseExcludes ++ electronExcludes;
      extraExcludes = cfg.extraExcludes;
      extraIncludes = cfg.extraIncludes;
      inherit persistedFiles;
      inherit persistedDirs;
      programs = programNames;
      inherit homeDir;
    };
  };
}
