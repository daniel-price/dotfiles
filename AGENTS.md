# Pull request test plans

Every PR must include a simple, concrete manual test plan in its description so
the maintainer can test the change before merging.

- State the required OS, prerequisites, starting directory and any expected writes.
- Give numbered steps with copyable commands and an expected result after each.
- Match the plan to the actual PR; replace the template's authoring instructions.
- Cover the normal path, declined confirmation, repeat runs and relevant failures
  when the changed behaviour makes those checks applicable.
- Test modifying operations in a disposable environment or isolated test paths;
  explain safe cleanup and never ask the reviewer to risk existing configuration.
- Separate automated/agent validation from manual checks still awaiting review.
  Leave reviewer checkboxes unchecked until the maintainer reports the result.
- Update the plan when the implementation changes. Record untested platforms
  honestly instead of implying that fixtures prove real-machine compatibility.

Use `.github/pull_request_template.md` as the structure, including when opening
PRs through an API rather than GitHub's web interface.
