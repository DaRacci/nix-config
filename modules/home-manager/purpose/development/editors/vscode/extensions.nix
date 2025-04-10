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
          version = "17.0.1";
          sha256 = "0s22bqy2k971h1iv1fq28c4lh72x53fx6304il2vmavxaisn216k";

        };
        "editorconfig"."editorconfig" = vscode-utils.extensionFromVscodeMarketplace {
          name = "editorconfig";
          publisher = "editorconfig";
          version = "0.17.2";
          sha256 = "1s0a2zgxk6qxl6lzw6klkn8xhsxk0l87vcbms2k8535kvscbwbay";

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
          version = "1.297.0";
          sha256 = "1gfiyi5sy7dnhnalbdawpx0cwflnknpi0rpc9k28wj8czxhz8lji";

        };
        "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot-chat";
          publisher = "github";
          version = "0.25.1";
          sha256 = "0qq55khxbn0r778sifbnbd3g8bv06012dixhhybdh74851zfj7vp";

        };
        "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.27.1";
          sha256 = "0pq97nl5h170r5cwsvps9z059lvj7a9aik2w84fnn3mjficrlwlq";

        };
        "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-pull-request-github";
          publisher = "github";
          version = "0.108.0";
          sha256 = "10p76fi8516gawjm9bvxgdw1val4mwrbmf3z7b7qld7kr5rlzlqq";

        };
        "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
          name = "todo-tree";
          publisher = "gruntfuggly";
          version = "0.0.226";
          sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";

        };
        "jnoortheen"."nix-ide" = vscode-utils.extensionFromVscodeMarketplace {
          name = "nix-ide";
          publisher = "jnoortheen";
          version = "0.4.16";
          sha256 = "0mhc58lzdn153yskqi6crvzx6pgi1d72mdhmnpc4qkbf1wx47l9i";

        };
        "jscearcy"."rust-doc-viewer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-doc-viewer";
          publisher = "jscearcy";
          version = "4.2.0";
          sha256 = "0fizwx057nghy8k0xz66f1narxps47d5asl26jr7aq1h1ypncnn7";

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
          version = "1.29.5";
          sha256 = "1rj1bw16vw2zikpjgdm3bwdx1g1m76w4a4wn3q29ka7y5yl9a22r";

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
          version = "2022.3.2";
          sha256 = "0624b0bxk5q3y9pnggqpfgf7rj6363nbzcrzv3p0pzswrxyi443i";

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
          version = "2025.4.1";
          sha256 = "0ldgacr9yqaj9zmxnj5rkkamr1044cf9rfjqsv7qkvpyw4f397ax";

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
          version = "0.119.0";
          sha256 = "0zqw0iq4z6q8p47x01cb3lp5pkmn0fdls9i3mg424da3z4qaxajb";

        };
        "pkief"."material-icon-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-icon-theme";
          publisher = "pkief";
          version = "5.21.2";
          sha256 = "00p10xzccy6y3qk2fsa21jibkq9335ac9sl9abwwg8l2wimhaiqw";

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
            version = "2.34.3";
            sha256 = "0ladgyija724flxmagf9amj80r00c9yg2v5rjmzglj0m3wfzy56b";
            arch = "linux-x64";

          };
          "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
            name = "debugpy";
            publisher = "ms-python";
            version = "2025.6.0";
            sha256 = "0x7j5hbf6q5v1vh11sqqx45ysv7wnn1bn9iyik68wvq6xrzcds72";
            arch = "linux-x64";

          };
          "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
            name = "python";
            publisher = "ms-python";
            version = "2025.4.0";
            sha256 = "149hpb3927mk0fmx9hj7whgbrfw5g4a38ka583a25c5pwr75rs00";
            arch = "linux-x64";

          };
          "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-xml";
            publisher = "redhat";
            version = "0.28.0";
            sha256 = "0pipcl1r6sngf6dq3cmz3g56ww78r10r8acqjzmri6l5kxpx22ah";
            arch = "linux-x64";

          };
          "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
            name = "rust-analyzer";
            publisher = "rust-lang";
            version = "0.3.2370";
            sha256 = "0rndfyi85167hgz8nhv1ipwzjyk8814779f7sl0qcz9ydxqgsima";
            arch = "linux-x64";

          };
        }))
      (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) {
        "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
          name = "terraform";
          publisher = "hashicorp";
          version = "2.34.3";
          sha256 = "0z3c1g71dp8ww8irlgdlhwnvqrksxplh8k4izvjg55mycj34pigp";
          arch = "linux-arm64";

        };
        "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
          name = "debugpy";
          publisher = "ms-python";
          version = "2025.6.0";
          sha256 = "1kh4aiiqba9ahbbm6z53mp9kv7ydijivslvmlm7qidnvmfdw256p";
          arch = "linux-arm64";

        };
        "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
          name = "python";
          publisher = "ms-python";
          version = "2025.4.0";
          sha256 = "118lq055dxv0j9cv67frayhzmd1w1rq27a34s60i00ljc46vr26h";
          arch = "linux-arm64";

        };
        "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-analyzer";
          publisher = "rust-lang";
          version = "0.3.2370";
          sha256 = "1kr6q783ma0aylagyzhcc4l5fxzx7giwa1alhmmn89lrja4j349n";
          arch = "linux-arm64";

        };
      }))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {
      "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
        name = "terraform";
        publisher = "hashicorp";
        version = "2.34.3";
        sha256 = "0kz2xx4i6wa52ym4nmjfb9j28lbk4hmcwkpifb23vhnni0l20d4f";
        arch = "darwin-x64";

      };
      "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
        name = "debugpy";
        publisher = "ms-python";
        version = "2025.6.0";
        sha256 = "1py3sx42bq149vb4s0ccs84f5b5awm8kzhb939z7w8abv1lmbjqj";
        arch = "darwin-x64";

      };
      "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
        name = "python";
        publisher = "ms-python";
        version = "2025.4.0";
        sha256 = "1yj06cqaj41apm7gg03csjklr253bsv4fd8bmp0afa8j4mqj744s";
        arch = "darwin-x64";

      };
      "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-xml";
        publisher = "redhat";
        version = "0.28.0";
        sha256 = "1mdjb3app4b34fzxi34rqgz4jjn0vhwjyhlgh7rlcnavqsk4amzg";
        arch = "darwin-x64";

      };
      "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
        name = "rust-analyzer";
        publisher = "rust-lang";
        version = "0.3.2370";
        sha256 = "1zmqkr0imzvjrw33ih1wyyw6aysp7vn6fjwb7msadbhag3x94gy5";
        arch = "darwin-x64";

      };
    }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {
    "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
      name = "terraform";
      publisher = "hashicorp";
      version = "2.34.3";
      sha256 = "0bcngqbk7mp4131dqb0x1cw32m7ssr8c0sx819d8vvr98wgp2kwh";
      arch = "darwin-arm64";

    };
    "ms-python"."debugpy" = vscode-utils.extensionFromVscodeMarketplace {
      name = "debugpy";
      publisher = "ms-python";
      version = "2025.6.0";
      sha256 = "1fbwg2nm2srs5ps65jahmcpgkp6nvg0vzamzbn7qg5vsf4zr3fac";
      arch = "darwin-arm64";

    };
    "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
      name = "python";
      publisher = "ms-python";
      version = "2025.4.0";
      sha256 = "16pzq9sm4lmknv960pacr9i90v5mk1zbp2wi2r8i03y32ig489f5";
      arch = "darwin-arm64";

    };
    "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
      name = "vscode-xml";
      publisher = "redhat";
      version = "0.28.0";
      sha256 = "1wzb8rxf420ggrnl4z83zps2n6k02mqk32yxvaa8fqcvscf0c7jw";
      arch = "darwin-arm64";

    };
    "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
      name = "rust-analyzer";
      publisher = "rust-lang";
      version = "0.3.2370";
      sha256 = "0jwhbqxjhxwz6a9285k96pdbjmfc1sqzib6qwjhkiszss84856ml";
      arch = "darwin-arm64";

    };
  })
