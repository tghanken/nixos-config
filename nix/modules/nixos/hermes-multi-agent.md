# Hermes Multi-Agent System

## Overview

Sets up a single Hermes Agent container on hercules with multiple profiles for coordinated multi-agent work via the Kanban system.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  HOST: hercules (NixOS)                                      │
│                                                              │
│  ┌──────────────┐                                            │
│  │ LM Studio    │  :1234 (localhost)                         │
│  └──────┬───────┘                                            │
│         │ forwardPorts                                      │
│  ┌──────▼────────────────────────────────────────────────┐   │
│  │ Container: hermes-agent (Ubuntu 24.04)                │   │
│  │                                                       │   │
│  │  Gateway process (systemd: hermes-agent)             │   │
│  │    ├─ Dispatcher (auto-runs every 60s)               │   │
│  │    ├─ API Server (:8642)                             │   │
│  │    └─ CLI routing (transparent)                      │   │
│  │                                                       │   │
│  │  Profiles:                                            │   │
│  │    - orchestrator (user-facing coordinator)          │   │
│  │    - planner (writes technical specs)                │   │
│  │    - builder (implements code)                       │   │
│  │    - reviewer (reviews code quality)                 │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  User → hermes chat (host CLI → routes into container)      │
│       → Dashboard (hermes dashboard → :9119)                │
└──────────────────────────────────────────────────────────────┘
```

## Profiles

| Profile | Role | Toolsets |
|---------|------|----------|
| orchestrator | User-facing coordinator, delegates work | kanban, gateway, memory |
| planner | Breaks requests into technical specs | terminal, file, web, kanban |
| builder | Implements code from specs | terminal, file, kanban |
| reviewer | Reviews code for quality | terminal, file, kanban |

## Usage

### Talk to the orchestrator

```bash
# Interactive chat (routes into container)
hermes chat

# Or use the orchestrator profile directly
hermes -p orchestrator chat
```

### Watch the kanban board

```bash
# Open the dashboard GUI
hermes dashboard  # opens http://localhost:9119

# CLI commands
hermes kanban list      # list tasks
hermes kanban stats     # board statistics
hermes kanban watch     # live tail of task events
```

### API access

The API server is exposed on port 8642:

```bash
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer hermes-local-dev-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "hermes-agent", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Adding New Profiles

### 1. Create a SOUL.md file

Add a new file in `nix/modules/nixos/hermes-souls/`:

```markdown
# NewRole

You are the NewRole — your description here.

## Your Role
- What you do
- How you work

## Rules
- Guidelines for behavior

## Metadata Format
When completing, include structured metadata:
```json
{
  "key": "value"
}
```
```

### 2. Register the profile

In `nix/modules/nixos/hermes-multi-agent.nix`, add to `defaultProfiles`:

```nix
newrole = {
  description = "Description used by the kanban decomposer for routing";
  toolsets = ["terminal" "file" "kanban"];
};
```

### 3. Add the soul file reference

In the same file, add to `souls`:

```nix
souls = {
  # ... existing profiles
  newrole = ./hermes-souls/newrole.md;
};
```

### 4. Rebuild

```bash
nixos-rebuild switch
```

## Configuration Options

All options are under `services.hermes-multi-agent`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the multi-agent system |
| `lmStudioPort` | int | `1234` | Host port where LM Studio runs |
| `apiPort` | int | `8642` | Host port for API server |
| `dashboardPort` | int | `9119` | Host port for dashboard |
| `orchestratorProfile` | str | `"orchestrator"` | Profile for root tasks |
| `hostUsers` | list of str | `[]` | Host users with CLI access |
| `extraVolumes` | list of str | `[]` | Additional container volumes |
| `secretsFile` | path or null | `null` | Path to env file with API keys |
| `profiles` | attrs | `{}` | Profile definitions (merged with defaults) |

## Adding API Keys (OpenRouter, etc.)

1. Create the secret file:
```bash
cd nix/modules/secrets/secret_files
agenix -e encrypted/hermes_api_keys.age
```

2. Add API keys to the file:
```
OPENROUTER_API_KEY=sk-or-...
KILO_CODE_GATEWAY_KEY=...
CURSOR_API_KEY=...
```

3. Update hercules config:
```nix
services.hermes-multi-agent.secretsFile = config.age.secrets.hermes_api_keys.path;
```

4. Rebuild:
```bash
nixos-rebuild switch
```

## Troubleshooting

### Container not starting

```bash
# Check service status
systemctl status hermes-agent

# Check container status
docker ps -a | grep hermes

# View logs
journalctl -u hermes-agent -f
```

### Profiles not initialized

```bash
# Check if init ran
ls -la /var/lib/hermes/.profiles-initialized

# Manually trigger init
sudo systemctl start hermes-init-profiles
```

### LM Studio not reachable

Ensure LM Studio is running on the host with API enabled on port 1234.

## References

- [Hermes Agent Documentation](https://hermes-agent.nousresearch.com/docs)
- [Kanban Guide](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)
- [Nix Setup](https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup)
- [Profiles](https://hermes-agent.nousresearch.com/docs/user-guide/profiles)
