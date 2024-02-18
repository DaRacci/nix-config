{ inputs, pkgs, ... }: {
  programs.anyrun = {
    enable = true;
    config = {
      plugins = with inputs.anyrun.packages.${pkgs.system}; [
        applications
        dictionary
        kidex
        randr
        rink
        shell
        stdin
        symbols
        translate
        websearch
      ];

      width = { fraction = 0.3; };

      hideIcons = false;
      ignoreExclusiveZones = false;
      layer = "overlay";
      hidePluginInfo = false;
      closeOnClick = false;
      showResultsImmediately = true;
      maxEntries = null;
    };
  };
}
