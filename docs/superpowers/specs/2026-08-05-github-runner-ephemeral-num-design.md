# Design: ephemeral runners + `num` parallelism

Approved: option A (list entries + optional `num`), Hercules `num = 4`.

## Goal

Keep `services.github-runner-containers` (per-owner containers, niks3, Docker
socket). Adopt two reliability/scale defaults from github-nix-ci:

1. `ephemeral = true` on every nixpkgs `services.github-runners` unit
2. Per-repo `num` to spin N parallel runners

## Interface

```nix
services.github-runner-containers.runners = [
  { owner = "tghanken"; repo = "nixos-config"; num = 4; }
  { owner = "tghanken"; repo = "seneschal"; num = 4; }
  { owner = "actionable-work"; repo = "actionable"; num = 4; }
];
```

- `num` defaults to `1` if omitted
- Must be a positive integer

## Naming

For index `i` in `1..num` (zero-padded to 2 digits):

| Field | Pattern | Example |
|---|---|---|
| GitHub runner name | `{owner}-{repo}-{hostname}-{ii}` | `tghanken-nixos-config-hercules-01` |
| systemd / state key | `{owner}-{repo}-{ii}` (sanitized) | `tghanken-nixos_config-01` |

Suffix is always present (including `num = 1`) so naming stays uniform.

## Behavior

- `replace = true` (unchanged) + `ephemeral = true`: each job/start gets a
  fresh registration; avoids stale credentials after GitHub GC
- Containers, PAT layout, labels (`nixos` + hostname), Docker, niks3 unchanged
- Old non-suffixed runner names on GitHub can be deleted manually after deploy

## Out of scope

- Org-wide runners (`orgRunners`)
- Switching to github-nix-ci
- Label model changes (`runs-on` stays `[self-hosted, nixos, hercules]`)
