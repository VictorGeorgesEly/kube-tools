#!/bin/bash
set -euo pipefail

# Debug option: DEBUG=1 ./get-latest-versions.sh
if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
fi

trap 'rc=$?; echo "[ERR] Échec (rc=$rc) à la ligne $LINENO: $BASH_COMMAND" >&2; exit $rc' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_TOOLS_FILE="${KUBE_TOOLS_FILE:-$SCRIPT_DIR/kube-tools.sh}"

APPLY=0
DRY_RUN=0

_usage() {
  cat <<'USAGE'
Usage:
  ./get-latest-versions.sh [--apply|-a] [--dry-run] [--file PATH]

Options:
  --apply, -a   Met à jour les *_VERSION dans kube-tools.sh (pour les tools OUTDATED)
  --dry-run     Affiche ce qui serait modifié sans écrire le fichier
  --file PATH   Chemin vers kube-tools.sh (par défaut: ./kube-tools.sh)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply|-a) APPLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --file) KUBE_TOOLS_FILE="$2"; shift 2 ;;
    -h|--help) _usage; exit 0 ;;
    *) echo "[ERR] Argument inconnu: $1" >&2; _usage; exit 2 ;;
  esac
done

# Function to get latest release tag from GitHub (robuste: ne fait pas échouer le script)
get_latest_release() {
  local repo=$1
  local json
  json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || true)"
  [[ -n "$json" ]] || { echo ""; return 0; }

  # Rate limit / erreurs GitHub => pas de tag
  echo "$json" | grep -q '"tag_name":' || { echo ""; return 0; }

  echo "$json" | sed -nE 's/.*"tag_name": *"([^"]+)".*/\1/p' | head -1
}

# Fallback: latest tag (robuste)
get_latest_tag() {
  local repo=$1
  local json
  # Fetch more tags to filter out non-version tags (like vTestB)
  json="$(curl -fsSL "https://api.github.com/repos/$repo/tags?per_page=30" 2>/dev/null || true)"
  [[ -n "$json" ]] || { echo ""; return 0; }

  echo "$json" | grep '"name":' | sed -nE 's/.*"name": *"([^"]+)".*/\1/p' | grep -E '^(kustomize/)?v?[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

_strip_v() {
  local v="$1"
  # Handle kustomize tags (kustomize/vX.Y.Z)
  v="${v#kustomize/}"
  # Handle standard v prefix
  echo "${v#v}"
}
_fail=0

_read_version_var() {
  local var="$1"
  local line
  line="$(grep -E "^${var}=" "$KUBE_TOOLS_FILE" | head -1 || true)"
  [[ -n "${line:-}" ]] || { echo ""; return 0; }
  echo "$line" | sed -E 's/^[A-Z0-9_]+=//; s/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

_inplace_sed() {
  # macOS sed wants: sed -i '' ; GNU sed: sed -i
  if sed --version >/dev/null 2>&1; then
    sed -i -E "$@"
  else
    sed -i '' -E "$@"
  fi
}

_set_version_var() {
  local var="$1" new="$2" file="$3"

  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "[DRY] set ${var}=${new} (in $file)"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v var="$var" -v val="$new" '
    BEGIN { done=0 }
    $0 ~ ("^" var "=") && done==0 {
      print var "=\"" val "\""
      done=1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

_check() {
  local name="$1" current="$2" latest="$3" varname="${4:-}"
  if [[ -z "${current:-}" ]]; then current="(missing)"; fi
  if [[ -z "${latest:-}" ]]; then latest="(N/A)"; fi

  if [[ "$latest" == "(N/A)" ]]; then
    printf "%-10s %-12s %-12s %s\n" "$name" "$current" "$latest" "[SKIP]"
    return 0
  fi
  if [[ "$current" == "$latest" ]]; then
    printf "%-10s %-12s %-12s %s\n" "$name" "$current" "$latest" "[OK]"
  else
    printf "%-10s %-12s %-12s %s\n" "$name" "$current" "$latest" "[OUTDATED]"
    _fail=1
    if [[ "$APPLY" == "1" && -n "${varname:-}" && "$latest" != "(N/A)" ]]; then
      _set_version_var "$varname" "$latest" "$KUBE_TOOLS_FILE"
      echo "[APPLY] ${varname} -> ${latest}"
    fi
  fi
}

_latest_github() {
  local repo="$1"
  local tag=""
  tag="$(get_latest_release "$repo")"
  [[ -n "${tag:-}" ]] || tag="$(get_latest_tag "$repo")"
  [[ -n "${tag:-}" ]] || { echo ""; return 0; }
  _strip_v "$tag"
}

echo "Fetching latest versions..."
echo "Using versions from: $KUBE_TOOLS_FILE"
if [[ ! -f "$KUBE_TOOLS_FILE" ]]; then
  echo "[ERR] Fichier introuvable: $KUBE_TOOLS_FILE" >&2
  exit 2
fi
if [[ "$APPLY" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "Mode: APPLY (mise à jour de $KUBE_TOOLS_FILE) [DRY-RUN]"
  else
    echo "Mode: APPLY (mise à jour de $KUBE_TOOLS_FILE)"
  fi
else
  echo "Mode: CHECK"
fi

echo "----------------------------------------"
printf "%-10s %-12s %-12s %s\n" "tool" "current" "latest" "status"
echo "----------------------------------------"

_kubectl_latest="$(_strip_v "$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null || true)")"
_check "kubectl" "$(_read_version_var KUBECTL_VERSION)" "${_kubectl_latest:-}" "KUBECTL_VERSION"

# GitHub releases/tags
_check "kubectx"   "$(_read_version_var KUBECTX_VERSION)"     "$(_latest_github "ahmetb/kubectx")" "KUBECTX_VERSION"
_check "kubens"    "$(_read_version_var KUBENS_VERSION)"      "$(_latest_github "ahmetb/kubectx")" "KUBENS_VERSION"
_check "helm"      "$(_read_version_var HELM_VERSION)"        "$(_latest_github "helm/helm")" "HELM_VERSION"
_check "helmfile"  "$(_read_version_var HELMFILE_VERSION)"    "$(_latest_github "helmfile/helmfile")" "HELMFILE_VERSION"
_check "k9s"       "$(_read_version_var K9S_VERSION)"         "$(_latest_github "derailed/k9s")" "K9S_VERSION"
_check "kustomize" "$(_read_version_var KUSTOMIZE_VERSION)"   "$(_latest_github "kubernetes-sigs/kustomize")" "KUSTOMIZE_VERSION"
_check "stern"     "$(_read_version_var STERN_VERSION)"       "$(_latest_github "stern/stern")" "STERN_VERSION"
_check "yq"        "$(_read_version_var YQ_VERSION)"          "$(_latest_github "mikefarah/yq")" "YQ_VERSION"
_check "sops"      "$(_read_version_var SOPS_VERSION)"        "$(_latest_github "getsops/sops")" "SOPS_VERSION"
_check "kube-ps1"  "$(_read_version_var KUBE_PS1_VERSION)"    "$(_latest_github "jonmosco/kube-ps1")" "KUBE_PS1_VERSION"
_check "kubeshark" "$(_read_version_var KUBESHARK_VERSION)"   "$(_latest_github "kubeshark/kubeshark")" "KUBESHARK_VERSION"
_check "kubeseal"  "$(_read_version_var KUBESEAL_VERSION)"    "$(_latest_github "bitnami-labs/sealed-secrets")" "KUBESEAL_VERSION"

echo "----------------------------------------"
if [[ "$_fail" -eq 0 ]]; then
  echo "[OK] Tout est à jour (ou latest indisponible)"
else
  if [[ "$APPLY" == "1" ]]; then
    echo "[WARN] Fichier mis à jour pour les tools OUTDATED"
  else
    echo "[ERR] Au moins un tool n'est pas à jour"
  fi
fi
exit "$_fail"
