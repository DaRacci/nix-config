export-env {
  $env.GIT_ROOT = ($env.PWD | git rev-parse --show-toplevel | str trim)
  $env.CURRENT_HOST = (cat /etc/hostname | str trim)
  $env.CURRENT_USER = (whoami | str trim)
}

export def select_host [] {
  let hosts = flake-eval r#'builtins.attrNames flake.nixosConfigurations |> builtins.concatStringsSep " "'#
    | split words
    | where $it != $env.CURRENT_HOST

  let selected = ["current", ...($hosts)] | input list -f
  if $selected == "current" {
    $env.CURRENT_HOST
  } else {
    $selected
  }
}

export def select_user [] {
  let users = flake-eval r#'builtins.attrNames flake.homeConfigurations |> builtins.concatStringsSep " "'#
    | split words
    | where $it != $env.CURRENT_USER

  let selected = ["current", ...($users)] | input list -f
  if $selected == "current" {
    $env.CURRENT_USER
  } else {
    $selected
  }
}

export def --wrapped flake-eval [
  expr: string,
  ...nix_args: string
] {

  nix eval --quiet --raw --no-pure-eval --expr $'
    let
      flake = builtins.getFlake "($env.GIT_ROOT)";
    in ($expr)
  ' ...$nix_args
}
