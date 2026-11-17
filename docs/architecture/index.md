# Architecture

Use specialised tools rather than building another configuration manager.

| Responsibility | Owner |
| --- | --- |
| Initial setup, approvals and safe updates | Small Bash scripts |
| Versioned tools, packages and dotfile targets | mise |
| Public configuration and review history | This Git repository |
| Non-public configuration | Explicitly selected, authorised private source |
| Machine-specific keys and overrides | Local files outside Git |
| Encrypted credentials (planned) | age through mise |
| Isolated workloads | Rootless containers where appropriate |

The boundaries matter more than the implementation details:

- **Public setup must work alone.** Private sources are never discovered or cloned automatically.
- **Inspect before changing.** Conflict refusal, repeatability and explicit approval are defaults.
- **Keep secrets and identities out of public Git.** A private repository is not equivalent to encryption or permission to store work files.
- **Containerise selectively.** Host CLI tools, desktop apps, short-lived agents and persistent services have different needs.

Read more only when relevant: [platforms](platforms.md), [configuration layers](private-configuration.md), [secrets](secrets.md), [apps and containers](applications.md), [repository layout](repository-layout.md) and [architecture decisions](../decisions/0001-mise-age.md) (including [generated documentation](../decisions/0002-generated-configuration-docs.md)). For implementation status and POCs, use the [roadmap](../roadmap.md).
