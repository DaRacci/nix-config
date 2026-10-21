{
  osConfig ? null,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkEnableOption
    optional
    ;
  inherit (pkgs) fetchFromGitHub;
  cfg = config.programSets.shell.tools;

  hasGPUAcceleration = osConfig != null && osConfig.hardware.graphics.hasAcceleration;
  hasContainers =
    osConfig != null
    && (osConfig.virtualisation.docker.enable || osConfig.virtualisation.podman.enable);
in
{
  options.programSets.shell.tools = {
    enable = mkEnableOption "common shell tools" // {
      default =
        (osConfig == null || osConfig.host.device.role != "server") && config.programSets.shell.enable;
      defaultText = "true if the device is not a server and shell is enabled";
    };

    enableModernReplacements = mkEnableOption "modern replacements" {
      default = cfg.enable;
      defaultText = "true if shell tools are enabled";
    };

    enableNetworkTools = mkEnableOption "network tools" {
      default = cfg.enable;
      defaultText = "true if shell tools are enabled";
    };

    enableSystemTools = mkEnableOption "system information tools" {
      default = cfg.enable;
      defaultText = "true if shell tools are enabled";
    };

    enableTUI = mkEnableOption "TUI tools" {
      default = cfg.enable;
      defaultText = "true if shell tools are enabled";
    };
  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> config.programSets.shell.enable;
          message = "shell tools can only be enabled if shell is enabled";
        }
        {
          assertion = cfg.enableModernReplacements -> cfg.enable;
          message = "enableModernReplacements requires shell tools to be enabled";
        }
        {
          assertion = cfg.enableNetworkTools -> cfg.enable;
          message = "enableNetworkTools requires shell tools to be enabled";
        }
        {
          assertion = cfg.enableSystemTools -> cfg.enable;
          message = "enableSystemTools requires shell tools to be enabled";
        }
        {
          assertion = cfg.enableTUI -> cfg.enable;
          message = "enableTUI requires shell tools to be enabled";
        }
      ];
    }

    (mkIf cfg.enable {
      programs.helix = {
        enable = true;
        defaultEditor = true;
        settings.editor = {
          line-number = "relative";
          cursorline = false;
          cursorcolumn = false;
        };
      };
    })

    (mkIf cfg.enableModernReplacements {
      home = {
        packages = [
          pkgs.duf
          pkgs.dust
          pkgs.gping
          pkgs.procs
          pkgs.sd
          pkgs.xh
        ];

        shellAliases = {
          cat = "bat";
          grep = "rg";
          ping = "gping";
        };
      };

      programs = {
        bat.enable = true;
        fd.enable = true;
        ripgrep.enable = true;
      };
    })

    (mkIf cfg.enableNetworkTools {
      home.packages = [
        pkgs.doggo
        pkgs.ttl
      ];
    })

    (mkIf cfg.enableSystemTools {
      home.packages = [
        pkgs.inxi
        pkgs.iotop-c
        pkgs.lsof
        pkgs.pciutils
        pkgs.sysstat
      ]
      ++ (optional hasGPUAcceleration pkgs.nvtopPackages.full)
      ++ (optional hasContainers pkgs.ctop);

      programs = {
        btop = {
          enable = true;
          settings = {
            update_ms = 300;
            proc_per_core = true;
            proc_info_smaps = true;
            proc_filter_kernel = true;
            use_fstab = false;
            swap_disk = false;
            io_mode = true;
          };
        };

        fastfetch = {
          enable = true;
          settings = {
            "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
            logo = {
              padding = {
                top = 2;
              };
            };
            display = {
              separator = " -> ";
              constants = [ "──────────────────────────────" ];
            };
            modules = [
              {
                type = "custom";
                format = "┌{$1}{$1}┐";
                outputColor = "90";
              }
              {
                type = "title";
                keyWidth = 10;
              }
              {
                type = "custom";
                format = "└{$1}{$1}┘";
                outputColor = "90";
              }
              {
                type = "custom";
                format = " {#90}  {#31}  {#32}  {#33}  {#34}  {#35}  {#36}  {#37}  {#38}  {#39}       {#38}  {#37}  {#36}  {#35}  {#34}  {#33}  {#32}  {#31}  {#90}";
              }
              {
                type = "custom";
                format = "┌{$1}{$1}┐";
                outputColor = "90";
              }
              {
                type = "os";
                key = "{icon} OS";
                keyColor = "yellow";
              }
              {
                type = "kernel";
                key = "│ ├";
                keyColor = "yellow";
              }
              {
                type = "packages";
                key = "│ ├󰏖";
                keyColor = "yellow";
              }
              {
                type = "shell";
                key = "│ └";
                keyColor = "yellow";
              }
              {
                type = "wm";
                key = " DE/WM";
                keyColor = "blue";
              }
              {
                type = "lm";
                key = "│ ├󰧨";
                keyColor = "blue";
              }
              {
                type = "wmtheme";
                key = "│ ├󰉼";
                keyColor = "blue";
              }
              {
                type = "icons";
                key = "│ ├󰀻";
                keyColor = "blue";
              }
              {
                type = "terminal";
                key = "│ ├";
                keyColor = "blue";
              }
              {
                type = "wallpaper";
                key = "│ └󰸉";
                keyColor = "blue";
              }
              {
                type = "host";
                key = "󰌢 PC";
                keyColor = "green";
              }
              {
                type = "cpu";
                key = "│ ├󰻠";
                keyColor = "green";
              }
              {
                type = "gpu";
                key = "│ ├󰍛";
                keyColor = "green";
              }
              {
                type = "disk";
                key = "│ ├";
                keyColor = "green";
              }
              {
                type = "memory";
                key = "│ ├󰑭";
                keyColor = "green";
              }
              {
                type = "swap";
                key = "│ ├󰓡";
                keyColor = "green";
              }
              {
                type = "uptime";
                key = "│ ├󰅐";
                keyColor = "green";
              }
              {
                type = "display";
                key = "│ └󰍹";
                keyColor = "green";
              }
              {
                type = "sound";
                key = " SND";
                keyColor = "cyan";
              }
              {
                type = "player";
                key = "│ ├󰥠";
                keyColor = "cyan";
              }
              {
                type = "media";
                key = "│ └󰝚";
                keyColor = "cyan";
              }
              {
                type = "custom";
                format = "└{$1}{$1}┘";
                outputColor = "90";
              }
              "break"
              {
                type = "custom";
                format = " {#90}  {#31}  {#32}  {#33}  {#34}  {#35}  {#36}  {#37}  {#38}  {#39}       {#38}  {#37}  {#36}  {#35}  {#34}  {#33}  {#32}  {#31}  {#90}";
              }
            ];
          };
        };
      };
    })

    (mkIf cfg.enableTUI {
      home.packages = [
        pkgs.trash-cli
        pkgs.fzf
      ];

      programs.xplr = {
        enable = true;
        extraConfig = builtins.readFile ./xplr.lua;
        plugins = {
          trash-cli = fetchFromGitHub {
            owner = "sayanarijit";
            repo = "trash-cli.xplr";
            rev = "2c5c8c64ec88c038e2075db3b1c123655dc446fa";
            sha256 = "0vp4lf4v53hh4ipygnrf3vng8qk5izfaz1g498klvbrcxk7srf51";
          };
          zoxide = fetchFromGitHub {
            owner = "sayanarijit";
            repo = "zoxide.xplr";
            rev = "e50fd35db5c05e750a74c8f54761922464c1ad5f";
            sha256 = "1f9y6va4xyn7zxmvkqys1y0kvwfvffbrwxmnfqmz4m4psgwz7l1m";
          };
          map = fetchFromGitHub {
            owner = "sayanarijit";
            repo = "map.xplr";
            rev = "ed774d21195246060ae2d9cae83f82c698e9d8e7";
            sha256 = "1qidg97l5z2jrq3alsd38jfa7qcqv0njm1f7lsl8x5p7gl9cln8v";
          };
          find = fetchFromGitHub {
            owner = "sayanarijit";
            repo = "find.xplr";
            rev = "5355d213a7063347f219975e71ddca4bdf8085c9";
            sha256 = "1909p3hxvsb2pv252wzv32vm1vwj88w83rgffnahakkd0bwn0vsq";
          };
          dual-pane = fetchFromGitHub {
            owner = "sayanarijit";
            repo = "dual-pane.xplr";
            rev = "db470860912fb9f36ef397329c0e42c2f76187b8";
            sha256 = "0xxrid3qx7pakzy8df9kh8hfm7jpwbrx5dh2695zl8k3byigb7qj";
          };
        };
      };
    })
  ];
}
