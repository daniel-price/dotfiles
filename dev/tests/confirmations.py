"""Semantic confirmation actions for interactive CLI tests.

Tests specify decisions, not terminal keystrokes. The terminal input protocol
is centralised here so future prompt changes only affect this module.
"""


import os
import select
import subprocess
import termios
import time


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

def communicate_confirmations(process, master, slave, *decisions, timeout):
    """Reply to each prompt only after Bash has enabled single-key input.

    macOS Bash can flush input while switching terminal modes, so queuing
    responses before read starts is not portable. Drain the output pipe
    as we go and keep unused decisions harmless for early exits.
    """
    keys = iter(confirmation_keys(*decisions))
    output = bytearray()
    prompt = b"[y/N] "
    cursor = 0
    deadline = time.monotonic() + timeout

    def remaining():
        seconds = deadline - time.monotonic()
        if seconds <= 0:
            raise subprocess.TimeoutExpired(process.args, timeout, output=bytes(output))
        return seconds

    try:
        while True:
            if not select.select([process.stdout], [], [], remaining())[0]:
                raise subprocess.TimeoutExpired(process.args, timeout, output=bytes(output))
            chunk = os.read(process.stdout.fileno(), 65536)
            if not chunk:
                break
            output.extend(chunk)
            while (index := output.find(prompt, cursor)) != -1:
                cursor = index + len(prompt)
                key = next(keys, None)
                if key is None:
                    raise AssertionError("Unexpected confirmation prompt: " +
                                         output.decode(errors="replace"))
                # The prompt is printed just before read -s -n 1. Wait for
                # the slave's terminal mode as well as the prompt itself.
                while termios.tcgetattr(slave)[3] & (termios.ICANON | termios.ECHO):
                    time.sleep(min(0.001, remaining()))
                os.write(master, bytes([key]))
        process.wait(timeout=remaining())
        return output.decode(errors="replace")
    except BaseException:
        if process.poll() is None:
            process.kill()
        process.wait()
        raise
