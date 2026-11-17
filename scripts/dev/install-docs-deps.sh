#!/usr/bin/env bash
set -euo pipefail

# Use an activated virtual environment locally; CI provisions its own Python.
exec python3 -m pip install zensical
