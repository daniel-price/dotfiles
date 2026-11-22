# Architecture

Use specialised tools rather than building another configuration manager.

| Responsibility | Owner |
| --- | --- |
| Initial setup, approvals and safe updates | Small Bash scripts |
| Versioned tools, packages and dotfile targets | mise |
| **Base** configuration and review history | This public Git repository |
| Optional **Profiles** | Explicitly selected, authorised Git repositories (reusable across devices) |
| Per-device configuration (deferred) | Manually managed; no Local layer yet |
| Encrypted credentials (planned) | age through mise |
| Isolated workloads | Rootless containers where appropriate |

The boundaries matter more than the implementation details:

- **Base setup must work alone.** Profiles are never discovered or cloned automatically.
- **Inspect before changing.** Conflict refusal, repeatability and explicit approval are defaults.
- **Keep secrets and identities out of public Git.** A private repository is not equivalent to encryption or permission to store work files.
- **Containerise selectively.** Host CLI tools, desktop apps, short-lived agents and persistent services have different needs.

Read more only when relevant: [platforms](platforms.md), [Base and Profiles](configuration.md), [secrets](secrets.md), [apps and containers](applications.md), [repository layout](repository-layout.md) and [architecture decisions](../decisions/0001-mise-age.md) (including [generated documentation](../decisions/0002-generated-configuration-docs.md)). For implementation status and POCs, use the [roadmap](../roadmap.md).
