## AI Agent

Autonomous AI Agent service powered by Zeroclaw, providing intelligent task automation with security controls for code review and development tasks.

- **Entry point**: `modules/nixos/services/ai-agent.nix`
- **Bundled module**: `modules/nixos/services/zeroclaw.nix`

### Options

{{#include ../../../generated/ai-agent-options.md}}

### Allowed Domains

The AI Agent is configured to access the following domains for development, coding, and general information tasks:

- **Version Control & Collaboration**: `github.com`, `gitlab.com`, `codeberg.org`, `git.sr.ht`, `raw.githubusercontent.com`
- **Programming Languages & Frameworks**: `rust-lang.org`, `golang.org`, `registry.npmjs.org`, `pypi.org`, `developer.mozilla.org`, `cppreference.com`
- **Documentation & Reference**: `docs.rs`, `crates.io`, `devdocs.io`, `learn.microsoft.com`, `w3.org`, `gnu.org`, `curl.se`, `man.archlinux.org`
- **General Information**: `wikipedia.org`
- **Package Management & Containers**: `docker.io`, `hub.docker.com`
- **Development Tools**: `stackoverflow.com`
- **NixOS Ecosystem**: `nixos.org`

### Allowed Commands

The AI Agent has automatic approval for the following common and safe bash utilities and developer tools:

- **File Operations**: `cat`, `diff`, `fd`, `file`, `find`, `head`, `od`, `strings`, `tail`, `tree`, `wc`
- **Text Processing & Search**: `awk`, `cut`, `echo`, `grep`, `jq`, `printf`, `rg`, `sed`, `sort`, `tr`, `uniq`
- **Archiving & Compression**: `gzip`, `gunzip`, `tar`
- **Hashing & Encoding**: `base64`, `md5sum`, `sha256sum`
- **System Information**: `date`, `pwd`, `uname`, `whoami`
- **Network & Connectivity**: `curl`, `dig`, `ping`, `wget`
- **Text Editors & Pagers**: `less`, `more`, `nano`, `vim`
- **Rust Development**: `cargo`, `cargo-build`, `cargo-check`, `cargo-test`, `rustc`, `rustfmt`, `rustup`
- **Nix Tools**: `nix`, `nix-build`, `nix-env`, `nix-flake`, `nix-fmt`, `nix-shell`
- **C/C++ Development**: `clang`, `cmake`, `g++`, `gcc`
- **Version Control**: `git`, `hg`, `jj`
- **Language Runtimes**: `go`, `lua`, `node`, `npm`, `pip`, `poetry`, `python`, `python3`, `ruby`
- **Build Tools**: `make`
- **Debugging & Analysis**: `gdb`, `lldb`, `ltrace`, `strace`, `valgrind`

### Specialized Agents

The AI Agent service includes 15 specialized agents designed for different development tasks. Each agent is optimized for specific roles:

#### Deep Work & Architecture

- **sisyphus**: Deep architectural analysis and foundational problem solving (Claude Opus 4.6)
- **metis**: Strategic planning, best practices, and architectural wisdom (Claude Opus 4.6)
- **architect**: System design, architecture decisions, and scalability planning (Claude Opus 4.6)

#### Code Understanding & Exploration

- **atlas**: Code exploration, pattern discovery, and codebase navigation (GPT-5.2 Codex)
- **prometheus**: Code analysis, refactoring planning, and optimization strategies (GPT-5.2 Codex)
- **explorer**: Quick code exploration and debugging assistance (GPT-5 Mini)

#### Implementation & Building

- **hephaestus**: Implementation, building, and crafting solutions (GPT-5.2 Codex)
- **validator**: Test design, QA strategy, and reliability verification (GPT-5.2)

#### Quality & Security

- **critic**: Code review, quality analysis, and best practice enforcement (Claude Opus 4.6)
- **guardian**: Security analysis, vulnerability assessment, and hardening (Claude Opus 4.6)

#### Operations & Infrastructure

- **devops**: Infrastructure, deployment, and operational excellence (Claude Opus 4.6)

#### Knowledge & Communication

- **oracle**: General technical inquiry and consultation (GPT-5.2)
- **librarian**: Documentation lookup, API reference, and quick answers (GPT-5 Mini)
- **scribe**: Documentation writing, README creation, and technical communication (GPT-5 Mini)

#### General Purpose

- **default**: General purpose agent for miscellaneous tasks (Claude Opus 4.6)

### Usage Example

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
  };
}
```

### Operational Notes

The AI Agent service runs with automatic approval for safe operations (`file_read`, `memory_recall`, `web_fetch`, `web_search`) as well as a curated set of non-destructive bash commands. It enforces security controls including OTP gating for sensitive domains (banking, finance, medical, government, identity providers) and an emergency stop capability. The service is configured to operate only within designated workspace boundaries and maintains a local SQLite memory backend with automatic saving. It runs a heartbeat check every 15 minutes to ensure operational health.
