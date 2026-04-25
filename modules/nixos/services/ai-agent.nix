{
  inputs,
  config,
  pkgs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.services.ai-agent;
in
{
  imports = lib.optional importExternals "${inputs.services-zeroclaw}";

  options.services.ai-agent = {
    enable = mkEnableOption "autonomous AI Agent service";
  };

  config = mkIf cfg.enable {
    services.zeroclaw = {
      enable = true;

      settings = {
        agent = {
          compact_context = true;
          parallel_tools = true;
        };

        autonomy = {
          level = "supervised";
          workspace_only = true;
          require_approval_for_medium_risk = false;
          allowed_commands = [
            "awk"
            "base64"
            "cargo"
            "cargo-check"
            "cargo-build"
            "cargo-test"
            "cat"
            "clang"
            "cmake"
            "curl"
            "cut"
            "date"
            "dig"
            "diff"
            "echo"
            "file"
            "find"
            "fd"
            "g++"
            "gcc"
            "git"
            "gdb"
            "go"
            "grep"
            "gzip"
            "gunzip"
            "head"
            "hg"
            "jj"
            "jq"
            "ls"
            "less"
            "lldb"
            "ltrace"
            "lua"
            "make"
            "md5sum"
            "more"
            "nano"
            "node"
            "npm"
            "nix"
            "nil"
            "nixd"
            "nixfmt"
            "od"
            "pip"
            "ping"
            "poetry"
            "printf"
            "python"
            "python3"
            "pwd"
            "rustc"
            "rustfmt"
            "rustup"
            "rg"
            "sed"
            "sha256sum"
            "sort"
            "strace"
            "strings"
            "tail"
            "tar"
            "tree"
            "tr"
            "tmux"
            "uname"
            "uniq"
            "valgrind"
            "vim"
            "wc"
            "wget"
            "whoami"
          ];
          auto_approve = [
            "shell"
            "file_read"
            "file_write"
            "file_edit"
            "global_search"
            "content_search"
            "cron_add"
            "cron_list"
            "cron_remove"
            "cron_run"
            "cron_runs"
            "memory_store"
            "memory_recall"
            "memory_forget"
            "schedule"
            "model_switch"
            "git_operations"
            "browser_open"
            "browser"
            "http_request"
            "web_fetch"
            "web_search_tool"
            "project_intel"
            "pdf_read"
            "knowledge"
            "delegate"
          ];
          forbidden_paths = [
            "/etc"
            "/root"
            "/home"
            "/usr"
            "/bin"
            "/sbin"
            "/lib"
            "/opt"
            "/boot"
            "/dev"
            "/proc"
            "/sys"
            "/var"
            "/tmp"
            "/run"
            "~/.ssh"
            "~/.gnupg"
            "~/.aws"
            "~/.config"
          ];
        };

        security = {
          estop.enabled = true;
        };

        heartbeat = {
          enabled = true;
          interval_minutes = 15;
        };

        observability = {
          backend = "log";
          runtime_trace_mode = "rolling";
          runtime_trace_path = "state/runtime-trace.jsonl";
        };

        runtime.kind = "native";

        memory = {
          backend = "sqlite";
          auto_save = true;
        };

        skills = {
          open_skills_enabled = true;
          prompt_injection_mode = "compact";
          skill_creation.enabled = true;
        };

        browser = {
          enabled = true;
          backend = "rust_native";
        };

        http_request = {
          enabled = true;
          allowed_domains = [
            "codeberg.org"
            "cppreference.com"
            "crates.io"
            "devdocs.io"
            "developer.mozilla.org"
            "docker.io"
            "docs.rs"
            "github.com"
            "gitlab.com"
            "golang.org"
            "hub.docker.com"
            "man.archlinux.org"
            "nixos.org"
            "pypi.org"
            "raw.githubusercontent.com"
            "registry.npmjs.org"
            "rust-lang.org"
            "stackoverflow.com"
            "w3.org"
            "wikipedia.org"
            "www.moltbook.com "
          ];
        };

        web_search.enabled = true;
        project_intel.enabled = true;
        web_fetch.enabled = true;
        knowledge = {
          enabled = true;
          auto_capture = true;
        };
      };
    };

    systemd.services.zeroclaw = {
      path = [
        # General tools
        pkgs.bash
        pkgs.openssh
        pkgs.git
        pkgs.curl
        pkgs.uutils-coreutils-noprefix
        pkgs.fd
        pkgs.ripgrep
        pkgs.tmux
        pkgs.opencode

        # Language tooling
        pkgs.python314
        pkgs.nodejs
        pkgs.rustc
        pkgs.cargo
      ];

      environment = {
        HOME = "/var/lib/${config.services.zeroclaw.stateDir}";
        SHELL = lib.getExe pkgs.bash;
        XDG_CONFIG_HOME = "/var/lib/${config.services.zeroclaw.stateDir}/.config";
      };

      serviceConfig = {
        PrivateDevices = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RemoveIPC = true;
        ProtectProc = "noaccess";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  };
}
