# Warning, this file is autogenerated by nix4vscode. Don't modify this manually.
{ pkgs, lib }:

let
  inherit (pkgs.stdenv) isDarwin isLinux isi686 isx86_64 isAarch32 isAarch64;
  vscode-utils = pkgs.vscode-utils;
  merge = lib.attrsets.recursiveUpdate;
in
merge
  (merge
    (merge
      (merge
      {
        "aaron-bond"."better-comments" = vscode-utils.extensionFromVscodeMarketplace {
          name = "better-comments";
          publisher = "aaron-bond";
          version = "3.0.2";
          sha256 = "15w1ixvp6vn9ng6mmcmv9ch0ngx8m85i1yabxdfn6zx3ypq802c5";

        };
        "alefragnani"."project-manager" = vscode-utils.extensionFromVscodeMarketplace {
          name = "project-manager";
          publisher = "alefragnani";
          version = "12.8.0";
          sha256 = "1gp2dd4xm5a4dmaikcng79mfcb8a24mddsdwpgg4bqshcz4q7n5h";

        };
        "bierner"."markdown-preview-github-styles" = vscode-utils.extensionFromVscodeMarketplace {
          name = "markdown-preview-github-styles";
          publisher = "bierner";
          version = "2.1.0";
          sha256 = "1fn9gdf3xj1drch4djn6c9lg94i2r9yjpfrf1a0y4v8q2zjk8sz8";

        };
        "coolbear"."systemd-unit-file" = vscode-utils.extensionFromVscodeMarketplace {
          name = "systemd-unit-file";
          publisher = "coolbear";
          version = "1.0.6";
          sha256 = "0sc0zsdnxi4wfdlmaqwb6k2qc21dgwx6ipvri36x7agk7m8m4736";

        };
        "dustypomerleau"."rust-syntax" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-syntax";
          publisher = "dustypomerleau";
          version = "0.6.1";
          sha256 = "0rccp8njr13jzsbr2jl9hqn74w7ji7b2spfd4ml6r2i43hz9gn53";

        };
        "eamodio"."gitlens" = vscode-utils.extensionFromVscodeMarketplace {
          name = "gitlens";
          publisher = "eamodio";
          version = "17.1.1";
          sha256 = "07lyd3s5g6w5piglqbsm808f620j1mc8lwbr4cm41gvpnkhnln46";

        };
        "editorconfig"."editorconfig" = vscode-utils.extensionFromVscodeMarketplace {
          name = "editorconfig";
          publisher = "editorconfig";
          version = "0.17.4";
          sha256 = "1hxzvrj65dnzhjk6qp7dy860gvl8n57wb8s8s6chdil04a2xi0ri";

        };
        "esbenp"."prettier-vscode" = vscode-utils.extensionFromVscodeMarketplace {
          name = "prettier-vscode";
          publisher = "esbenp";
          version = "11.0.0";
          sha256 = "1fcz8f4jgnf24kblf8m8nwgzd5pxs2gmrv235cpdgmqz38kf9n54";

        };
        "formulahendry"."code-runner" = vscode-utils.extensionFromVscodeMarketplace {
          name = "code-runner";
          publisher = "formulahendry";
          version = "0.12.2";
          sha256 = "0i5i0fpnf90pfjrw86cqbgsy4b7vb6bqcw9y2wh9qz6hgpm4m3jc";

        };
        "foxundermoon"."shell-format" = vscode-utils.extensionFromVscodeMarketplace {
          name = "shell-format";
          publisher = "foxundermoon";
          version = "7.2.5";
          sha256 = "0a874423xw7z6zjj7gzzl39jahrrqcf2r16zbcvncw23483m3yli";

        };
        "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot";
          publisher = "github";
          version = "1.331.0";
          sha256 = "106nwqz7m2vixvb11a1p87lvflg37srjy2qhb7amas9izxhj9ydd";

        };
        "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot-chat";
          publisher = "github";
          version = "0.27.3";
          sha256 = "021iifmfsaw29wmbhdcagnn2pqf9xlkdlryvlz0c29gh7infzg3g";

        };
        "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.27.2";
          sha256 = "06afix94nxb9vbkgmygg02pyczb09cmvr1l8d2b9alsxhk2i0r69";

        };
        "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-pull-request-github";
          publisher = "github";
          version = "0.110.0";
          sha256 = "09xc0bfbb64865ayzm18ijmn3f2h2qh4527243v85lv602xgm05f";

        };
        "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
          name = "todo-tree";
          publisher = "gruntfuggly";
          version = "0.0.226";
          sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";

        };
        "ironmansoftware"."powershellprotools" = vscode-utils.extensionFromVscodeMarketplace {
          name = "powershellprotools";
          publisher = "ironmansoftware";
          version = "2024.12.0";
          sha256 = "12yabm6ba69ha0m6l0732dg56jdp7pnw4fgp5dwsmn4j8xi5655k";

        };
        "jnoortheen"."nix-ide" = vscode-utils.extensionFromVscodeMarketplace {
          name = "nix-ide";
          publisher = "jnoortheen";
          version = "0.4.18";
          sha256 = "16n9nzm9wdmhrcxhlw0d9a8195w0m8nh4gzbac4432jw8mkvbk5r";

        };
        "jscearcy"."rust-doc-viewer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-doc-viewer";
          publisher = "jscearcy";
          version = "4.2.0";
          sha256 = "0fizwx057nghy8k0xz66f1narxps47d5asl26jr7aq1h1ypncnn7";

        };
        "markis"."code-coverage" = vscode-utils.extensionFromVscodeMarketplace {
          name = "code-coverage";
          publisher = "markis";
          version = "1.12.0";
          sha256 = "1in99l6nxbqffqrn3r1xrpq9ajjrn3r7x791by6sv2n357j2908d";

        };
        "matthewpi"."caddyfile-support" = vscode-utils.extensionFromVscodeMarketplace {
          name = "caddyfile-support";
          publisher = "matthewpi";
          version = "0.4.0";
          sha256 = "1fjhirybvb92frqj1ssh49a73q497ny69z9drdjlkpaccpbvb0r7";

        };
        "mkhl"."direnv" = vscode-utils.extensionFromVscodeMarketplace {
          name = "direnv";
          publisher = "mkhl";
          version = "0.17.0";
          sha256 = "1n2qdd1rspy6ar03yw7g7zy3yjg9j1xb5xa4v2q12b0y6dymrhgn";

        };
        "ms-azuretools"."vscode-docker" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-docker";
          publisher = "ms-azuretools";
          version = "2.0.0";
          sha256 = "0sjnbzark9vqbzzg1z2zh9zr2prqd5xa2fdkhdsjz73x99xaq733";

        };
        "ms-dotnettools"."vscode-dotnet-runtime" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-dotnet-runtime";
          publisher = "ms-dotnettools";
          version = "2.3.5";
          sha256 = "0w9j94skiy2ipjl2lra2z3lfzv9ykp6vv4is4czjnw3gv023aa8y";

        };
        "ms-python"."black-formatter" = vscode-utils.extensionFromVscodeMarketplace {
          name = "black-formatter";
          publisher = "ms-python";
          version = "2025.2.0";
          sha256 = "0kiz9rv62sg6kj6h3csmxr1jzv6falcgylspq7ayjainkrr73yqh";

        };
        "ms-python"."gather" = vscode-utils.extensionFromVscodeMarketplace {
          name = "gather";
          publisher = "ms-python";
          version = "2025.4.0";
          sha256 = "1qn2drgbv55h2n48bwnm7xvcyjxm9swbbqa8chrj4lzhcbsrzhx5";

        };
        "ms-python"."isort" = vscode-utils.extensionFromVscodeMarketplace {
          name = "isort";
          publisher = "ms-python";
          version = "2025.0.0";
          sha256 = "1bpa83r1bsqlanhb0j86aprzvvjsr1r4kwbbkmykpqiwzlz7s2wz";

        };
        "ms-python"."mypy-type-checker" = vscode-utils.extensionFromVscodeMarketplace {
          name = "mypy-type-checker";
          publisher = "ms-python";
          version = "2025.2.0";
          sha256 = "125vr6irqn5q78ydgrql3lfkwjn264amzv52qkh8hv0w5r4dg7sl";

        };
        "ms-python"."pylint" = vscode-utils.extensionFromVscodeMarketplace {
          name = "pylint";
          publisher = "ms-python";
          version = "2025.2.0";
          sha256 = "0s3lj4kgblprxkl9qcdiy2brwmaq1l7v1camvb9rpd50xgz9h6nx";

        };
        "ms-python"."vscode-pylance" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-pylance";
          publisher = "ms-python";
          version = "2025.5.1";
          sha256 = "1davggj8d0fs0vlgd4qn9hmxp5hwixvfh3bnj3ii6kdh7sldcyg8";

        };
        "ms-vscode"."powershell" = vscode-utils.extensionFromVscodeMarketplace {
          name = "powershell";
          publisher = "ms-vscode";
          version = "2025.0.0";
          sha256 = "141n9zpabm76l940ap5x9wf5906bx6548slb6jncyf5d4ismybd8";

        };
        "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.120.0";
          sha256 = "0p8rx867pdwyzx1bcjf069zzi8nfvhb3bjv7q3v8dd43l4n2dmhg";

        };
        "pkief"."material-icon-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-icon-theme";
          publisher = "pkief";
          version = "5.23.0";
          sha256 = "09xcjqfqjrzzy4d9vlni52zbg3c3ffmp9sbmjjhz5a61sam8xscy";

        };
        "pspester"."pester-test" = vscode-utils.extensionFromVscodeMarketplace {
          name = "pester-test";
          publisher = "pspester";
          version = "2023.7.7";
          sha256 = "1rzm57rq5fmaz3ygai8yff96sank5fvrzklw94jq0s1gbfnx9ylm";

        };
        "rogalmic"."bash-debug" = vscode-utils.extensionFromVscodeMarketplace {
          name = "bash-debug";
          publisher = "rogalmic";
          version = "0.3.9";
          sha256 = "0n7lyl8gxrpc26scffbrfczdj0n9bcil9z83m4kzmz7k5dj59hbz";

        };
        "ruschaaf"."extended-embedded-languages" = vscode-utils.extensionFromVscodeMarketplace {
          name = "extended-embedded-languages";
          publisher = "ruschaaf";
          version = "1.3.0";
          sha256 = "17y48hslb2lm187qkr3qxhh5793canrj5yb5mr40y6hz6jg6cq60";

        };
        "tamasfe"."even-better-toml" = vscode-utils.extensionFromVscodeMarketplace {
          name = "even-better-toml";
          publisher = "tamasfe";
          version = "0.21.2";
          sha256 = "0208cms054yj2l8pz9jrv3ydydmb47wr4i0sw8qywpi8yimddf11";

        };
        "tylerleonhardt"."vscode-inline-values-powershell" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-inline-values-powershell";
          publisher = "tylerleonhardt";
          version = "0.0.7";
          sha256 = "13m1yzn7g1hbpww6mcbz8vzv06dll9nzin4jyv8cbs85lam3gpcl";

        };
        "wayou"."vscode-todo-highlight" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-todo-highlight";
          publisher = "wayou";
          version = "1.0.5";
          sha256 = "1sg4zbr1jgj9adsj3rik5flcn6cbr4k2pzxi446rfzbzvcqns189";

        };
        "zhuangtongfa"."material-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-theme";
          publisher = "zhuangtongfa";
          version = "3.19.0";
          sha256 = "1z3wiacb2m7hvpfhn6qs710lsaxpy7c56jbjckccvqi705w9firb";

        };
      }
        (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) {
          "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
            name = "terraform";
            publisher = "hashicorp";
            version = "2.34.4";
            sha256 = "1ppyvdmj2lvixhyzyadrbhxhd7f8hln68x058bxj943zx2rs27wa";
            arch = "linux-x64";

          };
          "ms-dotnettools"."csdevkit" = vscode-utils.extensionFromVscodeMarketplace {
            name = "csdevkit";
            publisher = "ms-dotnettools";
            version = "1.20.35";
            sha256 = "0m4ila5h83m0051lp1r98fq59cy5hw8zz91vdfchcbbsg4ddm6vf";
            arch = "linux-x64";

          };
          "ms-dotnettools"."csharp" = vscode-utils.extensionFromVscodeMarketplace {
            name = "csharp";
            publisher = "ms-dotnettools";
            version = "2.80.16";
            sha256 = "1iwlp587c2wj6snq2f2jzjxif0qzkypliylc9yadadn0h06g45dg";
            arch = "linux-x64";

          };
          "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
            name = "debugpy";
            publisher = "ms-python";
            version = "2025.8.0";
            sha256 = "1d9mdx5dwpi8x6wvb0zw5qjvf3yrwrc5jhnjaikydf61zgzp9ac9";
            arch = "linux-x64";

          };
          "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
            name = "python";
            publisher = "ms-python";
            version = "2025.6.1";
            sha256 = "1n3jnmwgddc014m35nfac5kz06hp9qr2plimxdla7lhyz0vhlgyx";
            arch = "linux-x64";

          };
          "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-xml";
            publisher = "redhat";
            version = "0.29.0";
            sha256 = "0dvkrsc4v6pxran4ygy5b0pg9x53a6b6w0gp7l645zf26nj16wqn";
            arch = "linux-x64";

          };
          "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
            name = "rust-analyzer";
            publisher = "rust-lang";
            version = "0.3.2490";
            sha256 = "190fd77lk299r09479z0jzsa05s48b6q13892jgln6px5q0x785x";
            arch = "linux-x64";

          };
        }))
      (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) {
        "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
          name = "terraform";
          publisher = "hashicorp";
          version = "2.34.4";
          sha256 = "1hhvsnivamvi9ll4q9aqlrrdkx4z542qmmnb8b43zb8n1dc6zg21";
          arch = "linux-arm64";

        };
        "ms-dotnettools"."csdevkit" = vscode-utils.extensionFromVscodeMarketplace {
          name = "csdevkit";
          publisher = "ms-dotnettools";
          version = "1.20.35";
          sha256 = "0xfyjal2vff5n4c19d1xgl4ngc1w57ma7hz4psx7wpa70sqgj568";
          arch = "linux-arm64";

        };
        "ms-dotnettools"."csharp" = vscode-utils.extensionFromVscodeMarketplace {
          name = "csharp";
          publisher = "ms-dotnettools";
          version = "2.80.16";
          sha256 = "1jz0ww1h815q015s5xpxhvyw8l3ja3xg9a19q4sfc679prkfg4nw";
          arch = "linux-arm64";

        };
        "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
          name = "debugpy";
          publisher = "ms-python";
          version = "2025.8.0";
          sha256 = "1ap6kisb9a05bda5v2sdw8w69n0ksj6m1imzqvq9qr7l3ljbcn0r";
          arch = "linux-arm64";

        };
        "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
          name = "python";
          publisher = "ms-python";
          version = "2025.6.1";
          sha256 = "0fyqrii331q4zcfl0ga43yj77882711z3pjxkv9a7cz846sgv0dq";
          arch = "linux-arm64";

        };
        "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-analyzer";
          publisher = "rust-lang";
          version = "0.3.2490";
          sha256 = "02ynfiv918gdhny2kv3z2aah2jkknrdknlii1pb7a75q1fwfqmf4";
          arch = "linux-arm64";

        };
      }))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {
      "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
        name = "terraform";
        publisher = "hashicorp";
        version = "2.34.4";
        sha256 = "1piy2bp78hny2zcbwms8i06jl5i72p8mjhx462w85zbdim9i25y1";
        arch = "darwin-x64";

      };
      "ms-dotnettools"."csdevkit" = vscode-utils.extensionFromVscodeMarketplace {
        name = "csdevkit";
        publisher = "ms-dotnettools";
        version = "1.20.35";
        sha256 = "0a5z87k41yyqh1yiwqd6p1wa20ksm9jfwg7g9x4m0jsvflvqdfjv";
        arch = "darwin-x64";

      };
      "ms-dotnettools"."csharp" = vscode-utils.extensionFromVscodeMarketplace {
        name = "csharp";
        publisher = "ms-dotnettools";
        version = "2.80.16";
        sha256 = "0rs2pr6gdpj2ff1q5q658rrkdp7qk0j0nxxnl2n95ngqfdszj4ya";
        arch = "darwin-x64";

      };
      "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
        name = "debugpy";
        publisher = "ms-python";
        version = "2025.8.0";
        sha256 = "1ggxx2ym2czavbi2dk9r1csynm051q95qlfk7ya26dcfqq3jwrjb";
        arch = "darwin-x64";

      };
      "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
        name = "python";
        publisher = "ms-python";
        version = "2025.6.1";
        sha256 = "1rwk0hhck3vdwk698ndcdzaajrs1r7vwhhk4p9wv91svr81cplj4";
        arch = "darwin-x64";

      };
      "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-xml";
        publisher = "redhat";
        version = "0.29.0";
        sha256 = "1qzq3b4a66iq6xci6im7kb2fpjxdr2vvw2vshd47kvjxxb613ybc";
        arch = "darwin-x64";

      };
      "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
        name = "rust-analyzer";
        publisher = "rust-lang";
        version = "0.3.2490";
        sha256 = "0qjwvxknk8ias8pk3ins2lp72fn9x1n7z6v2jqpgrgcnyfcaic1a";
        arch = "darwin-x64";

      };
    }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {
    "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
      name = "terraform";
      publisher = "hashicorp";
      version = "2.34.4";
      sha256 = "1pw3ql7ppi8ni9p4wlg2wvi0l0ablnnfq154qr19v1z4mvp3fdc1";
      arch = "darwin-arm64";

    };
    "ms-dotnettools"."csdevkit" = vscode-utils.extensionFromVscodeMarketplace {
      name = "csdevkit";
      publisher = "ms-dotnettools";
      version = "1.20.35";
      sha256 = "0z8l4wnzc32r91f69pksshwl3vy8cg5bqm8lq447ma1sq112hnrs";
      arch = "darwin-arm64";

    };
    "ms-dotnettools"."csharp" = vscode-utils.extensionFromVscodeMarketplace {
      name = "csharp";
      publisher = "ms-dotnettools";
      version = "2.80.16";
      sha256 = "176dvc9vyq40hpsrrxnslc7x38h9zya29va02wkpsjzc1kh9klra";
      arch = "darwin-arm64";

    };
    "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
      name = "debugpy";
      publisher = "ms-python";
      version = "2025.8.0";
      sha256 = "06vvc5kf72kx23j3vqbr9d62l96fxp5zy8r3avhx88f92cacxrbf";
      arch = "darwin-arm64";

    };
    "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
      name = "python";
      publisher = "ms-python";
      version = "2025.6.1";
      sha256 = "1hrkknw22q08xc3aqi1m0g07x9llvvz955w02xqgg6ypjkf38ksh";
      arch = "darwin-arm64";

    };
    "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
      name = "vscode-xml";
      publisher = "redhat";
      version = "0.29.0";
      sha256 = "0b8kb5s4xjw3nh48w665j069hf4f46cv5564kyrzhwd27735cx2j";
      arch = "darwin-arm64";

    };
    "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
      name = "rust-analyzer";
      publisher = "rust-lang";
      version = "0.3.2490";
      sha256 = "1a85sxwp00s3nlzg3i64y406dh9rprpwgi2h7wqiwr3l4vr22js8";
      arch = "darwin-arm64";

    };
  })
