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
      };
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
            else
              lib.removeSuffix ".nix" relPath;
        in
        builtins.replaceStrings [ "/" ] [ "." ] withoutDefault;

      normalizePrefix =
        prefix: prefix |> lib.splitString "." |> map lib.strings.toCamelCase |> lib.concatStringsSep ".";

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
          name = discoveredPrefix;
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
    in
    builtins.listToAttrs (map moduleToEntry (findModuleFilesRec moduleDir ""));

  discoverFlakeModules =
    discoverModules "flake" "${self}/modules/flake" mkFlakeModuleOptions
      flakeAggregateOptionsJSON;
  discoverNixosModules =

    discoverModules "nixos" "${self}/modules/nixos" mkNixosModuleOptions nixosAggregateOptionsJSON;
  discoverHomeManagerModules =
    discoverModules "home-manager" "${self}/modules/home-manager" mkHomeManagerModuleOptions
      homeManagerAggregateOptionsJSON;

  prefixOverrides = {
    "services.woodpecker-nix" = "services.woodpeckerNix";
  };

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
