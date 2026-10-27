#!/usr/bin/env bash
# Shared PCI BDF validation and normalization for installer-side checks.
# Keep these helpers side-effect-free so they can be regression-tested directly.

valid_pci_address() {
  local address="${1-}"
  address="${address,,}"
  [[ "$address" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[01][0-9a-f]\.[0-7]$ ]]
}

normalize_pci_address() {
  local address="${1-}"
  printf '%s\n' "${address,,}"
}
