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
        "alefragnani"."project-manager" = vscode-utils.extensionFromVscodeMarketplace {
          name = "project-manager";
          publisher = "alefragnani";
          version = "12.8.0";
          sha256 = "1gp2dd4xm5a4dmaikcng79mfcb8a24mddsdwpgg4bqshcz4q7n5h";

        };
        "zhuangtongfa"."material-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-theme";
          publisher = "zhuangtongfa";
          version = "3.19.0";
          sha256 = "1z3wiacb2m7hvpfhn6qs710lsaxpy7c56jbjckccvqi705w9firb";

        };
        "foxundermoon"."shell-format" = vscode-utils.extensionFromVscodeMarketplace {
          name = "shell-format";
          publisher = "foxundermoon";
          version = "7.2.5";
          sha256 = "0a874423xw7z6zjj7gzzl39jahrrqcf2r16zbcvncw23483m3yli";

        };
        "esbenp"."prettier-vscode" = vscode-utils.extensionFromVscodeMarketplace {
          name = "prettier-vscode";
          publisher = "esbenp";
          version = "11.0.0";
          sha256 = "1fcz8f4jgnf24kblf8m8nwgzd5pxs2gmrv235cpdgmqz38kf9n54";

        };
        "rogalmic"."bash-debug" = vscode-utils.extensionFromVscodeMarketplace {
          name = "bash-debug";
          publisher = "rogalmic";
          version = "0.3.9";
          sha256 = "0n7lyl8gxrpc26scffbrfczdj0n9bcil9z83m4kzmz7k5dj59hbz";

        };
        "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.118.2025022515";
          sha256 = "1n5gqbm7v38xqq6qfy2j2hhmpiz9j0akg8mqz7q99j56l1mas6vf";

        };
        "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.27.1";
          sha256 = "0pq97nl5h170r5cwsvps9z059lvj7a9aik2w84fnn3mjficrlwlq";

        };
        "jscearcy"."rust-doc-viewer" = vscode-utils.extensionFromVscodeMarketplace {
          name = "rust-doc-viewer";
          publisher = "jscearcy";
          version = "4.2.0";
          sha256 = "0fizwx057nghy8k0xz66f1narxps47d5asl26jr7aq1h1ypncnn7";

        };
        "ruschaaf"."extended-embedded-languages" = vscode-utils.extensionFromVscodeMarketplace {
          name = "extended-embedded-languages";
          publisher = "ruschaaf";
          version = "1.3.0";
          sha256 = "17y48hslb2lm187qkr3qxhh5793canrj5yb5mr40y6hz6jg6cq60";

        };
        "fill-labs"."dependi" = vscode-utils.extensionFromVscodeMarketplace {
          name = "dependi";
          publisher = "fill-labs";
          version = "0.7.13";
          sha256 = "1dsd4qal7wmhhbzv5jmcrf8igm20dnr256s2gp1m5myhj08qlzay";

        };
        "jnoortheen"."nix-ide" = vscode-utils.extensionFromVscodeMarketplace {
          name = "nix-ide";
          publisher = "jnoortheen";
          version = "0.4.12";
          sha256 = "0rdq9wnqfrj8k1g5fcaam5iahzd16bdpi3sa0n2gi0rh02kg55fy";

        };
        "editorconfig"."editorconfig" = vscode-utils.extensionFromVscodeMarketplace {
          name = "editorconfig";
          publisher = "editorconfig";
          version = "0.17.1";
          sha256 = "0al61nfnq3zsir5m3mp7a2kgi2lwvdk59rj132h0888zpm5aw2xq";

        };
        "pkief"."material-icon-theme" = vscode-utils.extensionFromVscodeMarketplace {
          name = "material-icon-theme";
          publisher = "pkief";
          version = "5.19.0";
          sha256 = "16ly295r3ibi42dhj24iks7b8mz0blw4mrq6g9v7w3l1lf45y3cf";

        };
        "ms-vscode"."powershell" = vscode-utils.extensionFromVscodeMarketplace {
          name = "powershell";
          publisher = "ms-vscode";
          version = "2025.1.0";
          sha256 = "1g7a36037wm4l0bj2sgywznl40dg2qxsi1p1p8zyhmamssw7ypx0";

        };
        "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
          name = "todo-tree";
          publisher = "gruntfuggly";
          version = "0.0.226";
          sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";

        };
        "bierner"."markdown-preview-github-styles" = vscode-utils.extensionFromVscodeMarketplace {
          name = "markdown-preview-github-styles";
          publisher = "bierner";
          version = "2.1.0";
          sha256 = "1fn9gdf3xj1drch4djn6c9lg94i2r9yjpfrf1a0y4v8q2zjk8sz8";

        };
        "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-pull-request-github";
          publisher = "github";
          version = "0.105.2025022504";
          sha256 = "1ybwi028diyj84qavhbcqkc8r57x7vxq5jvajbcj7cv050b8dpiy";

        };
        "coolbear"."systemd-unit-file" = vscode-utils.extensionFromVscodeMarketplace {
          name = "systemd-unit-file";
          publisher = "coolbear";
          version = "1.0.6";
          sha256 = "0sc0zsdnxi4wfdlmaqwb6k2qc21dgwx6ipvri36x7agk7m8m4736";

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
          version = "1.29.4";
          sha256 = "1nhrp43gh4pwsdy0d8prndx2l0mrczf1kirjl1figrmhcp7h4q4g";

        };
        "tamasfe"."even-better-toml" = vscode-utils.extensionFromVscodeMarketplace {
          name = "even-better-toml";
          publisher = "tamasfe";
          version = "0.21.2";
          sha256 = "0208cms054yj2l8pz9jrv3ydydmb47wr4i0sw8qywpi8yimddf11";

        };
        "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot-chat";
          publisher = "github";
          version = "0.24.2025021302";
          sha256 = "1w4haa98rgijnhv3bkbw0xbip7s8yqp34wh9mpb4pg2girzgwmps";

        };
        "formulahendry"."code-runner" = vscode-utils.extensionFromVscodeMarketplace {
          name = "code-runner";
          publisher = "formulahendry";
          version = "0.12.2";
          sha256 = "0i5i0fpnf90pfjrw86cqbgsy4b7vb6bqcw9y2wh9qz6hgpm4m3jc";

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
          version = "2025.2.2504";
          sha256 = "03qj2xzldqx8iac638zw026hb64j9ikwhna2lcmfkw4iys97gxpy";

        };
        "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot";
          publisher = "github";
          version = "1.275.1396";
          sha256 = "1j91qxapds2b6sbms8rkx5jpj52fv5nqrc0szgnfvr6kdl9jlvyw";

        };
      }
        (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) {
          "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-xml";
            publisher = "redhat";
            version = "0.28.2025021408";
            sha256 = "07bx0pckdl846104rrcys341si44falid15dqr9knj33fjx45754";
            arch = "linux-x64";

          };
          "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
            name = "terraform";
            publisher = "hashicorp";
            version = "2.34.2025012311";
            sha256 = "0zzp6rdsv8r116wv0hcycip45l8nr5g8xgfdvm2vx6ly0ph4xj7v";
            arch = "linux-x64";

          };
          "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
            name = "rust-analyzer";
            publisher = "rust-lang";
            version = "0.4.2320";
            sha256 = "0z5bn807jm6s7mqjbyqrzwydvl8vg2c7rhh993w65ggp1189i8bp";
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
          version = "0.4.2320";
          sha256 = "0xig89jdf5xfqdk1l0qky3sbrrpzdwx7l6fpnvxbn2a15bzkh4b2";
          arch = "linux-arm64";

        };
        "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-xml";
          publisher = "redhat";
          version = "0.28.2025021408";
          sha256 = "1pr1idnqxyz0si9m4n0528bc7hfv0s49r7ygzh40skyv0q8yypfs";
          arch = "linux-arm64";

        };
      }))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {
      "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
        name = "rust-analyzer";
        publisher = "rust-lang";
        version = "0.4.2320";
        sha256 = "1c5ilj3f88jhyr5bid0yladika3hhcrzb51bhv3kr0q04s8y60k1";
        arch = "darwin-x64";

      };
      "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-xml";
        publisher = "redhat";
        version = "0.28.2025021408";
        sha256 = "1qkslskg05390acp4f5l3pdzs335v8vjdg88bpx457pwmvakx4la";
        arch = "darwin-x64";

      };
      "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
        name = "terraform";
        publisher = "hashicorp";
        version = "2.34.2025012311";
        sha256 = "1safkh5853sndiakk73snz8gyqzg9rka9x4xbawid8c6sy8h3l8j";
        arch = "darwin-x64";

      };
    }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {
    "redhat"."vscode-xml" = vscode-utils.extensionFromVscodeMarketplace {
      name = "vscode-xml";
      publisher = "redhat";
      version = "0.28.2025021408";
      sha256 = "18d3v6g5z3z2xgsq4y79vmjqma0yh7w815q7zcqszfzgf28bj3aa";
      arch = "darwin-arm64";

    };
    "rust-lang"."rust-analyzer" = vscode-utils.extensionFromVscodeMarketplace {
      name = "rust-analyzer";
      publisher = "rust-lang";
      version = "0.4.2320";
      sha256 = "0m16hhranxihir6iv6v0b8bkk4dgl4drn14yxhar3pz9g0dyi0w1";
      arch = "darwin-arm64";

    };
    "hashicorp"."terraform" = vscode-utils.extensionFromVscodeMarketplace {
      name = "terraform";
      publisher = "hashicorp";
      version = "2.34.2025012311";
      sha256 = "05wfn49q669y4r9z4h9inx5f0rrmx28ibgwdk3pk1c1j31b06q2a";
      arch = "darwin-arm64";

    };
  })
