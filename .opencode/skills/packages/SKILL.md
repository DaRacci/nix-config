---
name: packages
description: Create custom packages and overlays
---

# Packages

## Package Directory Structure

```
pkgs/
  default.nix           # Central registry - exports all packages
  <package-name>/       # Each package in its own directory
    default.nix         # Package definition
    [other files]       # Scripts, patches, deps.json, etc.
  python/               # Python library packages
    pyarlo.nix
    pyuptimekuma.nix
```

## Adding a New Package

### 1. Create package directory

```bash
mkdir -p pkgs/my-package
```

### 2. Create package definition

```nix
# pkgs/my-package/default.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "my-package";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "my-package";
    rev = "v${version}";
    hash = "sha256-AAAA...";
  };

  meta = with lib; {
    description = "My custom package";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

### 3. Register in pkgs/default.nix

```nix
# pkgs/default.nix
{ pkgs, ... }:
{
  my-package = pkgs.callPackage ./my-package { };
}
```

## Common Builder Patterns

### Shell Script Wrapper

```nix
{
  writeShellApplication,
  gawk,
  coreutils,
}:
writeShellApplication {
  name = "my-script";
  text = builtins.readFile ./my-script.sh;
  runtimeInputs = [ gawk coreutils ];
}
```

### Binary Package with autoPatchelf

```nix
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "my-binary";
  version = "1.0.0";

  src = fetchurl {
    url = "https://example.com/my-binary-${version}.tar.gz";
    hash = "sha256-AAAA...";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    install -Dm755 my-binary $out/bin/my-binary
  '';
}
```

### Python Application

```nix
{
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication rec {
  pname = "my-app";
  version = "1.0.0";
  pyproject = true;

  src = fetchFromGitHub { ... };

  build-system = [ python3Packages.setuptools ];
  dependencies = [ python3Packages.requests ];

  meta = { ... };
}
```

### Python Library

```nix
# pkgs/python/my-lib.nix
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  requests,
}:
buildPythonPackage rec {
  pname = "my-lib";
  version = "1.0.0";
  pyproject = true;

  src = fetchFromGitHub { ... };

  build-system = [ setuptools ];
  dependencies = [ requests ];

  pythonImportsCheck = [ "my_lib" ];

  meta = { ... };
}
```

Register Python packages with:

```nix
# pkgs/default.nix
my-lib = pkgs.python3Packages.callPackage ./python/my-lib.nix { };
```

### Multi-Output Package

```nix
{
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonApplication;
in
{
  my-server = buildPythonApplication { ... };
  my-client = buildPythonApplication { ... };
}
```

Register with:

```nix
inherit (pkgs.callPackage ./my-package { }) my-server my-client;
```

## Overlay Integration

Packages are exposed via `overlays/default.nix`:

```nix
additions = final: prev:
  import ../pkgs {
    inherit inputs lib;
    pkgs = final;
  };
```

This makes all packages available as `pkgs.<package-name>`.

## Update Scripts

Add automatic update support:

```nix
passthru.updateScript = nix-update-script {
  extraArgs = [ "--flake" ];
};
```

Then update with: `nix-update --flake <package-name>`
