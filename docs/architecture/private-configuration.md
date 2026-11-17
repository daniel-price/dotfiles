# Configuration layers

Configuration has three distinct trust boundaries:

| Layer | Example | Source |
| --- | --- | --- |
| Public baseline | Shell and editor defaults | This repository |
| Optional private profile | Authorised non-public settings | Explicitly selected private source |
| Machine-local state | SSH keys, age identities, device overrides | Outside Git |

Public setup works without private access. A private Git repository is **not encryption** and does not automatically authorise storing work-owned files.

## Current support

The [private overlay script](../guides/private-profiles.md) can link **one explicitly selected local directory** to one target through mise. It previews the change and refuses conflicting targets or dirty/divergent Git sources. It never discovers, clones or updates private repositories.

Full public → private → local precedence is **planned**, not implemented. When introducing it, test mise's effective config order and file target conflicts rather than assuming that TOML fragments override one another.

Encrypted whole-file history is a separate Git store, **not** the private overlay or this public checkout; see [secrets](secrets.md).

Do not include private identifiers, material or credentials in public commits, documentation, tests or CI artifacts. Use synthetic fixtures.
