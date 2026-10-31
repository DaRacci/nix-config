{ lib }:
let
  inherit (lib)
    mkIf
    mkEnableOption
    optional
    getName
    getExe
    splitString
    ;
  inherit (builtins)
    filter
    isAttrs
    listToAttrs
    hasAttr
    isList
    foldl'
    elemAt
    length
    ;

  # Takes a list of packages, returning a list of the same packages with any packages matching depNames removed.
  depsMinusNamed =
    depNames: pkgs:
    let
      depNamesSet = listToAttrs (
        map (name: {
          inherit name;
          value = true;
        }) depNames
      );
      isNotNamedDep = pkg: !(hasAttr (lib.getName pkg) depNamesSet);
    in
    filter isNotNamedDep pkgs;

  # Deep merge with list concatenation, so feature toggles can append instead of clobbering.
  mergeDeep =
    lhs: rhs:
    if isAttrs lhs && isAttrs rhs then
      lhs // lib.mapAttrs (name: value: if lhs ? ${name} then mergeDeep lhs.${name} value else value) rhs
    else if isList lhs && isList rhs then
      lhs ++ rhs
    else
      rhs;

  # Binaries from plugin `extraPackages` are symlinked into the agent's virtualenv bin
  # directory, because that is a directory the gateway is *launched* with: the hermes
  # container entrypoint prepends `$HOME/.venv/bin` to PATH before it execs the gateway
  # (upstream `nix/nixosModules.nix`). PATH edits made from a login shell — `.profile`,
  # `.bashrc` — never reach the gateway process, so they cannot make a directory visible
  # to it. `mkdir -p` before each link keeps delivery working when the venv directory is
  # missing or has just been recreated; `ln` alone silently drops the binary in that case.
  # The postStart hook runs as root, so a directory it has to create is handed back to the
  # agent user — otherwise a root-owned `~/.venv` would stop the entrypoint from ever
  # provisioning the virtualenv.
  agentHome = "/home/hermes";
  agentBinDir = "${agentHome}/.venv/bin";

  # Create a simple option and config module for plugins.
  mkPluginModule =
    config:
    {
      name,
      extraPackages ? [ ],
      extraPythonPackages ? [ ],
      extraPluginSrc ? null,

      # Override the plugin name that is used to load the plugin.
      pluginName ? name,

      settings ? { },
      extraConfig ? { },
    }:
    {
      options.services.ai-agent.plugins.${name} = {
        enable = mkEnableOption "${name} plugin";
      };

      config = mkIf config.services.ai-agent.plugins.${name}.enable (
        mergeDeep extraConfig {
          services = {
            ai-agent.settings = mergeDeep settings {
              plugins.enabled = [ pluginName ];
            };
            hermes-agent = {
              inherit extraPackages extraPythonPackages;
              extraPlugins = optional (extraPluginSrc != null) extraPluginSrc;
            };
          };

          # When hermes-agent runs inside a container it doesnt inherit the PATH from the systemd unit which includes the extraPackages,
          # so we symlink the binaries into the venv bin dir (see `agentBinDir`) that the container entrypoint puts on the gateway's PATH.
          #
          # This does come with some caveats, such as for plugins that rely on the presence of a binary to register themselves,
          # since this is ran as a postStart hook, the agent may have already started and not had the binary available at the time of plugin registration, so the plugin may not be loaded.
          # This would be resolved uppon a restart of the agent, but isnt ideal.
          services.ai-agent.containerPostStart =
            extraPackages
            |> map (
              pkg:
              let
                binaryPath = getExe pkg;
                binaryName =
                  if binaryPath == "" then
                    getName pkg
                  else
                    elemAt (splitString "/" binaryPath) (length (splitString "/" binaryPath) - 1);
              in
              "mkdir -p ${agentBinDir} && chown --reference=${agentHome} ${agentHome}/.venv ${agentBinDir} 2>/dev/null; ln -sfn ${binaryPath} ${agentBinDir}/${binaryName}"
            );
        }
      );
    };

  hermesConfigType = lib.types.mkOptionType {
    name = "ai-agent-hermes-settings";
    description = "Hermes config attrs, deep-merged with list concatenation.";
    check = isAttrs;
    merge = _loc: defs: foldl' mergeDeep { } (map (d: d.value) defs);
  };
in
{
  inherit
    depsMinusNamed
    mergeDeep
    mkPluginModule
    hermesConfigType
    ;
}
