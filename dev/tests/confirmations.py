"""Semantic confirmation actions for interactive CLI tests.

Tests specify decisions, not terminal keystrokes. The terminal input protocol
is centralised here so future prompt changes only affect this module.
"""


class Confirm:
    """Approve the presented action."""


class Deny:
    """Decline the presented action."""


def confirmation_keys(*decisions):
    """Encode decisions as immediate, single-key terminal input."""
    keys = {Confirm: b"y", Deny: b"n"}
    try:
        return b"".join(keys[type(decision)] for decision in decisions)
    except KeyError as error:
        raise TypeError("Expected Confirm() or Deny()") from error
