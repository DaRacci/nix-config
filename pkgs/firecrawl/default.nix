{
  stdenv,
  lib,
  fetchFromGitHub,
  nodejs_22,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  rustPlatform,
  go,
  makeWrapper,
  playwright-driver,
  pax-utils,
  ...
}:

let
  pname = "firecrawl";
  version = "2.10.25";

  src = fetchFromGitHub {
    owner = "firecrawl";
    repo = "firecrawl";
    rev = "refs/tags/v${version}";
    hash = "sha256-c/mbNYZeJWF3YKhOutHHlwof/v0rSCtGe06bK28v/Dw=";
  };

  # Rust native module (napi-rs cdylib)
  nativeSrc = stdenv.mkDerivation {
    pname = "firecrawl-native-src";
    inherit version src;
    dontUnpack = false;
    phases = [
      "unpackPhase"
      "patchPhase"
      "installPhase"
    ];
    patchPhase = ''
      runHook prePatch
      cp ${./Cargo.lock} $NIX_BUILD_TOP/$sourceRoot/apps/api/native/Cargo.lock
      runHook postPatch
    '';
    installPhase = ''
      runHook preInstall
      cp -r $NIX_BUILD_TOP/$sourceRoot $out
      runHook postInstall
    '';
  };

  rustAddon = rustPlatform.buildRustPackage {
    pname = "firecrawl-rs";
    inherit version;
    src = nativeSrc;

    sourceRoot = "${nativeSrc.name}/apps/api/native";

    cargoDeps = rustPlatform.fetchCargoVendor {
      src = nativeSrc;
      cargoRoot = "apps/api/native";
      name = "${pname}-cargo-deps";
      hash = "sha256-q7Y2vkoi562GQmFDLkoJhLFP/8GOKhcNZf2FSASq1VI=";
    };

    nativeBuildInputs = [
      stdenv.cc
    ];

    buildType = "release";

    # We only want the cdylib (.so or .node), not a binary
    # napi-rs on linux produces libfirecrawl_rs.so from cargo, but
    # the napi build tool produces firecrawl-rs.linux-x64-gnu.node
    # We build just the lib and copy it with the expected napi name
    cargoBuildFlags = [ "--lib" ];

    postBuild = ''
      # napi-rs @napi-rs/cli normally produces the .node file.
      # Since we skip the napi build script, we copy the cdylib
      # as the expected .node filename for the napi loader.
      find . -name "libfirecrawl_rs.so" -exec cp {} firecrawl-rs.linux-x64-gnu.node \;
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp firecrawl-rs.linux-x64-gnu.node $out/
      # Generate napi-rs loader (normally produced by napi build)
      cat > $out/index.js << 'NODELOADER'
      const { existsSync, readFileSync } = require('fs')
      const { join } = require('path')

      const { platform, arch } = process

      let nativeBinding = null
      let localFileFound = false
      let loadError = null

      function isMusl() {
        if (!process.report || typeof process.report.getReport !== 'function') {
          try {
            const lddPath = require('child_process').execSync('which ldd').toString().trim();
            return readFileSync(lddPath, 'utf8').includes('musl')
          } catch (e) {
            return true
          }
        } else {
          const report = process.report.getReport();
          if (report && report.sharedObjects) {
            return report.sharedObjects.some((obj) => obj.includes('ld-musl'))
          }
        }
        return false
      }

      switch (platform) {
        case 'linux':
          switch (arch) {
            case 'x64':
              localFileFound = true
              nativeBinding = require('./firecrawl-rs.linux-x64-gnu.node')
              break
            default:
              throw new Error(`Unsupported architecture on Linux: ''${arch}`)
          }
          break
        default:
          throw new Error(`Unsupported OS: ''${platform}, architecture: ''${arch}`)
      }

      if (!nativeBinding) {
        if (loadError) {
          throw loadError
        }
        throw new Error('Failed to load native binding')
      }

      module.exports = nativeBinding
      NODELOADER
      runHook postInstall
    '';

    meta = {
      description = "Firecrawl Rust native napi-rs addon";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
    };
  };

  # Go shared library (libhtml-to-markdown.so)
  goModules = stdenv.mkDerivation {
    pname = "firecrawl-go-modules";
    inherit version src;
    sourceRoot = "${src.name}/apps/api/sharedLibs/go-html-to-md";
    nativeBuildInputs = [ go ];
    configurePhase = ''
      runHook preConfigure
      export GOPATH=$TMPDIR/gopath
      export GOMODCACHE=$TMPDIR/gomod
      export HOME=$TMPDIR
      mkdir -p $GOPATH $GOMODCACHE
      runHook postConfigure
    '';
    buildPhase = ''
      runHook preBuild
      go mod download
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r $GOMODCACHE/cache $out/cache
      runHook postInstall
    '';
    outputHash = "sha256-RF0UPM2AlHoMRGqFdwDED8QUlcZQtUXkn/jeHI8bVhs=";
    outputHashMode = "recursive";
  };

  goSharedLib = stdenv.mkDerivation {
    pname = "libhtml-to-markdown";
    inherit version src;

    sourceRoot = "${src.name}/apps/api/sharedLibs/go-html-to-md";

    nativeBuildInputs = [ go ];

    configurePhase = ''
      runHook preConfigure
      export GOPATH=$TMPDIR/gopath
      export GOMODCACHE=$TMPDIR/gomod
      export HOME=$TMPDIR
      mkdir -p $GOPATH $GOMODCACHE
      cp -r ${goModules}/cache $GOMODCACHE/cache
      chmod -R u+w $GOMODCACHE
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      GOFLAGS="-mod=mod" GONOSUMCHECK='*' GONOSUMDB='*' GOFLAGS="$GOFLAGS -modcacherw" \
        go build -o libhtml-to-markdown.so -buildmode=c-shared html-to-markdown.go
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp libhtml-to-markdown.so $out/lib/
      cp libhtml-to-markdown.h $out/lib/
      runHook postInstall
    '';

    meta = {
      description = "Go shared library for HTML-to-Markdown conversion";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
    };
  };

  # Main Firecrawl Node.js application
  pnpmRoot = "apps/api";
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = [
    nodejs_22
    pnpm_10
    pnpmConfigHook
    makeWrapper
    pax-utils
  ];

  inherit pnpmRoot;

  pnpmDeps = fetchPnpmDeps {
    inherit pname version;
    inherit (finalAttrs) src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-uZuecz5MD/Y5H+BJiWFvWDbkV2buE9zDGiMJltk221w=";
    sourceRoot = "${src.name}/apps/api";
  };

  buildPhase = ''
        runHook preBuild

        cd apps/api

        # Patch TypeScript strict mode error upstream hasn't fixed
        # Function lacks ending return statement in document engine
        substituteInPlace src/scraper/scrapeURL/engines/document/index.ts \
          --replace-fail "function getContentTypeFromDocumentType(documentType: DocumentType): string {
      switch (documentType) {
        case DocumentType.Docx:
          return \"application/vnd.openxmlformats-officedocument.wordprocessingml.document\";
        case DocumentType.Doc:
          return \"application/msword\";
        case DocumentType.Odt:
          return \"application/vnd.oasis.opendocument.text\";
        case DocumentType.Rtf:
          return \"application/rtf\";
        case DocumentType.Xlsx:
          return \"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\";
      }
    }" "function getContentTypeFromDocumentType(documentType: DocumentType): string {
      switch (documentType) {
        case DocumentType.Docx:
          return \"application/vnd.openxmlformats-officedocument.wordprocessingml.document\";
        case DocumentType.Doc:
          return \"application/msword\";
        case DocumentType.Odt:
          return \"application/vnd.oasis.opendocument.text\";
        case DocumentType.Rtf:
          return \"application/rtf\";
        case DocumentType.Xlsx:
          return \"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\";
      }
      return \"\";
    }"

        # Patch harness.ts to gate container management at runtime
        substituteInPlace src/harness.ts \
          --replace-fail "async function setupNuqPostgres(): Promise<Services[\"nuqPostgres\"]> {" $'async function setupNuqPostgres(): Promise<Services["nuqPostgres"]> {\n  if (process.env.FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT === "1") {\n    logger.info("Container management disabled by FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT, skipping NUQ PostgreSQL setup");\n    return undefined;\n  }'
        substituteInPlace src/harness.ts \
          --replace-fail "async function setupNuqRabbitMQ(): Promise<Services[\"nuqRabbitMQ\"]> {" $'async function setupNuqRabbitMQ(): Promise<Services["nuqRabbitMQ"]> {\n  if (process.env.FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT === "1") {\n    logger.info("Container management disabled by FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT, skipping NUQ RabbitMQ setup");\n    return undefined;\n  }'
        substituteInPlace src/harness.ts \
          --replace-fail "async function setupFdb(): Promise<Services[\"fdb\"]> {" $'async function setupFdb(): Promise<Services["fdb"]> {\n  if (process.env.FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT === "1") {\n    logger.info("Container management disabled by FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT, skipping FoundationDB setup");\n    return undefined;\n  }'

        # Place Rust native addon where the source expects it
        mkdir -p native
        cp ${rustAddon}/firecrawl-rs.linux-x64-gnu.node native/
        cp ${rustAddon}/index.js native/

        # Place Go shared library where koffi FFI loader expects it
        mkdir -p sharedLibs/go-html-to-md
        cp ${goSharedLib}/lib/libhtml-to-markdown.so sharedLibs/go-html-to-md/

        # TypeScript compilation
        pnpm run build

        # Prune dev dependencies for runtime output
        pnpm config set confirmModulesPurge false
        CI=true pnpm prune --prod --ignore-scripts

        # Remove broken symlinks from pruned dev deps
        find node_modules -xtype l -delete || true

        runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/$pname
    mkdir -p $out/bin

    # Copy all runtime artifacts from apps/api
    cp -r dist $out/lib/$pname/
    cp -r node_modules $out/lib/$pname/
    cp -r native $out/lib/$pname/
    cp -r sharedLibs $out/lib/$pname/
    cp package.json $out/lib/$pname/
    cp pnpm-lock.yaml $out/lib/$pname/

    # Expose NUQ PostgreSQL schema for external initialization
    mkdir -p $out/share/firecrawl
    cp "$NIX_BUILD_TOP/$sourceRoot/apps/nuq-postgres/nuq.sql" $out/share/firecrawl/nuq.sql

    # Clear executable stack on native .node addons to avoid loader rejection
    find $out/lib/$pname -name '*.node' -type f -exec sh -c 'scanelf -qeX "$1" >/dev/null || true' _ {} \;

    # Create wrapper that sets up environment and runs the harness
    makeWrapper ${lib.getExe nodejs_22} $out/bin/$pname \
      --add-flags "$out/lib/$pname/dist/src/harness.js" \
      --add-flags "--start-docker" \
      --set-default NODE_ENV production \
      --set-default HOME /var/lib/firecrawl \
      --set-default FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT 1 \
      --set-default PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
      --set-default PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD 1 \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
      --chdir "$out/lib/$pname"

    runHook postInstall
  '';

  meta = {
    description = "Turn entire websites into LLM-ready markdown or structured data";
    homepage = "https://github.com/firecrawl/firecrawl";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "firecrawl";
  };
})
