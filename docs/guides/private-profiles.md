# Use an optional private configuration profile

**Status: planned.** No implementation or private repo has been configured.

A future machine-specific setup will follow these steps, not automatically
download private settings just because a machine appears to be used for work.

1. Classify each file: public, authorised private, or machine-local.
   Work-owned files require an employer-approved destination and device.
2. Explicitly select a private repository and profile **on the machine**,
   only after checking permission and intended scope. Do not place its remote
   URL, credentials or contents in this public repository.
3. Review clone/update operations and require an individual confirmation.
   Leave a dirty/diverged checkout unchanged until resolved.
4. Verify the effective mise merge order: public defaults, private overlay
   (when selected), then local-only overrides.
5. Preview every target path; require separate approval for collisions.
   Declining should preserve the public-only setup.
6. Test no private access, failed authentication, empty/private profile,
   collisions, repeated runs and safe cleanup with **dummy fixtures**.
7. Check that neither public CI/site output nor Git history includes
   private contents or identifiers.

There are intentionally no executable setup commands yet. See
[configuration layers](../architecture/private-configuration.md),
[Secrets](../architecture/secrets.md) and
[ADR-0003](../decisions/0003-private-config-layers.md).
