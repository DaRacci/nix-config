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
        "pkief"."material-icon-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-icon-theme";
          publisher = "pkief";
          version = "5.19.0";
          sha256 = "16ly295r3ibi42dhj24iks7b8mz0blw4mrq6g9v7w3l1lf45y3cf";

        };
        "alefragnani"."project-manager" = vscode-utils.extensionFromVscodeMarketplace {
          name = "project-manager";
          publisher = "alefragnani";
          version = "12.8.0";
          sha256 = "1gp2dd4xm5a4dmaikcng79mfcb8a24mddsdwpgg4bqshcz4q7n5h";

        };
        "fill-labs"."dependi" = vscode-utils.extensionFromVscodeMarketplace {
          name = "dependi";
          publisher = "fill-labs";
          version = "0.7.13";
          sha256 = "1dsd4qal7wmhhbzv5jmcrf8igm20dnr256s2gp1m5myhj08qlzay";

        };
        "ms-vscode"."powershell" = vscode-utils.extensionFromVscodeMarketplace {
          name = "powershell";
          publisher = "ms-vscode";
          version = "2025.1.0";
          sha256 = "1g7a36037wm4l0bj2sgywznl40dg2qxsi1p1p8zyhmamssw7ypx0";

        };
        "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-pull-request-github";
          publisher = "github";
          version = "0.105.2025020615";
          sha256 = "0r4khhwqfdapdzd7bh6lvwinhb63iqfl8ldb0z7sgpq430zsdj5q";

        };
        "jnoortheen"."nix-ide" = vscode-utils.extensionFromVscodeMarketplace {
          name = "nix-ide";
          publisher = "jnoortheen";
          version = "0.4.12";
          sha256 = "0rdq9wnqfrj8k1g5fcaam5iahzd16bdpi3sa0n2gi0rh02kg55fy";

        };
        "ms-azuretools"."vscode-docker" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-docker";
          publisher = "ms-azuretools";
          version = "1.29.4";
          sha256 = "1nhrp43gh4pwsdy0d8prndx2l0mrczf1kirjl1figrmhcp7h4q4g";

        };
        "ruschaaf"."extended-embedded-languages" = vscode-utils.extensionFromVscodeMarketplace {
          name = "extended-embedded-languages";
          publisher = "ruschaaf";
          version = "1.3.0";
          sha256 = "17y48hslb2lm187qkr3qxhh5793canrj5yb5mr40y6hz6jg6cq60";

        };
        "formulahendry"."code-runner" = vscode-utils.extensionFromVscodeMarketplace {
          name = "code-runner";
          publisher = "formulahendry";
          version = "0.12.2";
          sha256 = "0i5i0fpnf90pfjrw86cqbgsy4b7vb6bqcw9y2wh9qz6hgpm4m3jc";

        };
        "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot-chat";
          publisher = "github";
          version = "0.24.2025020602";
          sha256 = "04lwqbclqs9zjp39k4n0z5pjp5haqm9jm8jpng0xc8c4xhkq2rxj";

        };
        "esbenp"."prettier-vscode" = vscode-utils.extensionFromVscodeMarketplace {
          name = "prettier-vscode";
          publisher = "esbenp";
          version = "11.0.0";
          sha256 = "1fcz8f4jgnf24kblf8m8nwgzd5pxs2gmrv235cpdgmqz38kf9n54";

        };
        "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot";
          publisher = "github";
          version = "1.266.1363";
          sha256 = "1n25cc34k98v4w5w8y9laz0kbxsg3470c6wy0rxji388jdyzz955";

        };
        "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.118.2025020720";
          sha256 = "1misizc4hjg7agryrh0wy28q5wv99nrz43b98bvdhl9vv0p3bbvz";

        };
        "foxundermoon"."shell-format" = vscode-utils.extensionFromVscodeMarketplace {
          name = "shell-format";
          publisher = "foxundermoon";
          version = "7.2.5";
          sha256 = "0a874423xw7z6zjj7gzzl39jahrrqcf2r16zbcvncw23483m3yli";

        };
        "rogalmic"."bash-debug" = vscode-utils.extensionFromVscodeMarketplace {
          name = "bash-debug";
          publisher = "rogalmic";
          version = "0.3.9";
          sha256 = "0n7lyl8gxrpc26scffbrfczdj0n9bcil9z83m4kzmz7k5dj59hbz";

        };
        "jscearcy"."rust-doc-viewer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-doc-viewer";
          publisher = "jscearcy";
          version = "4.2.0";
          sha256 = "0fizwx057nghy8k0xz66f1narxps47d5asl26jr7aq1h1ypncnn7";

        };
        "mkhl"."direnv" = vscode-utils.extensionFromVscodeMarketplace {
          name = "direnv";
          publisher = "mkhl";
          version = "0.17.0";
          sha256 = "1n2qdd1rspy6ar03yw7g7zy3yjg9j1xb5xa4v2q12b0y6dymrhgn";

        };
        "bierner"."markdown-preview-github-styles" = vscode-utils.extensionFromVscodeMarketplace {
          name = "markdown-preview-github-styles";
          publisher = "bierner";
          version = "2.1.0";
          sha256 = "1fn9gdf3xj1drch4djn6c9lg94i2r9yjpfrf1a0y4v8q2zjk8sz8";

        };
        "eamodio"."gitlens" = vscode-utils.extensionFromVscodeMarketplace {
          name = "gitlens";
          publisher = "eamodio";
          version = "2025.2.804";
          sha256 = "04kf98qy5vsh16nn4ydrl8nb47hbwafpjcfj2qrl7xvf9jshw2bb";

        };
        "editorconfig"."editorconfig" = vscode-utils.extensionFromVscodeMarketplace {
          name = "editorconfig";
          publisher = "editorconfig";
          version = "0.16.7";
          sha256 = "154xgkqsfm2cky0h7cq76ry3k084w33ydwn7s7c82a0f34f8rchf";

        };
        "dustypomerleau"."rust-syntax" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-syntax";
          publisher = "dustypomerleau";
          version = "0.6.1";
          sha256 = "0rccp8njr13jzsbr2jl9hqn74w7ji7b2spfd4ml6r2i43hz9gn53";

        };
        "coolbear"."systemd-unit-file" = vscode-utils.extensionFromVscodeMarketplace {
          name = "systemd-unit-file";
          publisher = "coolbear";
          version = "1.0.6";
          sha256 = "0sc0zsdnxi4wfdlmaqwb6k2qc21dgwx6ipvri36x7agk7m8m4736";

        };
        "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
          name = "todo-tree";
          publisher = "gruntfuggly";
          version = "0.0.226";
          sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";

        };
        "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.27.1";
          sha256 = "0pq97nl5h170r5cwsvps9z059lvj7a9aik2w84fnn3mjficrlwlq";

        };
        "zhuangtongfa"."material-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-theme";
          publisher = "zhuangtongfa";
          version = "3.18.0";
          sha256 = "0iwz7rzl5gmgbr3ihgaqq26rli2w7zsdj8wmcnn3pzwxazmlbrrx";

        };
        "matthewpi"."caddyfile-support" = vscode-utils.extensionFromVscodeMarketplace {
          name = "caddyfile-support";
          publisher = "matthewpi";
          version = "0.4.0";
          sha256 = "1fjhirybvb92frqj1ssh49a73q497ny69z9drdjlkpaccpbvb0r7";

        };
        "tamasfe"."even-better-toml" = vscode-utils.extensionFromVscodeMarketplace {
          name = "even-better-toml";
          publisher = "tamasfe";
          version = "0.21.2";
          sha256 = "0208cms054yj2l8pz9jrv3ydydmb47wr4i0sw8qywpi8yimddf11";

        };
      }
        (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) {
          "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
            name = "rust-analyzer";
            publisher = "rust-lang";
            version = "0.4.2296";
            sha256 = "1mdwh0q52d6hshkp4mavg8ygvpmlczrms5njzsdvqfryvyl0ihga";
            arch = "linux-x64";

          };
          "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-xml";
            publisher = "redhat";
            version = "0.28.2025012908";
            sha256 = "0zhz0s8jrrzzyml0w17i9kj21imm15l69asa3nkwkkp7n6iz507y";
            arch = "linux-x64";

          };
          "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
            name = "terraform";
            publisher = "hashicorp";
            version = "2.34.2025012311";
            sha256 = "0zzp6rdsv8r116wv0hcycip45l8nr5g8xgfdvm2vx6ly0ph4xj7v";
            arch = "linux-x64";

          };
        }))
      (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) {
        "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
          name = "terraform";
          publisher = "hashicorp";
          version = "2.34.2025012311";
          sha256 = "1fq9dscx66ch41jhjqsg22ra40ml8hcqapxs5gpk7q09jd0mdlng";
          arch = "linux-arm64";

        };
        "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-analyzer";
          publisher = "rust-lang";
          version = "0.4.2296";
          sha256 = "1czghbaswsapwp0plmn9nmrflxxjhj047wwl4l13dkfgswfqxkk7";
          arch = "linux-arm64";

        };
        "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-xml";
          publisher = "redhat";
          version = "0.28.2025012908";
          sha256 = "07fxmm9aax3c3f4am6l7pwqj1p498cz1sjnwc5b874jvp92586xl";
          arch = "linux-arm64";

        };
      }))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {
      "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
        name = "rust-analyzer";
        publisher = "rust-lang";
        version = "0.4.2296";
        sha256 = "0i3w6immpxpf20qn717vv7h9pl68j5npvsapbwxs8hazd8kcibmb";
        arch = "darwin-x64";

      };
      "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
        name = "terraform";
        publisher = "hashicorp";
        version = "2.34.2025012311";
        sha256 = "1safkh5853sndiakk73snz8gyqzg9rka9x4xbawid8c6sy8h3l8j";
        arch = "darwin-x64";

      };
      "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-xml";
        publisher = "redhat";
        version = "0.28.2025012908";
        sha256 = "1qhd1yj66dzhcvrf0dh0944vybwssv3r36qma8vvp42hzax776bl";
        arch = "darwin-x64";

      };
    }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {
    "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
      name = "terraform";
      publisher = "hashicorp";
      version = "2.34.2025012311";
      sha256 = "05wfn49q669y4r9z4h9inx5f0rrmx28ibgwdk3pk1c1j31b06q2a";
      arch = "darwin-arm64";

    };
    "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
      name = "vscode-xml";
      publisher = "redhat";
      version = "0.28.2025012908";
      sha256 = "02pzgq2sp3j1cb62z1g0hcs8xb739s23363bbg2cfys1l66l1fsl";
      arch = "darwin-arm64";

    };
    "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
      name = "rust-analyzer";
      publisher = "rust-lang";
      version = "0.4.2296";
      sha256 = "1mrb8fy0xsiqlfhy0ncghcp2a4743lqs40gnqr4zv584mxr2i9ar";
      arch = "darwin-arm64";

    };
  })
