{
  self,
  inputs,
  system,
  pkgs,
  lib,
  ...
}:
let
  inherit (inputs.search.packages.${system}) mkOptionsJSON;
  inherit (lib)
    any
    hasInfix
    filterAttrs
    mapAttrsToList
    removePrefix
    hasSuffix
    concatLists
    ;

  # Stubs for server module helpers so individual evaluation works in docs context.
  # Server sub-modules use curried args like `isThisIOPrimaryHost`, `collectAllAttrs`,
  # `importModule` etc. that normally come from `server/default.nix` which can't be
  # evaluated standalone (needs host config). These stubs let individual files resolve.
  serverHelpers = lib.fix (self: {
    isIOPrimaryHost = _: true;
    isThisIOPrimaryHost = false;
    isMonitoringPrimaryHost = _: true;
    isThisMonitoringPrimaryHost = false;
    primaryIOHostConfig = { };
    getIOPrimaryHostAttr = _: { };
    getAllAttrs = _: [ ];
    getAllAttrsFunc = _: _: [ ];
    getOtherAttrs = _: [ ];
    getOtherAttrsFunc = _: _: [ ];
    collectAllAttrs = _: { };
    collectAllAttrsFunc = _: _: { };
    collectOtherAttrs = _: { };
    collectOtherAttrsFunc = _: _: { };
    getOthersWhere = _: [ ];
    serverConfigurations = [ ];
    importModule = path: inherits: import path (self // inherits);
  });

  # Build minimal module evaluations suitable for options documentation.
  # Keep specialArgs aligned with normal module loading so recursive scans can
  # evaluate modules that expect repository-level args.
  mkFlakeOptionsJSON =
    modules:
    mkOptionsJSON {
      inherit modules;
      specialArgs = {
        inherit inputs lib self;
      };
    };

  mkNixosOptionsJSON =
    modules:
    mkOptionsJSON {
      inherit modules;
      specialArgs = {
        inherit inputs lib self;
        hostDirectory = "${self}/hosts";
        importExternals = false;
        users = [ ];
      }
      // serverHelpers;
    };

  mkHomeManagerOptionsJSON =

    modules:
    mkOptionsJSON {
      inherit modules;
      specialArgs = {
        inherit inputs lib self;
        hostDirectory = "${self}/hosts";
        importExternals = false;
      };
    };

  mkFlakeModuleOptions =
    path:
    mkFlakeOptionsJSON [
      "${self}/modules/flake/default.nix"
      path
    ];

  mkNixosModuleOptions =
    path:
    mkNixosOptionsJSON [
      "${self}/modules/nixos/default.nix"
      path
      {
        _module.args = {
          inherit self inputs pkgs;
        };
      }
    ];

  mkHomeManagerModuleOptions =
    path:
    mkHomeManagerOptionsJSON [
      "${self}/modules/home-manager/purpose/default.nix"
      path
      {
        _module.args = {
          inherit self inputs pkgs;
          outputs = self.outputs;
          osConfig = null;
        };

        _module.check = false;
      }
    ];

  flakeAggregateOptionsJSON = mkFlakeOptionsJSON [ "${self}/modules/flake/default.nix" ];

  nixosAggregateOptionsJSON = mkNixosOptionsJSON [
    "${self}/modules/nixos/default.nix"
    "${self}/modules/nixos/core/default.nix"
    "${self}/modules/nixos/server/default.nix"
    {
      _module.args = {
        inherit self inputs pkgs;
      };
    }
  ];

  homeManagerAggregateOptionsJSON = mkHomeManagerOptionsJSON [
    "${self}/modules/home-manager/purpose/default.nix"
    {
      _module.args = {
        inherit self inputs pkgs;
        outputs = self.outputs;
        osConfig = null;
      };

      _module.check = false;
    }
  ];

  discoverModules =
    category: moduleDir: mkFn: aggregateJSON:

    let
      fileLooksLikeModule =
        path:
        let
          content = builtins.readFile path;
          hasModuleBody = any (needle: hasInfix needle content) [
            "options."
            "options ="
            "config ="
            "imports ="
          ];
          isModuleFactory = any (needle: hasInfix needle content) [
            "imports ? [ ]"
            "options ? { }"
            "extraConfig ? { }"
          ];

        in
        hasModuleBody && !isModuleFactory;

      findModuleFilesRec =
        dir: relDir:
        let
          entries = builtins.readDir dir;
          files = filterAttrs (
            name: type: hasSuffix ".nix" name && type == "regular" && fileLooksLikeModule "${dir}/${name}"
          ) entries;
          subdirs = filterAttrs (_: type: type == "directory") entries;
          fileResults = mapAttrsToList (
            name: _:
            let
              relPath = removePrefix "/" "${relDir}/${name}";
            in
            {
              inherit relPath;
              fullPath = "${dir}/${name}";
              isCurriedHelper =
                let
                  content = builtins.readFile "${dir}/${name}";
                in
                hasInfix "}:
{" content || hasInfix "_:
{" content;
              isDefault = name == "default.nix";
            }

          ) files;
          subResults = concatLists (
            mapAttrsToList (subdir: _: findModuleFilesRec "${dir}/${subdir}" "${relDir}/${subdir}") subdirs
          );
        in
        fileResults ++ subResults;

      pathToPrefix =
        relPath:
        let
          withoutDefault =
            if relPath == "default.nix" then
              ""
            else if lib.hasSuffix "/default.nix" relPath then
              lib.removeSuffix "/default.nix" relPath
            else if relPath == "options.nix" then
              ""
            else if lib.hasSuffix "/options.nix" relPath then
              lib.removeSuffix "/options.nix" relPath
            else
              lib.removeSuffix ".nix" relPath;
        in
        builtins.replaceStrings [ "/" ] [ "." ] withoutDefault;

      normalizePrefix =
        prefix:
        prefix
        |> lib.splitString "."
        |> map lib.strings.toCamelCase
        |> lib.concatStringsSep ".";

      prefixToOutputName = prefix: builtins.replaceStrings [ "." ] [ "-" ] prefix;

      moduleToEntry =
        module:
        let
          discoveredPrefix = pathToPrefix module.relPath;
          prefix = prefixOverrides.${discoveredPrefix} or (normalizePrefix discoveredPrefix);
          outputName = prefixToOutputName discoveredPrefix;
          json = if module.isDefault || module.isCurriedHelper then aggregateJSON else mkFn module.fullPath;

        in
        {
          name = if discoveredPrefix == "" then category else "${category}.${discoveredPrefix}";
          value = {
            path = module.fullPath;
            inherit
              json
              prefix
              outputName
              category
              ;
          };
        };

      moduleFiles = findModuleFilesRec moduleDir "";
      # When a directory has both default.nix and options.nix, both map to the
      # same prefix (options.nix, like default.nix, is stripped).  Drop the
      # default.nix entry so options.nix takes precedence.
      optionsNixDirs = builtins.filter (d: d != "") (
        map (m: dirOf m.relPath) (builtins.filter (m: lib.hasSuffix "/options.nix" m.relPath) moduleFiles)
      );
      dedupedFiles = builtins.filter (
        m: !m.isDefault || !builtins.elem (dirOf m.relPath) optionsNixDirs
      ) moduleFiles;
    in
    builtins.listToAttrs (map moduleToEntry dedupedFiles);

  discoverFlakeModules =
    discoverModules "flake" "${self}/modules/flake" mkFlakeModuleOptions
      flakeAggregateOptionsJSON;
  discoverNixosModules =
    discoverModules "nixos" "${self}/modules/nixos" mkNixosModuleOptions
      nixosAggregateOptionsJSON;
  discoverHomeManagerModules =
    discoverModules "home-manager" "${self}/modules/home-manager" mkHomeManagerModuleOptions
      homeManagerAggregateOptionsJSON;

  prefixOverrides = { };

  flakeModules = discoverFlakeModules;
  nixosModules = discoverNixosModules;
  homeManagerModules = discoverHomeManagerModules;

  allModules = flakeModules // nixosModules // homeManagerModules;

  moduleOptionsJSON = lib.mapAttrs (_name: module: module.json) allModules;

in
rec {
  search = pkgs.callPackage ./search.nix {
    inherit
      self
      inputs
      system
      pkgs
      ;
    lib = pkgs.lib;
  };

  inherit moduleOptionsJSON allModules;

  docs = pkgs.callPackage ./site.nix {
    inherit
      self
      inputs
      pkgs
      lib
      search
      moduleOptionsJSON
      allModules

      mkNixosModuleOptions
      mkHomeManagerModuleOptions
      discoverModules
      ;
  };

  serve-docs = pkgs.callPackage ./serve.nix {
    inherit docs;
  };
}
