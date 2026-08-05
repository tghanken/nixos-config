# GitHub Actions runners on NixOS

Self-hosted runners for hercules (and any host that imports
`flake.modules.utils.github-runner`).

## Layout

- **One NixOS container per GitHub owner** (`tghanken`, `actionable-work`, …)
- **One agenix PAT per owner** — mounted only into that owner's container
- **One `services.github-runners` unit per repository** inside the owner container

Example on hercules:

| Container | PAT secret | Repos |
|---|---|---|
| `github-runners-tghanken` | `github_runner_tghanken.age` | `nixos-config`, `seneschal` |
| `github-runners-actionable-work` | `github_runner_actionable_work.age` | `actionable` |

Shared with the host (by design): read-only `/nix/store`, read-only nix-daemon
socket, and (optionally) the Docker socket. Containers **do not** run their own
`nix-daemon` when store sharing is enabled — a second daemon on the shared
socket would replace the host socket and break Nix for the whole machine.
Isolation is for **tokens / runner state**, not for build sandboxing.

## Authentication: what to use

The nixpkgs `services.github-runners` module accepts a file containing either:

1. **Fine-grained PAT** (recommended)
2. **Classic PAT**
3. **Runner registration token** (not recommended — expires in ~1 hour)

There is **no first-class GitHub App support** in the module today. A GitHub App
is nicer long-term (short-lived tokens, org install, no user-owned secret), but
you would need a small wrapper that mints a registration token into the
`tokenFile` before the runner starts. Until then, use fine-grained PATs.

Registration tokens from the “Add runner” UI are a bad fit for NixOS: any
reconfigure after expiry fails with opaque `404`s.

## Fine-grained PAT (recommended)

Create one PAT **per owner** (Settings → Developer settings → Fine-grained tokens,
or org → Settings → Personal access tokens if using an org-owned token).

### Resource owner

- Personal repos: your user (`tghanken`)
- Org repos: the organization (`actionable-work`)

### Repository access

- **Only select repositories** you register runners for  
  (e.g. `nixos-config` + `seneschal`, or `actionable`)

### Permissions

Under **Repository permissions**:

| Permission | Access | Why |
|---|---|---|
| **Administration** | Read and write | Required to create/manage self-hosted runners on the repo |

That is the permission GitHub exposes for “repository self-hosted runners”.
nixpkgs documents it as *Read and Write access to … repository self hosted runners*;
in the fine-grained UI this maps to **Administration** (not the separate Actions
permission).

If Administration alone fails registration, also try:

| Permission | Access |
|---|---|
| **Actions** | Read and write |
| **Metadata** | Read-only (usually required / auto-included) |

### Org-wide runners (optional)

If you later register at `https://github.com/<org>` instead of per-repo URLs:

- Resource owner = organization
- Repository access = **All repositories** (or the set you care about)
- Organization permissions: **Self-hosted runners** → Read and write

This module currently uses **per-repo** registration URLs, so repo Administration
on the listed repos is enough.

### Token file format

Exactly one line, **no trailing newline**:

```bash
# create / update the agenix secret (opens $EDITOR)
just es github_runner_tghanken
# paste the token with no newline, or from a file:
# printf '%s' "$TOKEN" | … into the editor buffer
```

Secret names (hyphens → underscores):

- `encrypted/github_runner_tghanken.age`
- `encrypted/github_runner_actionable_work.age`

Public keys for those secrets are in `nix/modules/secrets/secret_files/secrets.nix`
(hercules host key + your user keys).

## Classic PAT (fallback)

| Use case | Classic scope |
|---|---|
| User/repo runners | `repo` |
| Org-wide runners | `admin:org` |

Prefer fine-grained tokens; classic scopes are broader than needed.

## Labels / `runs-on`

Default labels from GitHub: `self-hosted`, `Linux`, `X64`.  
This module also adds `nixos` and the hostname (e.g. `hercules`).

```yaml
jobs:
  build:
    runs-on: [self-hosted, nixos, hercules]
```

Do not add a redundant `linux` label.

## Deploy checklist

1. Create the two fine-grained PATs with the scopes above
2. `just es github_runner_tghanken` and `just es github_runner_actionable_work`
3. Deploy hercules
4. Confirm containers: `machinectl list` → `github-runners-tghanken`, `github-runners-actionable_work`
5. Confirm runners under each repo’s **Settings → Actions → Runners**

## Adding a repo

```nix
services.github-runner-containers.runners = [
  # …
  { owner = "tghanken"; repo = "new-repo"; }
];
```

If the owner is new, add `encrypted/github_runner_<owner>.age` to `secrets.nix`
and create the PAT/secret. If the owner already exists, extend that owner’s
fine-grained PAT repository list to include the new repo.

## niks3 binary cache

Runners pull from niks3 via the `services.github-runner-containers.niks3`
substituter (enabled by default). Upload support is also on by default
(`niks3.uploader.enable`).

When the uploader is enabled, each runner job gets:

- `niks3` on `PATH`
- `NIKS3_SERVER` / `NIKS3_SERVER_URL` set to the upload server
- `NIKS3_AUTH_TOKEN_FILE` pointing at the agenix secret
- `~/.config/niks3/auth-token` symlinked to the same secret (for
  `nix-fast-build` and `niks3-warm-intermediates`)

Workflows no longer need a "Setup niks3 cache" step on self-hosted runners.
They still need `NIKS3_SERVER` in job `env` if the flake entrypoint gates on
it (e.g. seneschal's `flake-check`).

### Upload token

Create the agenix secret with the niks3 API token (exactly one line, no
trailing newline — same format as the GitHub runner PATs):

```bash
just es niks3_upload_token
```

Secret file: `encrypted/niks3_upload_token.age`

To disable uploads without removing the substituter:

```nix
services.github-runner-containers.niks3.uploader.enable = false;
```
