#!/usr/bin/env bash
# Append BamBuddy Virtual Printer CA to Bambu Studio / OrcaSlicer printer.cer
# https://wiki.bambuddy.cool/features/virtual-printer/#step-2-append-the-bambuddy-ca-certificate-to-slicer
#
# macOS: Bambu Studio and OrcaSlicer ignore the system keychain — the CA must
# live in each app's bundled printer.cer (append only; do not replace).
#
# macOS sealed app bundles under /Applications cannot be modified, even with
# sudo. This script patches a user-owned copy under ~/Applications/.
#
# Examples:
#   ./append-vp-ca-to-slicer.sh --ca-file ~/Downloads/bambuddy-virtual-printer-ca.crt
#   ./append-vp-ca-to-slicer.sh --ca-file ~/Downloads/bbl_ca.crt --slicer orca --dry-run

set -euo pipefail

CA_FILE=""
SLICER="both"
DRY_RUN=false

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  cat <<'EOF'

Options:
  --ca-file PATH     PEM file to append (bbl_ca.crt / bambuddy-virtual-printer-ca.crt)
  --slicer NAME      bambu | orca | both (default: both)
  --dry-run          Show actions without writing
  -h, --help         This help

After running: fully quit the slicer (Cmd+Q on macOS), then reopen it.

On macOS, /Applications/*.app bundles are sealed — the script patches a copy
under ~/Applications/ instead. Launch the slicer from that copy.
Backups: ~/Library/Application Support/BambBuddy/printer.cer-backups/.
EOF
}

log() { printf '%s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ca-file) CA_FILE=$2; shift 2 ;;
    --slicer) SLICER=$2; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "$CA_FILE" ]] || die "pass --ca-file PATH"
case "$SLICER" in
  bambu|orca|both) ;;
  *) die "--slicer must be bambu, orca, or both" ;;
esac

command -v openssl >/dev/null || die "openssl not found"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

[[ -f "$CA_FILE" ]] || die "CA file not found: $CA_FILE"
openssl x509 -in "$CA_FILE" -noout -subject >/dev/null 2>&1 \
  || die "CA file is not a valid PEM certificate: $CA_FILE"

ca_fp=$(openssl x509 -in "$CA_FILE" -noout -fingerprint -sha256 | sed 's/sha256 Fingerprint=//I' | tr -d ':')
log "BamBuddy CA SHA-256: $ca_fp"

printer_cer_paths() {
  case "$(uname -s)" in
    Darwin)
      [[ "$SLICER" == bambu || "$SLICER" == both ]] && {
        printf '%s\n' \
          "/Applications/BambuStudio.app/Contents/Resources/cert/printer.cer" \
          "${HOME}/Applications/BambuStudio.app/Contents/Resources/cert/printer.cer"
      }
      [[ "$SLICER" == orca || "$SLICER" == both ]] && {
        printf '%s\n' \
          "/Applications/OrcaSlicer.app/Contents/Resources/cert/printer.cer" \
          "${HOME}/Applications/OrcaSlicer.app/Contents/Resources/cert/printer.cer"
      }
      ;;
    Linux)
      [[ "$SLICER" == bambu || "$SLICER" == both ]] && {
        printf '%s\n' \
          "/usr/share/BambuStudio/resources/cert/printer.cer" \
          "/usr/share/bambu-studio/resources/cert/printer.cer"
      }
      [[ "$SLICER" == orca || "$SLICER" == both ]] && \
        printf '%s\n' "/usr/share/OrcaSlicer/resources/cert/printer.cer"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      [[ "$SLICER" == bambu || "$SLICER" == both ]] && \
        printf '%s\n' "/c/Program Files/Bambu Studio/resources/cert/printer.cer"
      [[ "$SLICER" == orca || "$SLICER" == both ]] && \
        printf '%s\n' "/c/Program Files/OrcaSlicer/resources/cert/printer.cer"
      ;;
    *)
      die "unsupported OS: $(uname -s)"
      ;;
  esac
}

cert_already_present() {
  local printer_cer=$1
  local block="" line fp
  while IFS= read -r line || [[ -n "$line" ]]; do
    block+="$line"$'\n'
    if [[ "$line" == *"-----END CERTIFICATE-----"* ]]; then
      fp=$(printf '%s' "$block" | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
        | sed 's/sha256 Fingerprint=//I' | tr -d ':') || { block=""; continue; }
      if [[ "$fp" == "$ca_fp" ]]; then
        return 0
      fi
      block=""
    fi
  done < "$printer_cer"
  return 1
}

BACKUP_DIR="${HOME}/Library/Application Support/BambBuddy/printer.cer-backups"
MACOS_PATCH_ROOT="${HOME}/Applications"
mkdir -p "$BACKUP_DIR" 2>/dev/null || true

resign_macos_app() {
  local app=$1
  command -v codesign >/dev/null || die "codesign not found (required after patching app bundle)"
  log "Re-signing $(basename "$app") (editing printer.cer invalidates the bundle signature)"
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] codesign --force --deep --sign - \"$app\""
    return 0
  fi
  codesign --force --deep --sign - "$app"
}

declare -a LAUNCH_APPS=()
PRINTER_CER_TARGET=""

darwin_app_from_cer() {
  local printer_cer=$1
  if [[ "$printer_cer" == /Applications/*.app/Contents/* \
     || "$printer_cer" == "$HOME"/Applications/*.app/Contents/* ]]; then
    printf '%s\n' "${printer_cer%%/Contents/*}"
    return 0
  fi
  return 1
}

resolve_printer_cer() {
  local source_cer=$1
  if [[ "$(uname -s)" != Darwin ]]; then
    PRINTER_CER_TARGET="$source_cer"
    return
  fi

  local source_app rel patched_app patched_cer
  source_app=$(darwin_app_from_cer "$source_cer") || {
    PRINTER_CER_TARGET="$source_cer"
    return
  }

  rel="${source_cer#"$source_app"}"
  if [[ "$source_app" == "$MACOS_PATCH_ROOT"/* ]]; then
    patched_app="$source_app"
    patched_cer="$source_cer"
  else
    patched_app="$MACOS_PATCH_ROOT/$(basename "$source_app")"
    patched_cer="${patched_app}${rel}"

    if [[ "$DRY_RUN" != true && ! -d "$patched_app" ]]; then
      log "Copying $(basename "$source_app") -> $patched_app"
      log "(macOS blocks edits inside /Applications; using a user-owned copy)"
      mkdir -p "$MACOS_PATCH_ROOT"
      ditto "$source_app" "$patched_app"
      xattr -cr "$patched_app" 2>/dev/null || true
    elif [[ "$DRY_RUN" == true && ! -d "$patched_app" ]]; then
      log "[dry-run] ditto $source_app -> $patched_app"
    fi
  fi

  LAUNCH_APPS+=("$patched_app")
  PRINTER_CER_TARGET="$patched_cer"
}

backup_path_for() {
  local printer_cer=$1
  local tag
  tag=$(echo "$printer_cer" | tr '/ ' '__')
  printf '%s/%s.%s\n' "$BACKUP_DIR" "$tag" "$(date +%Y%m%d%H%M%S)"
}

append_ca() {
  local source_cer=$1
  local printer_cer backup merged="$tmpdir/$(basename "$source_cer").merged"
  local source_copy="$tmpdir/$(basename "$source_cer").orig"

  resolve_printer_cer "$source_cer"
  printer_cer="$PRINTER_CER_TARGET"
  [[ -f "$printer_cer" || "$DRY_RUN" == true ]] || die "printer.cer not found: $printer_cer"

  if [[ -f "$printer_cer" ]] && cert_already_present "$printer_cer"; then
    log "skip (CA already present): $printer_cer"
    if [[ "$(uname -s)" == Darwin && "$printer_cer" == "$HOME"/Applications/*.app/* ]]; then
      resign_macos_app "${printer_cer%%/Contents/*}"
    fi
    return 0
  fi

  log "append CA to: $printer_cer"
  if [[ "$DRY_RUN" == true ]]; then
    backup=$(backup_path_for "$printer_cer")
    log "[dry-run] backup -> $backup"
    log "[dry-run] write merged bundle -> $printer_cer"
    return 0
  fi

  cat "$printer_cer" > "$source_copy"
  backup=$(backup_path_for "$printer_cer")
  cp -p "$source_copy" "$backup"
  log "backup: $backup"

  awk 'NF || NR==1 { print }' "$source_copy" > "$merged"
  printf '\n' >> "$merged"
  cat "$CA_FILE" >> "$merged"
  cp "$merged" "$printer_cer"
  log "updated: $printer_cer ($(grep -c 'BEGIN CERTIFICATE' "$merged") certs)"
  if [[ "$(uname -s)" == Darwin && "$printer_cer" == "$HOME"/Applications/*.app/* ]]; then
    resign_macos_app "${printer_cer%%/Contents/*}"
  fi
}

found=0
while IFS= read -r path; do
  [[ -f "$path" ]] || continue
  found=1
  append_ca "$path"
done < <(printer_cer_paths | sort -u)

if [[ "$found" -eq 0 ]]; then
  log "No slicer printer.cer found for --slicer $SLICER on $(uname -s)."
  log "Install Bambu Studio / OrcaSlicer, or pass a custom path by editing the script."
  log "Wiki paths: https://wiki.bambuddy.cool/features/virtual-printer/#step-2-append-the-bambuddy-ca-certificate-to-slicer"
  exit 1
fi

log ""
log "Done. Fully quit the slicer (Cmd+Q), then reopen before connecting to the virtual printer."
if [[ "$(uname -s)" == Darwin && ${#LAUNCH_APPS[@]} -gt 0 ]]; then
  log ""
  log "On macOS, use the patched copy (not /Applications):"
  for app in $(printf '%s\n' "${LAUNCH_APPS[@]}" | sort -u); do
    log "  open \"$app\""
  done
fi
