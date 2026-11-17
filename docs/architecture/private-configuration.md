# Public, private and machine-local configuration

**Status: narrow prototype implemented.** A user-supplied private directory can
be linked to one explicit target through mise. There is still no automatic
private repository discovery, cloning, profile selection, precedence merge or
secrets integration.

Some configuration is not secret but should not be public; other files are
specific to work or to an individual machine. Treat these as **distinct trust
boundaries**, rather than encrypting or publishing everything indiscriminately.

## The three layers

| Layer | Examples | Storage and availability |
| --- | --- | --- |
| **1. Public baseline** | Common shell/editor defaults, tool definitions and platform-safe templates | This repository; must work independently on every supported machine |
| **2. Optional private overlay** | Approved non-public personal settings or authorised work profiles | Separate access-controlled Git repo, chosen only on explicitly selected machines |
| **3. Local-only override** | Per-device SSH keys, age identities, host-only state and unsynchronised settings | Machine-local files, outside every Git repository |

A separate fourth concept is **mise's encrypted tracked-file history**. That is
not the private configuration repo, and has its own Git origin and decryption
rules. See [Secrets](secrets.md).

A private repository is **not the same as encrypted secrets**, and a personal
private GitHub repository is **not automatically authorised** for employer-owned
content. Work configuration must stay in storage approved by the employer
and only be installed on authorised machines. Never publish real private repo
names, URLs, machine identifiers or contents in this public documentation.

## Composition contract

Intended ordering:

1. Apply public defaults.
2. If explicitly approved and enabled, apply a private profile.
3. Keep machine-local overrides authoritative for host-specific state.

This is **design intent, not implemented precedence**. Mise loads global
`conf.d` fragments alphabetically *before* global `config.toml`, and
project config may override global config. A future implementation must
choose a documented mechanism and inspect the effective order with
`mise config ls`. Don't assume a file placed in `conf.d` automatically wins
over the public configuration.

File deployment is a separate problem from merging TOML values. Prefer
non-overlapping output paths; if both sources target the same file, show
the difference and ask before **each** modifying action. Declined or
unresolvable conflicts must not overwrite live configuration. Verify safe
reruns and rollback.

## Bootstrap and update rules

- The public bootstrap works **without** access to private configuration.
- Private sources are **opt-in only**: never list, discover, guess, clone,
  trust, sync or execute an unknown repository because a computer seems
  work-related.
- The user must explicitly choose an authorised source on the target
  machine. Verify the remote and access before each proposed clone/update,
  protect dirty/diverged checkouts, and use a reviewed fast-forward policy.
- A missing/denied private source must not break public setup or disclose
  sensitive identifiers. Work profiles must not be installed on personal
  machines automatically.
- Private content and remote identifiers must never flow back to public Git,
  PR logs, CI artifacts, the docs build or GitHub Pages.
- Use **synthetic private fixtures** for implementation/testing, not actual
  employer repositories or credentials.

The current prototype is deliberately narrow. `scripts/setup/apply-private-overlay.sh`
takes an explicit source directory and target directory, previews them with
`mise dot diff` and `mise dot apply --dry-run`, asks once before `mise dot apply`,
and refuses existing real paths, different symlinks, dirty checkouts and
diverged or behind branches. It never discovers, clones, fetches, updates or
persistently trusts a repository; the temporary generated mise config is trusted
only for the invoking process. Private sources and their identifiers remain on
the local machine. Full profile composition and precedence are still planned.

See [the intended how-to](../guides/private-profiles.md),
[ADR-0003](../decisions/0003-private-config-layers.md), and
[mise's configuration loading documentation](https://mise.jdx.dev/configuration.html).
