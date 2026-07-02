# nixai — AI Agent Host

## Purpose

`nixai` is the AI infrastructure host.
It runs the AI agent, local inference via Ollama, the Open WebUI chat interface, Mnemosyne memory sync, and voice services.

## Entry Point

- **Main file**: [`hosts/server/nixai/default.nix`](../../../../hosts/server/nixai/default.nix)
- **Supporting files**: `ai-agent.nix`, `backend.nix`, `mnemosyne.nix`, `voice.nix`, `web.nix`

## Architecture / Services / Scope

### AI Agent

- Containerized AI agent with a web dashboard, an OpenAI-compatible API server, and a webhook platform.
- Memory is enabled, backed by Mnemosyne sync.
- Voice is enabled, using the local Wyoming STT server.
- A hardened SSH daemon is provisioned inside the container for agent administration.

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

## References

- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [Ollama](https://ollama.com)
- [Mnemosyne](../../modules/nixos/ai/mnemosyne.md)
- [Database Coordinator](../../hosts/server/nixdb.md)
- [IO Coordinator](../../hosts/server/nixio.md)
