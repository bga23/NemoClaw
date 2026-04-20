<!--
  SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
  SPDX-License-Identifier: Apache-2.0
-->

# 🦞 NemoClaw Fork — bga23

> **This is a personal fork of [NVIDIA/NemoClaw](https://github.com/NVIDIA/NemoClaw) with bug fixes required to make the onboarding flow actually work end-to-end.**

## Fork Fixes

| # | Fix | File(s) | Details |
|---|-----|---------|---------|
| 1 | **TLS bootstrap: wrong secret key** | `cluster-image/cluster-bootstrap.sh` | The `openshell-server-client-ca` secret was created with key `tls.crt` (TLS type), but OpenShell expects `ca.crt` (generic/Opaque type). Gateway health-check failed on fresh installs. Fixed by using `--from-file=ca.crt=...` with generic secret type. |
| 2 | **Sandbox base image: hardcoded NVIDIA GHCR ref** | `src/lib/onboard.ts` | `SANDBOX_BASE_IMAGE` pointed to `ghcr.io/nvidia/nemoclaw/sandbox-base` which is a private registry. Onboarding step [6/8] failed with `docker pull` error. Repointed to `ghcr.io/bga23/nemoclaw/sandbox-base`. |
| 3 | **Dockerfile.base: CRLF breaks version check** | `Dockerfile.base` | `grep \| awk \| tr -d '"'` didn't strip `\r` from YAML values. When building on Windows (CRLF line endings), `OPENCLAW_MIN_VERSION` contained a trailing CR, causing the `sort -V` comparison to always fail — even when versions matched. Fixed by adding `\r` to `tr -d`. |
| 4 | **Cosmetic: ARG BASE_IMAGE default shows nvidia ref** | Dockerfile, 	est/onboard.test.ts | The ARG BASE_IMAGE default in Dockerfile showed ghcr.io/nvidia/... in build logs even though the correct ga23 image was passed via --build-arg. Updated default to ghcr.io/bga23/nemoclaw/sandbox-base:latest so logs reflect the actual image used. |

### Pre-built images

| Image | Tag |
|-------|-----|
| `ghcr.io/bga23/nemoclaw/cluster` | `0.0.26` |
| `ghcr.io/bga23/nemoclaw/sandbox-base` | `latest` |

---

# 🦞 NVIDIA NemoClaw: Reference Stack for Running OpenClaw in OpenShell

<!-- start-badges -->
[![License](https://img.shields.io/badge/License-Apache_2.0-blue)](https://github.com/NVIDIA/NemoClaw/blob/main/LICENSE)
[![Security Policy](https://img.shields.io/badge/Security-Report%20a%20Vulnerability-red)](https://github.com/NVIDIA/NemoClaw/blob/main/SECURITY.md)
[![Project Status](https://img.shields.io/badge/status-alpha-orange)](https://github.com/NVIDIA/NemoClaw/blob/main/docs/about/release-notes.md)
[![Discord](https://img.shields.io/badge/Discord-Join-7289da)](https://discord.gg/XFpfPv9Uvx)
<!-- end-badges -->

<!-- start-intro -->
NVIDIA NemoClaw is an open source reference stack that simplifies running [OpenClaw](https://openclaw.ai) always-on assistants more safely.
It installs the [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) runtime, part of NVIDIA Agent Toolkit, which provides additional security for running autonomous agents.
<!-- end-intro -->

> **Alpha software**
>
> NemoClaw is available in early preview starting March 16, 2026.
> This software is not production-ready.
> Interfaces, APIs, and behavior may change without notice as we iterate on the design.
> The project is shared to gather feedback and enable early experimentation.
> We welcome issues and discussion from the community while the project evolves.

NemoClaw adds guided onboarding, a hardened blueprint, state management, OpenShell-managed channel messaging, routed inference, and layered protection on top of the [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) runtime. For the full feature list, refer to [Overview](https://docs.nvidia.com/nemoclaw/latest/about/overview.html). For the system diagram, component model, and blueprint lifecycle, refer to [How It Works](https://docs.nvidia.com/nemoclaw/latest/about/how-it-works.html) and [Architecture](https://docs.nvidia.com/nemoclaw/latest/reference/architecture.html).

## Getting Started

Follow these steps to install NemoClaw and run your first sandboxed OpenClaw agent.

<!-- start-quickstart-guide -->

### Prerequisites

Before getting started, check the prerequisites to ensure you have the necessary software and hardware to run NemoClaw.

#### Hardware

| Resource | Minimum        | Recommended      |
|----------|----------------|------------------|
| CPU      | 4 vCPU         | 4+ vCPU          |
| RAM      | 8 GB           | 16 GB            |
| Disk     | 20 GB free     | 40 GB free       |

The sandbox image is approximately 2.4 GB compressed. During image push, the Docker daemon, k3s, and the OpenShell gateway run alongside the export pipeline, which buffers decompressed layers in memory. On machines with less than 8 GB of RAM, this combined usage can trigger the OOM killer. If you cannot add memory, configuring at least 8 GB of swap can work around the issue at the cost of slower performance.

#### Software

| Dependency | Version                          |
|------------|----------------------------------|
| Node.js    | 22.16 or later |
| npm        | 10 or later |
| Platform   | See below |

#### OpenShell Lifecycle

For NemoClaw-managed environments, use `nemoclaw onboard` when you need to create or recreate the OpenShell gateway or sandbox.
Avoid `openshell self-update`, `npm update -g openshell`, `openshell gateway start --recreate`, or `openshell sandbox create` directly unless you intend to manage OpenShell separately and then rerun `nemoclaw onboard`.

#### Container Runtimes

The following table lists tested platform and runtime combinations.
Availability is not limited to these entries, but untested configurations may have issues.

<!-- platform-matrix:begin -->
| OS | Container runtime | Status | Notes |
|----|-------------------|--------|-------|
| Linux | Docker | Tested | Primary tested path. |
| macOS (Apple Silicon) | Colima, Docker Desktop | Tested with limitations | Install Xcode Command Line Tools (`xcode-select --install`) and start the runtime before running the installer. |
| DGX Spark | Docker | Tested | Use the standard installer and `nemoclaw onboard`. |
| Windows WSL2 | Docker Desktop (WSL backend) | Tested with limitations | Requires WSL2 with Docker Desktop backend. |
<!-- platform-matrix:end -->

### Install NemoClaw and Onboard OpenClaw Agent

Download and run the installer script.
The script installs Node.js if it is not already present, then runs the guided onboard wizard to create a sandbox, configure inference, and apply security policies.

> **ℹ️ Note**
>
> NemoClaw creates a fresh OpenClaw instance inside the sandbox during the onboarding process.
>
> The installer runs as your normal user and does not require `sudo` or root.
> It installs Node.js via nvm and NemoClaw via npm, both into user-local directories.
> Docker must be installed and running before you run the installer. Installing Docker may require elevated privileges on Linux.

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

If you use nvm or fnm to manage Node.js, the installer may not update your current shell's PATH.
If `nemoclaw` is not found after install, run `source ~/.bashrc` (or `source ~/.zshrc` for zsh) or open a new terminal.

When the install completes, a summary confirms the running environment:

```text
──────────────────────────────────────────────────
Sandbox      my-assistant (Landlock + seccomp + netns)
Model        nvidia/nemotron-3-super-120b-a12b (NVIDIA Endpoints)
──────────────────────────────────────────────────
Run:         nemoclaw my-assistant connect
Status:      nemoclaw my-assistant status
Logs:        nemoclaw my-assistant logs --follow
──────────────────────────────────────────────────

[INFO]  === Installation complete ===
```

### Chat with the Agent

Connect to the sandbox, then chat with the agent through the TUI or the CLI.

```bash
nemoclaw my-assistant connect
```

In the sandbox shell, open the OpenClaw terminal UI and start a chat:

```bash
openclaw tui
```

Alternatively, send a single message and print the response:

```bash
openclaw agent --agent main --local -m "hello" --session-id test
```

### Uninstall

To remove NemoClaw and all resources created during setup, run the uninstall script:

```bash
curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh | bash
```

| Flag               | Effect                                              |
|--------------------|-----------------------------------------------------|
| `--yes`            | Skip the confirmation prompt.                       |
| `--keep-openshell` | Leave the `openshell` binary installed.              |
| `--delete-models`  | Also remove NemoClaw-pulled Ollama models.           |

For troubleshooting installation or onboarding issues, see the [Troubleshooting guide](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html).

<!-- end-quickstart-guide -->

## Documentation

Refer to the following pages on the official documentation website for more information on NemoClaw.

| Page | Description |
|------|-------------|
| [Overview](https://docs.nvidia.com/nemoclaw/latest/about/overview.html) | What NemoClaw does and how it fits together. |
| [How It Works](https://docs.nvidia.com/nemoclaw/latest/about/how-it-works.html) | Plugin, blueprint, sandbox lifecycle, and protection layers. |
| [Architecture](https://docs.nvidia.com/nemoclaw/latest/reference/architecture.html) | Plugin structure, blueprint lifecycle, sandbox environment, and host-side state. |
| [Inference Options](https://docs.nvidia.com/nemoclaw/latest/inference/inference-options.html) | Supported providers, validation, and routed inference configuration. |
| [Network Policies](https://docs.nvidia.com/nemoclaw/latest/reference/network-policies.html) | Baseline rules, operator approval flow, and egress control. |
| [Customize Network Policy](https://docs.nvidia.com/nemoclaw/latest/network-policy/customize-network-policy.html) | Static and dynamic policy changes, presets. |
| [Security Best Practices](https://docs.nvidia.com/nemoclaw/latest/security/best-practices.html) | Controls reference, risk framework, and posture profiles for sandbox security. |
| [Sandbox Hardening](https://docs.nvidia.com/nemoclaw/latest/deployment/sandbox-hardening.html) | Container security measures, capability drops, process limits. |
| [CLI Commands](https://docs.nvidia.com/nemoclaw/latest/reference/commands.html) | Full NemoClaw CLI command reference. |
| [Troubleshooting](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html) | Common issues and resolution steps. |

## Project Structure

The following directories make up the NemoClaw repository.

```text
NemoClaw/
├── bin/              # CLI entry point and library modules (CJS)
├── nemoclaw/         # TypeScript plugin (Commander CLI extension)
│   └── src/
│       ├── blueprint/    # Runner, snapshot, SSRF validation, state
│       ├── commands/     # Slash commands, migration state
│       └── onboard/      # Onboarding config
├── nemoclaw-blueprint/   # Blueprint YAML and network policies
├── scripts/          # Install helpers, setup, automation
├── test/             # Integration and E2E tests
└── docs/             # User-facing docs (Sphinx/MyST)
```

## Community

Join the NemoClaw community to ask questions, share feedback, and report issues.

- [Discord](https://discord.gg/XFpfPv9Uvx)
- [GitHub Discussions](https://github.com/NVIDIA/NemoClaw/discussions)
- [GitHub Issues](https://github.com/NVIDIA/NemoClaw/issues)

## Contributing

We welcome contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding standards, and the PR process.

## Security

NVIDIA takes security seriously.
If you discover a vulnerability in NemoClaw, **DO NOT open a public issue.**
Use one of the private reporting channels described in [SECURITY.md](SECURITY.md):

- Submit a report through the [NVIDIA Vulnerability Disclosure Program](https://www.nvidia.com/en-us/security/report-vulnerability/).
- Send an email to [psirt@nvidia.com](mailto:psirt@nvidia.com) encrypted with the [NVIDIA PGP key](https://www.nvidia.com/en-us/security/pgp-key).
- Use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configuring-private-vulnerability-reporting-for-a-repository) to submit a report directly on this repository.

For security bulletins and PSIRT policies, visit the [NVIDIA Product Security](https://www.nvidia.com/en-us/security/) portal.

## Notice and Disclaimer

This software automatically retrieves, accesses or interacts with external materials. Those retrieved materials are not distributed with this software and are governed solely by separate terms, conditions and licenses. You are solely responsible for finding, reviewing and complying with all applicable terms, conditions, and licenses, and for verifying the security, integrity and suitability of any retrieved materials for your specific use case. This software is provided "AS IS", without warranty of any kind. The author makes no representations or warranties regarding any retrieved materials, and assumes no liability for any losses, damages, liabilities or legal consequences from your use or inability to use this software or any retrieved materials. Use this software and the retrieved materials at your own risk.

---

## Fork Changes (bga23/NemoClaw)

This fork fixes the **OpenShell gateway bootstrap failure** that prevents NemoClaw from completing onboarding. The upstream cluster image (`ghcr.io/nvidia/openshell/cluster`) relies on an external CLI step to create TLS/HMAC Kubernetes secrets after k3s starts. When this step hangs or times out, the gateway never becomes healthy and `nemoclaw onboard` fails indefinitely.

### Root Cause

The OpenShell StatefulSet requires four Kubernetes secrets to mount its TLS volumes:

| Secret | Type | Key(s) | Purpose |
|---|---|---|---|
| `openshell-server-tls` | `kubernetes.io/tls` | `tls.crt`, `tls.key` | Server TLS certificate |
| `openshell-server-client-ca` | `Opaque` | **`ca.crt`** | CA for client verification |
| `openshell-client-tls` | `kubernetes.io/tls` | `tls.crt`, `tls.key` | Client mTLS certificate |
| `openshell-ssh-handshake` | `Opaque` | `secret` | HMAC key for SSH handshake |

Without these secrets the pod volumes cannot mount and the container never starts. The upstream `openshell gateway start` CLI is supposed to create them externally, but this often hangs on first run.

**Additional bug:** The `openshell-server-client-ca` secret must use key `ca.crt` (created via `kubectl create secret generic --from-file=ca.crt=...`), **not** `tls.crt` (which `kubectl create secret tls` produces). The Helm chart mounts this at `/etc/openshell-tls/client-ca/` and the server reads `ca.crt` from that path.

### What Changed

1. **`cluster-image/`** — Custom Dockerfile extending the upstream cluster image with a background TLS bootstrap script that:
   - Waits for the k3s API to become ready
   - Generates a CA, server cert (with proper SANs), client cert, and HMAC secret
   - Creates all four Kubernetes secrets idempotently
   - Runs as a background process alongside k3s (no external CLI needed)

2. **`.github/workflows/build-cluster-image.yml`** — GitHub Actions workflow to build and push the fixed image to `ghcr.io/bga23/nemoclaw/cluster`

3. **`src/lib/onboard.ts`** — Patched `getStableGatewayImageRef()` and `getGatewayStartEnv()` to reference `ghcr.io/bga23/nemoclaw/cluster` instead of the upstream image

### Philosophy

- **No NemoClaw logic changed** — guardrails, security policies, and the OpenClaw integration remain identical
- **Enterprise-safe** — TLS certificates are generated with 4096-bit RSA keys, proper SANs, and separate CA/server/client chains
- **Idempotent** — bootstrap skips if secrets already exist, safe for container restarts
- **Transparent** — the only difference is a self-contained cluster image that doesn't depend on external CLI timing

## License

Apache 2.0. See [LICENSE](LICENSE).
