# Declarative CLI POC comparison — 18 November 2026

Evaluation only. **Do not merge or migrate production scripts.**

## POCs and evidence

| Framework | PR | Linux Bash parser/validation | macOS Bash 3.2 | Markdown | Generated completion candidates | Interactive bare-Tab | Zsh in-process cd |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Usage 7.4.0 | [#60](https://github.com/daniel-price/dotfiles/pull/60) | CI pass | CI pass with Usage installed | Native, CI pass | Generated Zsh completion file; candidate content unverified | Unverified | Not implemented |
| argc 1.24.0 | [#61](https://github.com/daniel-price/dotfiles/pull/61) | CI pass | CI pass with argc installed | No native Markdown; man generation passes | Generated Zsh completion file; candidate content unverified | Unverified | Not implemented |
| Custom Bash registry | [#62](https://github.com/daniel-price/dotfiles/pull/62) | Functional CI pass on Ubuntu (earlier run) | Retest pending | Registry-derived Markdown | Candidate output tests; interactive Zsh unverified | Unverified | Wrapper implemented; current-shell behavior not PTY-tested |
| getoptions 3.3.2 + adapter | [#63](https://github.com/daniel-price/dotfiles/pull/63) | CI pass | CI pass, Bash 3.2.57 | DSL-derived via adapter, CI pass | Runtime candidates tested on both OS | Unverified | Wrapper implemented, Zsh smoke test added |
| Argsh pinned pure-Bash | [#63](https://github.com/daniel-price/dotfiles/pull/63) | Basic parsing tests pass | Unsupported Bash 3.2 | Pure-Bash `:usage docgen md` probe returns invalid command | Pure-Bash `:usage completion zsh` probe returns invalid command | Unverified | No working shared integration |
| Zsh `_gnu_generic` only | N/A, excluded | N/A | Zsh is portable | No declaration-derived Markdown | Derives option names from `--help` | Bare-Tab behavior unverified and value choices not intrinsic | Requires a separate parser/function |

### Interpretation

These are **the tests the POCs actually exercise**, not a guarantee of equivalent feature quality.

- **Verified** in #60/#61: their GitHub Actions and Shell checks passed, but neither explicitly sends Tab in a live Zsh PTY.
- **Verified** in #63 at functional CI commit `5d7675403e3ffa6771a8811d6d261a8c2401e9fc`: getoptions parsing/Markdown/runtime candidates passed on both OS; Argsh parsing passed on Linux; unsupported Argsh capabilities recorded as UNAVAILABLE (not as passes); macOS Bash 3.2 recorded UNSUPPORTED for Argsh.
- **Not verified anywhere yet**: real bare-Tab display, completion descriptions/menu UX, editing a declaration and testing live shell completion without re-registering, performance and generated man page quality in every candidate.

## 1–5 provisional ratings

5 = well suited; 1 = poor fit. `?` means the most important actual behavior remains unverified. Ratings are architectural assessments supported by the test column above, **not** completion acceptance results.

| Criterion | Importance | Usage | argc | getoptions+adapter | Custom | Argsh pure Bash |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Bare-Tab and choice completion | Critical | ? | ? | ? | ? | 1 |
| Markdown from one declaration | Critical | 5 | 2 | 4 | 4 | 1 |
| Single inline declaration | Critical | 5 | 5 | 4 | 4 | 4 |
| No rebuild after edits | Critical | 5 | 5 (with runtime argc) | 5 | 5 | 5 |
| Parsing and validation | High | 5 | 5 | 4 | 3 | 4 |
| Bash / Zsh integration | High | 3 | 3 | 4 | 4 | 2 |
| macOS Bash 3.2 / portability | Medium | 3 | 3 | 5 | 4 | 1 |
| Minimal per-command boilerplate | High | 5 | 4 | 3 | 3 | 4 |
| Maintainability | High | 4 | 4 | 3 | 2 | 3 |
| Runtime / startup performance | Medium | ? | ? | ? | ? | ? |
| Man pages | Low | ? | 5 | 1 | 1 | 1 tested |

A high Markdown score for getoptions/custom is qualified: we wrote a custom adapter; it is **not a framework-native feature**. For Usage/argc, runtime dependencies are not forbidden; a buildless argc script needs its executable on PATH. Argsh cannot satisfy macOS system Bash 3.2 without upgrading Bash and a different completion/docgen approach.

## Recommendation

**Prefer Usage for executable Bash utilities**, provided a manual bare-Tab test confirms that flags, choices, and descriptions work in a clean Zsh session. It is closest to *inline spec -> parsing/validation/help/Markdown/completion* with no build step, and avoids maintaining roughly 100 lines of custom introspection. If Usage cannot present flags on bare Tab, test whether a single global Zsh completion adapter or `zstyle` setting fixes this; don't adopt it without that result.

For native Zsh functions that must change `$PWD` (e.g. `,wt`), keep the actual `cd` in the current Zsh process; call a shared parser/resolver as necessary. Use one declarative command convention where feasible, not necessarily one implementation language.

**Runner verification still required** before any migration: interactive Zsh PTY, missing-binary fallback semantics, live-declaration edit, completion overhead, and a representative complex command (dynamic Git worktree/directory completion). Do not merge any POC.

## Manual test commands

```bash
gh pr checkout 60 && bash poc/cli-usage/check.sh --install
gh pr checkout 61 && bash poc/cli-argc/check.sh --install
gh pr checkout 62 && bash poc/cli-custom/check.sh
gh pr checkout 63 && bash poc/cli-alternatives/check.sh --install
```

In PR #63 follow its README for temporary Zsh completion registration and test:

```text
,case-text <TAB>
,case-text --<TAB>
,case-text --case <TAB>
,case-text --case=<TAB>
,jump-demo <TAB>
```

The user must **press Tab**, not literally type `<TAB>`. For documentation:

```bash
bash poc/cli-alternatives/getoptions/case-text --_poc_markdown > /tmp/getoptions-case-text.md
bash poc/cli-custom/bin/,case-text --_poc_markdown > /tmp/custom-case-text.md
mise -C poc/cli-usage exec -- usage generate markdown --file poc/cli-usage/bin/,case-text > /tmp/usage-case-text.md
mise -C poc/cli-argc exec -- argc --argc-mangen poc/cli-argc/bin/,case-text /tmp/argc-man
```
