{
  config,
  lib,
  pkgs,
  endpoints,
  tailRoots,
  lsRoots,
  catRoots,
}:
let
  inherit (lib) getExe';

  systemdPkg = config.systemd.package;
  systemctl = getExe' systemdPkg "systemctl";
  journalctl = getExe' systemdPkg "journalctl";
  systemdAnalyze = getExe' systemdPkg "systemd-analyze";
  ps = getExe' pkgs.procps "ps";
  free = getExe' pkgs.procps "free";
  df = getExe' pkgs.coreutils "df";
  uptime = getExe' pkgs.coreutils "uptime";
  ss = getExe' pkgs.iproute2 "ss";
  curl = getExe' pkgs.curl "curl";
in
{
  contracts = {
    unit_name = {
      type = "string_len";
      min = 1;
      max = 128;
    };

    lines = {
      type = "int_range";
      min = 1;
      max = 2000;
    };

    # State properties only, so `show` cannot read Environment.
    property = {
      type = "enum";
      values = [
        "ActiveState"
        "SubState"
        "UnitFileState"
        "NRestarts"
        "ExecMainStatus"
        "MemoryCurrent"
        "MainPID"
        "TasksCurrent"
      ];
    };

    unit_state = {
      type = "enum";
      values = [
        "active"
        "inactive"
        "failed"
        "running"
        "exited"
        "waiting"
      ];
    };

    priority = {
      type = "enum";
      values = [
        "emerg"
        "alert"
        "crit"
        "err"
        "warning"
        "notice"
        "info"
        "debug"
      ];
    };

    when = {
      type = "string_len";
      min = 1;
      max = 64;
    };

  }
  // lib.optionalAttrs (endpoints != [ ]) {
    endpoint = {
      type = "enum";
      values = endpoints;
    };

    seconds = {
      type = "int_range";
      min = 1;
      max = 20;
    };
  }
  // lib.optionalAttrs (tailRoots != [ ]) {
    tail_path = {
      type = "path";
      root_set = "tail";
    };
  }
  // lib.optionalAttrs (lsRoots != [ ]) {
    ls_path = {
      type = "path";
      root_set = "ls";
    };
  }
  // lib.optionalAttrs (catRoots != [ ]) {
    cat_path = {
      type = "path";
      root_set = "cat";
    };
  };

  root_sets =
    lib.optionalAttrs (tailRoots != [ ]) {
      tail = tailRoots;
    }
    // lib.optionalAttrs (lsRoots != [ ]) {
      ls = lsRoots;
    }
    // lib.optionalAttrs (catRoots != [ ]) {
      cat = catRoots;
    };

  flag_groups.pager = [
    "--no-pager"
    "--full"
  ];

  rules = [
    {
      command = "systemctl";
      action = {
        type = "run";
        binary = systemctl;
        args = [ ];
        timeout = "15s";
      };
      flag_groups = [ "pager" ];

      subcommands = [
        {
          name = "status";
          flags = [ "-n={lines}" ];
          args = [ "{unit:unit_name}" ];
        }
        {
          name = "is-active";
          args = [ "{unit:unit_name}" ];
        }
        {
          name = "is-enabled";
          args = [ "{unit:unit_name}" ];
        }
        {
          name = "is-failed";
          args = [ "{unit:unit_name}" ];
        }
        {
          name = "show";
          flags = [ "--property={property}" ];
          args = [ "{unit:unit_name}" ];
        }
        {
          name = "list-units";
          flags = [ "--state={unit_state}" ];
        }
        { name = "list-timers"; }
      ];
    }

    {
      command = "journalctl";
      action = {
        type = "run";
        binary = journalctl;
        args = [ ];
        timeout = "20s";
      };
      flag_groups = [ "pager" ];
      flags = [
        "-u={unit_name}"
        "-n={lines}"
        "--lines={lines}"
        "-p={priority}"
        "--priority={priority}"
        "--since={when}"
        "-b"
        "--disk-usage"
        "--list-boots"
        "--utc"
      ];
    }

    {
      command = "df";
      action = {
        type = "run";
        binary = df;
        args = [ ];
        timeout = "10s";
      };
      flags = [
        "-h"
        "-H"
        "-i"
        "-T"
      ];
    }

    {
      command = "free";
      action = {
        type = "run";
        binary = free;
        args = [ ];
        timeout = "10s";
      };
      flags = [
        "-h"
        "-m"
        "-g"
        "-w"
      ];
    }

    {
      command = "ps";
      action = {
        type = "run";
        binary = ps;
        args = [ ];
        timeout = "10s";
      };
      flags = [
        "-e"
        "-f"
        "-ef"
        "-A"
        "-eF"
      ];
    }

    {
      command = "uptime";
      action = {
        type = "run";
        binary = uptime;
        args = [ ];
        timeout = "10s";
      };
      flags = [
        "-p"
        "-s"
      ];
    }

    {
      command = "ss";
      action = {
        type = "run";
        binary = ss;
        args = [ ];
        timeout = "10s";
      };
      flags = [
        "-t"
        "-u"
        "-l"
        "-n"
        "-a"
        "-s"
        "-4"
        "-6"
      ];
    }

    {
      command = "systemd-analyze";
      action = {
        type = "run";
        binary = systemdAnalyze;
        args = [ ];
        timeout = "15s";
      };
      flag_groups = [ "pager" ];
      subcommands = [
        { name = "blame"; }
        { name = "critical-chain"; }
        { name = "time"; }
      ];
    }
  ]
  ++ lib.optional (endpoints != [ ]) {
    command = "curl";
    flags = [
      "-s"
      "-S"
      "--max-time={seconds}"
    ];
    args = [ "{url:endpoint}" ];
    action = {
      type = "run";
      binary = curl;
      args = [ ];
      timeout = "25s";
    };
  }
  ++ lib.optional (tailRoots != [ ]) {
    command = "tail";
    flags = [ "-n={lines}" ];
    args = [ "{path:tail_path}" ];
    action = {
      type = "tail_file";
      path_capture = "path";
      lines_capture = "lines";
      default_lines = 200;
      root_set = "tail";
    };
  }
  ++ lib.optional (lsRoots != [ ]) {
    command = "ls";
    args = [ "{path:ls_path}" ];
    action = {
      type = "list_dir";
      path_capture = "path";
      root_set = "ls";
    };
  }
  ++ lib.optional (catRoots != [ ]) {
    command = "cat";
    args = [ "{path:cat_path}" ];
    action = {
      type = "read_file";
      path_capture = "path";
      root_set = "cat";
    };
  };
}
