# NixAI — AI Agent Host

## Purpose

`nixai` is the AI infrastructure host.
It runs the AI agent, local inference via Ollama, the Open WebUI chat interface, Mnemosyne memory sync, and voice services.

## Entry Point

- **Main file**: [`hosts/server/nixai/default.nix`](../../../../hosts/server/nixai/default.nix)
- **Supporting files**: `ai-agent.nix`, `backend.nix`, `mnemosyne.nix`, `voice.nix`, `web.nix`

## Architecture / Services / Scope

### AI Agent

- Containerised AI agent with a web dashboard, an OpenAI-compatible API server, and a webhook platform.
- Memory is enabled, backed by Mnemosyne sync.
- Voice is enabled, using the local Wyoming STT server.
- A hardened SSH daemon is provisioned inside the container for agent administration.
- A checksummed GitHub CLI release is provisioned at container start, ahead of the base image's `gh`, and every Hermes profile is linked to the fleet gh credentials (see [GitHub CLI](#github-cli) below).

### Local Inference

- Runs local models on the host's AMD iGPU (ROCm/Vulkan), loading a small set of chat and embedding models.
- Used by Open WebUI and the agent for local model access.

### Open WebUI (`web.nix`)

- User-facing chat interface with RAG, web search (via SearXNG), and local Whisper STT.
- Backed by a PostgreSQL database on the Database Coordinator and tied into the database availability target so it only starts when the DB is reachable.

### Mnemosyne (`mnemosyne.nix`)

- Mnemosyne memory provider sync server, used by the agent for persistent memory. Served on its own vhost.

### Voice (`voice.nix`)

- Wyoming Piper (TTS) and faster-whisper (STT) servers exposed over TCP for local voice assistants.

## Secrets

### Declared secrets

| Secret key                        | Purpose                       |
| --------------------------------- | ----------------------------- |
| `AI_AGENT/AZURE_FOUNDRY_API_KEY`  | Model API key (Azure Foundry) |
| `AI_AGENT/AZURE_FOUNDRY_BASE_URL` | Model API base URL            |
| `AI_AGENT/OPENROUTER_API_KEY`     | OpenRouter model API key      |
| `AI_AGENT/DISCORD_BOT_TOKEN`      | Discord bot token             |
| `AI_AGENT/API_SERVER_TOKEN`       | Agent API server auth         |
| `MCP/N8N_API_KEY`                 | MCP access to n8n             |
| `MCP/API_TOKEN`                   | MCP bridge API token          |
| `MCP/HASSIO_TOKEN`                | Home Assistant MCP token      |
| `MCP/GITHUB_TOKEN`                | GitHub MCP token              |
| `MCP/ANILIST_TOKEN`               | AniList MCP token             |
| `MNEMOSYNE_SYNC_KEY`              | Mnemosyne sync API key        |

## Operational Notes / Assumptions

- Ollama relies on the AMD iGPU; ROCm on the iGPU is noted as unreliable upstream, so the config pins an override and waits on a Vulkan fix.
- Open WebUI, the agent dashboard, Mnemosyne, and the voice/whisper endpoints are exposed through the IO Coordinator reverse proxy.
- The agent's SSH port is opened to the subnet for administration.

### GitHub CLI

Cards whose completion contract is a pull request are verified by `hermes_cli/kanban_pr_acceptance.py`, which shells out to `gh api … --paginate --slurp` as the card's assignee profile. Two container-local properties make that work, and `services.ai-agent.containerPostStart` in `ai-agent.nix` re-asserts both on every container start, so a recreated container cannot silently lose them:

- **`gh` ahead of `/usr/bin`.** The base image ships gh 2.45.0 at `/usr/bin/gh`, which rejects `--slurp`. The post-start hook installs a pinned, checksummed gh release to `/usr/local/bin/gh`, which precedes `/usr/bin` on the container PATH. It skips the download whenever the installed binary already reports `--slurp`, so it is a no-op on restarts. A nix `pkgs.gh` cannot be used for this: the hermes-agent wrapper appends nix store tools to `PATH` with `--suffix` ("apt/uv-installed versions take priority"), so every `/nix/store/...` path sorts after `/usr/bin` and the distro `gh` always wins. The pinned version and tarball digest live in `hosts/server/nixai/ai-agent.nix`; a version bump updates `ghVersion` and the matching digest from that release's `gh_<version>_checksums.txt`.
- **Per-profile gh credentials.** The gate pins `GH_CONFIG_DIR` to `/data/.hermes/profiles/<profile>/gh` whenever the profile's environment carries no `GH_TOKEN`, `GITHUB_TOKEN` or `GH_CONFIG_DIR`. The post-start hook therefore symlinks `<profile>/gh` to the single fleet gh config (`/home/hermes/.config/gh`, the `RacciDev-Bot` identity) for every profile directory that exists.

**Profile onboarding rule:** a new profile needs no manual step — the next container start links it. A profile that genuinely needs a *distinct* GitHub login sets `GH_CONFIG_DIR` (or `GH_TOKEN`) in its own `.env`, which overrides the fallback; the hook only creates missing links, so an existing credential path is never overwritten.

## References

- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [Ollama](https://ollama.com)
- [Mnemosyne](../../modules/nixos/ai/mnemosyne.md)
- [Database Coordinator](../../hosts/server/nixdb.md)
- [IO Coordinator](../../hosts/server/nixio.md)
