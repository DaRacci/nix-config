{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOrder
    getExe
    escapeShellArgs
    ;
  inherit (pkgs) writableTmpDirAsHomeHook;

  cfg = config.programSets.shell;
  atuinCfg = config.programs.atuin;
in
{
  config = mkIf cfg.enable {
    programs.atuin.enable = true;

    user.persistence.directories = [ ".local/share/atuin" ];

    # Ordered so its *right* before the normal atuin hook
    # because the pty-proxy component MUST be loaded first.
    programs.nushell.extraConfig = mkOrder 1999 ''
      source ${
        pkgs.runCommand "atuin-pty-proxy-nushell-config.nu"
          {
            nativeBuildInputs = [ writableTmpDirAsHomeHook ];
          }
          ''
            ${getExe atuinCfg.package} init nu ${escapeShellArgs atuinCfg.flags} >> "$out"
          ''
      }
    '';
  };
}
