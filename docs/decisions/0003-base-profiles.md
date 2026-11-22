# ADR-0003: Standalone Base with optional Profiles

**Status:** Accepted (terminology updated 2026-11-22)
**Date:** 2026-11-15

## Context

The public dotfiles repository must work across macOS and Pop!_OS without exposing authorised non-public configuration. Users need optional, independently versioned settings for purposes such as personal development, work and home servers. Not every extra configuration is private, and a profile need not belong to one device.

## Decision

- **Base** is the public `dotfiles` checkout and works independently.
- **Profiles** are reusable optional Git repositories, selected explicitly, with no automatic discovery. A device may select several; a Profile may serve many devices.
- Git repository **visibility** is a security concern, not a configuration type. Profiles can be public or private, but employer-owned material must remain in authorised storage.
- Secrets and identity keys remain outside public Git; private Git does not provide encryption.
- **Local** (per-device configuration) is **deferred**. No third configuration layer is implemented or required for the current POC.

The current tested composition is **Base → selected Profiles**. Detect conflicts and refuse silent replacement. Preview and ask before cloning, activating, installing tools or deactivating; never make Base depend on Profile credentials.

## Alternatives

- **Encrypt everything in Base:** needlessly broad exposure of metadata and history.
- **Ignore all non-Base files:** no reusable versioned Profile source.
- **Git submodules:** couple public bootstrap to optional access and repository lifecycles.
- **Automatically discover Profiles:** violates explicit authorisation.

## Consequences and follow-up

The [Profiles POC](../guides/profiles.md) implements explicit selection and a constrained subset of tool, environment, shell and app configuration. Finish safe Git updates and rollback before production rollout. Introduce Local only if actual device-specific needs justify it, as tracked in the [roadmap](../roadmap.md).

The original design referred to “public/private/local” layers; these were deployment/security properties, not the current user-facing model. [Base and Profiles architecture](../architecture/configuration.md).
