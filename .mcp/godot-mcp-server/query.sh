#!/bin/bash
# Quick wrapper for godot-query.js
# Usage: ./query.sh <command> [args...]
# Example: ./query.sh get_current_scene

cd "$(dirname "$0")"
node godot-query.js "$@"
