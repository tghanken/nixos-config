# Migration Plan: flake-parts to blueprint

## Executive Summary

This document outlines the migration strategy for converting the nixos-config repository from flake-parts to [numtide/blueprint](https://github.com/numtide/blueprint). The migration will preserve the existing module hierarchy using blueprint's profile system while adopting convention-based auto-discovery for hosts, modules, and packages.

---

## 1. Current State Analysis

### 1.1 Current Directory Structure

```
nixos-config/
├── flake.nix                    # flake-parts based
├── clusters/clusters.nix        # Empty, future use
├── machines/
│   ├── machines.nix             # Host definitions + module composition
│   ├── hosts/
│   │   ├── desktops/            # Desktop hosts
│   │   │   ├── inwin-tower/
│   │   │   └── nixos-thinkpad/
│   │   ├── servers/             # Server hosts
│   │   │   ├── nixos-rpi3/
│   │   │   ├── nixos-rpi4-1/
│   │   │   ├── nixos-rpi4-2/
│   │   │   ├── nixos-rpi4-3/
│   │   │   └── syno-vm/
│   │   └── utils/               # Bootstrap configuration
│   │       └── nixos-bootstrap/
│   └── modules/                 # Shared modules
│       ├── bootstrap/
│       ├── common/
│       ├── desktop/
│       ├── hardware/
│       ├── install/
│       ├── server/
│       └── users/
├── packages/                    # Custom packages
└── secrets/                     # Agenix secrets
```

### 1.2 Current Module Hierarchy

The current configuration uses a layered module system:

```
bootstrap_mods (base)
    └── install_mods (+disko)
            └── common_mods (+secrets)
                    ├── server_mods
                    └── desktop_mods (+home-manager)
```

### 1.3 Current Flake Outputs

| Output | Description |
|--------|-------------|
| `nixosConfigurations.*` | 7 hosts (2 desktops, 5 servers) |
| `packages.*.nixos-vm-bootstrap-image` | x86_64 ISO bootstrap image |
| `packages.*.nixos-rpi-bootstrap-image` | aarch64 SD card bootstrap image |
| `packages.*.windsurf` | Custom windsurf package |
| `formatter.*` | alejandra |
| `devShells.*.default` | Shell with agenix |
| `checks.*.nix-fmt-check` | Format validation |

---

## 2. Blueprint Conventions

### 2.1 Blueprint Directory Structure

Blueprint uses convention-based auto-discovery with these expected directories:

| Directory | Purpose | Output |
|-----------|---------|--------|
| `hosts/` | NixOS configurations | `nixosConfigurations` |
| `modules/` | Shared NixOS modules | Auto-imported by hosts |
| `packages/` | Custom packages | `packages` |
| `lib/` | Helper functions | Available as `inputs.self.lib` |
| `devshells/` | Development shells | `devShells` |
| `formatter/` | Code formatter | `formatter` |
| `checks/` | CI checks | `checks` |

### 2.2 Host Discovery

Blueprint discovers hosts via:
- `hosts/{hostname}/default.nix` - Directory-based
- `hosts/{hostname}.nix` - File-based

### 2.3 Profile System

Blueprint supports profiles for shared configurations:
- Profiles are modules that can be selectively included
- Typically organized in `modules/profiles/` or similar

---

## 3. Proposed New Directory Structure

```
nixos-config/
├── flake.nix                    # Blueprint-based (simplified)
├── flake.lock
├── hosts/                       # Blueprint auto-discovery
│   ├── desktops/
│   │   ├── inwin-tower/
│   │   │   ├── default.nix      # Main config
│   │   │   ├── hardware-configuration.nix
│   │   │   └── devices.nix
│   │   └── nixos-thinkpad/
│   │       ├── default.nix
│   │       ├── hardware-configuration.nix
│   │       └── devices.nix
│   └── servers/
│       ├── nixos-rpi3/
│       │   ├── default.nix
│       │   └── hardware-configuration.nix
│       ├── nixos-rpi4-1/
│       ├── nixos-rpi4-2/
│       ├── nixos-rpi4-3/
│       └── syno-vm/
├── modules/                     # Blueprint auto-loads
│   ├── profiles/                # Hierarchical profiles
│   │   ├── bootstrap.nix        # Base profile
│   │   ├── install.nix          # +disko
│   │   ├── common.nix           # +secrets
│   │   ├── server.nix           # Server profile
│   │   └── desktop.nix          # Desktop profile
│   ├── hardware/                # Hardware-specific modules
│   │   └── raspberry-pi/
│   ├── users/                   # User configurations
│   └── apps/                    # Optional app modules
├── packages/                    # Blueprint auto-discovery
│   ├── default.nix              # Package set
│   ├── windsurf.nix
│   └── bootstrap-images.nix     # Bootstrap image generators
├── devshells/                   # Blueprint auto-discovery
│   └── default.nix              # Development shell
├── checks/                      # Blueprint auto-discovery
│   └── default.nix              # Format checks
├── formatter/                   # Blueprint auto-discovery
│   └── default.nix              # alejandra
├── lib/                         # Helper functions
│   └── default.nix
└── secrets/                     # Agenix secrets (unchanged)
    ├── mod.nix
    ├── secrets.nix
    └── keys/
```

---

## 4. Profile Hierarchy Design

### 4.1 Profile Structure

Blueprint profiles will mirror the current module hierarchy:

```nix
# modules/profiles/bootstrap.nix
{ config, lib, pkgs, ... }: {
  imports = [
    ../bootstrap/builders.nix
    ../bootstrap/tailscale.nix
  ];
  # Base nix settings, packages, etc.
}

# modules/profiles/install.nix
{ config, lib, pkgs, inputs, ... }: {
  imports = [
    ./bootstrap.nix
    inputs.disko.nixosModules.disko
    ../install/bootloader.nix
    ../install/locale.nix
  ];
}

# modules/profiles/common.nix
{ config, lib, pkgs, inputs, ... }: {
  imports = [
    ./install.nix
    inputs.agenix.nixosModules.default
    ../../secrets/mod.nix
    ../common/builders.nix
    ../common/networking.nix
    ../common/utils.nix
  ];
}

# modules/profiles/server.nix
{ config, lib, pkgs, ... }: {
  imports = [
    ./common.nix
    ../server/server.nix
    ../users/users.nix
  ];
}

# modules/profiles/desktop.nix
{ config, lib, pkgs, inputs, ... }: {
  imports = [
    ./common.nix
    inputs.home-manager.nixosModules.home-manager
    ../desktop/desktop.nix
    ../users/users.nix
  ];
  
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.tghanken = import ../users/tghanken/home-manager.nix;
  };
}
```

### 4.2 Host Configuration Pattern

Each host will import the appropriate profile:

```nix
# hosts/desktops/inwin-tower/default.nix
{ config, lib, pkgs, ... }: {
  imports = [
    ../../../modules/profiles/desktop.nix
    ./hardware-configuration.nix
    ../../../modules/apps/ollama.nix
    ../../../modules/apps/jetbrains.nix
    ../../../modules/apps/steam.nix
  ];
  
  networking.hostName = "inwin-tower";
  networking.hostId = "89cc1717";
  # ... rest of configuration
}
```

---

## 5. flake.nix Transformation

### 5.1 New flake.nix Structure

```nix
{
  description = "NixOS configuration for home devices";

  inputs = {
    # Core Inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS Inputs
    agenix = {
      url = "github:ryantm/agenix";
      inputs.darwin.follows = "";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs:
    inputs.blueprint {
      inherit inputs;
      prefix = "";
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    };
}
```

### 5.2 Key Changes

| Aspect | flake-parts | Blueprint |
|--------|-------------|-----------|
| Output generation | Explicit via `mkFlake` | Convention-based auto-discovery |
| Host definitions | `machines.nix` with `importApply` | `hosts/` directory |
| Module composition | Manual in `machines.nix` | Profile imports in each host |
| System iteration | `perSystem` function | Automatic via `systems` |

---

## 6. Bootstrap Image Strategy

### 6.1 Approach

Since bootstrap images are not standard NixOS configurations, they will be handled as custom packages:

```nix
# packages/bootstrap-images.nix
{ inputs, pkgs, system, ... }:
let
  bootstrap_modules = [
    ../hosts/utils/nixos-bootstrap/configuration.nix
    ../modules/profiles/bootstrap.nix
    ../modules/users/users.nix
  ];
in {
  nixos-vm-bootstrap-image = inputs.nixos-generators.nixosGenerate {
    inherit system;
    modules = bootstrap_modules;
    format = "iso";
  };
  
  nixos-rpi-bootstrap-image = inputs.nixos-generators.nixosGenerate {
    system = "aarch64-linux";
    modules = bootstrap_modules;
    format = "sd-aarch64";
  };
}
```

### 6.2 Alternative: Custom Host Type

Blueprint may support custom host builders. Check blueprint documentation for `nixosConfigurations` customization options.

---

## 7. Migration Checklist

### Phase 1: Preparation
- [ ] Create feature branch for migration
- [ ] Test current configuration builds successfully
- [ ] Document current outputs for validation

### Phase 2: Directory Restructure
- [ ] Create new `hosts/` directory structure
- [ ] Move host configurations from `machines/hosts/` to `hosts/`
- [ ] Rename `configuration.nix` to `default.nix` for each host
- [ ] Update relative import paths in host configs
- [ ] Create `modules/profiles/` directory
- [ ] Create profile modules (bootstrap, install, common, server, desktop)
- [ ] Reorganize modules directory structure
- [ ] Move packages to blueprint convention
- [ ] Create `devshells/default.nix`
- [ ] Create `formatter/default.nix`
- [ ] Create `checks/default.nix`

### Phase 3: flake.nix Migration
- [ ] Replace flake-parts with blueprint input
- [ ] Remove nix-systems input (blueprint handles this)
- [ ] Update outputs to use blueprint
- [ ] Remove `machines.nix` and `clusters.nix`

### Phase 4: Profile Implementation
- [ ] Implement `modules/profiles/bootstrap.nix`
- [ ] Implement `modules/profiles/install.nix`
- [ ] Implement `modules/profiles/common.nix`
- [ ] Implement `modules/profiles/server.nix`
- [ ] Implement `modules/profiles/desktop.nix`
- [ ] Update each host to import appropriate profile

### Phase 5: Validation
- [ ] Run `nix flake check`
- [ ] Build each host configuration
- [ ] Build bootstrap images
- [ ] Verify devShell works
- [ ] Verify formatter works
- [ ] Compare outputs with original

### Phase 6: Cleanup
- [ ] Remove old `machines/` directory
- [ ] Update README.md
- [ ] Update any CI/CD configurations

---

## 8. Risks and Mitigations

### 8.1 Identified Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Blueprint doesn't support nested host directories | Medium | May need to flatten `hosts/` or configure blueprint |
| Bootstrap images may not fit blueprint model | Low | Use custom packages approach |
| Path changes break imports | High | Careful path updates and testing |
| Home-manager integration differs | Medium | Test desktop profiles thoroughly |
| Hardware module discovery | Low | Explicit imports in host configs |

### 8.2 Rollback Strategy

Keep the original `machines/` directory until migration is complete and validated. If issues arise:
1. Revert flake.nix to flake-parts version
2. Restore machines.nix imports
3. Remove new blueprint directories

---

## 9. Post-Migration Structure Diagram

```
                    ┌─────────────────────┐
                    │      flake.nix      │
                    │     [blueprint]     │
                    └──────────┬──────────┘
                               │
        ┌──────────┬───────────┼───────────┬──────────┐
        │          │           │           │          │
        ▼          ▼           ▼           ▼          ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ hosts/  │ │modules/ │ │packages/│ │devshells│ │formatter│
   └────┬────┘ └────┬────┘ └─────────┘ └─────────┘ └─────────┘
        │          │
   ┌────┴────┐     │
   │         │     │
   ▼         ▼     ▼
┌──────┐ ┌──────┐ ┌────────────────────────────────────────┐
│desktops│servers│ │              profiles/                │
└───┬───┘└───┬───┘ │  bootstrap <- install <- common       │
    │        │     │                  │                     │
    │        │     │         ┌────────┴────────┐           │
    │        │     │         ▼                 ▼           │
    │        │     │     [server]         [desktop]        │
    │        │     └────────────────────────────────────────┘
    │        │
    ▼        ▼
 imports   imports
 desktop   server
 profile   profile
```

---

## 10. Questions to Resolve

1. **Nested host directories**: Does blueprint support `hosts/desktops/hostname/` or does it require `hosts/hostname/`? Need to verify in blueprint documentation.

2. **Bootstrap images**: Confirm best approach for nixos-generators integration with blueprint.

3. **Input access in modules**: Verify how blueprint exposes `inputs` to modules for accessing disko, agenix, etc.

4. **Hardware modules**: Decide whether nixos-hardware modules should be in profiles or host-specific imports.

---

## Appendix: File Change Summary

| Original Location | New Location | Notes |
|-------------------|--------------|-------|
| `machines/machines.nix` | Removed | Logic distributed to profiles |
| `clusters/clusters.nix` | Removed | Empty file |
| `machines/hosts/desktops/*` | `hosts/desktops/*` | Rename config.nix -> default.nix |
| `machines/hosts/servers/*` | `hosts/servers/*` | Rename config.nix -> default.nix |
| `machines/hosts/utils/nixos-bootstrap/*` | `hosts/utils/nixos-bootstrap/` | For bootstrap images |
| `machines/modules/bootstrap/*` | `modules/bootstrap/*` | Unchanged structure |
| `machines/modules/common/*` | `modules/common/*` | Unchanged structure |
| `machines/modules/desktop/*` | `modules/desktop/*` or `modules/apps/*` | May reorganize apps |
| `machines/modules/install/*` | `modules/install/*` | Unchanged structure |
| `machines/modules/server/*` | `modules/server/*` | Unchanged structure |
| `machines/modules/users/*` | `modules/users/*` | Unchanged structure |
| `machines/modules/hardware/*` | `modules/hardware/*` | Unchanged structure |
| `packages/` | `packages/` | Add bootstrap-images.nix |
| `secrets/` | `secrets/` | Unchanged |
| N/A | `modules/profiles/*` | New profile modules |
| N/A | `devshells/default.nix` | New |
| N/A | `formatter/default.nix` | New |
| N/A | `checks/default.nix` | New |
