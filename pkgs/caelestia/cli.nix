{
  pkgs,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication {
  pname = "cli";
  version = "0.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "caelestia-dots";
    repo = "cli";
    rev = "e2a34210e58cbd593be63fd4b3e5d2d6257f5c37";
    hash = "sha256-BlQQF73Qkk2uKfS0yYEQLWdnkf+uWzbvyqkvLqpyUCM=";
  };

  build-system = [
    python3.pkgs.hatch-vcs
    python3.pkgs.hatchling
  ];

  dependencies = with python3.pkgs; [
    materialyoucolor
    pillow
  ];

  pythonImportsCheck = [
    "caelestia"
  ];

  propagatedBuildInputs = with pkgs; [
    swappy
    libnotify
    slurp
    wl-clipboard
    app2unit
    cliphist
    dart-sass
    grim
    fuzzel
    quickshell
    wl-screenrec
  ];

  meta = {
    description = "A collection of scripts for my caelestia dotfiles";
    homepage = "https://github.com/caelestia-dots/cli";
    mainProgram = "caelestia";
  };
}
