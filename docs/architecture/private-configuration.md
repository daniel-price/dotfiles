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

The [real profile-repository POC](../guides/private-profiles-poc.md) can clone an explicitly authorised Git repository into a directory **outside** the public checkout, then stage a reviewed subset of tools, Bash commands, Zsh aliases/functions and application config. It requires separate consent before cloning, activation and each tool install; it never discovers or updates private repositories. The generated Zsh mise manifest combines exact public and selected profile tool versions, refusing incompatible pins. This does **not** imply that arbitrary TOML, application settings or scripts can be safely merged.

Encrypted whole-file history is a separate Git store, **not** the private overlay or this public checkout; see [secrets](secrets.md).

Do not include private identifiers, material or credentials in public commits, documentation, tests or CI artifacts. Use synthetic fixtures.
