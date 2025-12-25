#!/bin/bash
# Bash/zsh compatible - Source this to install K8s DevOps tools
# Binaries installed in /tmp/kube-tools to avoid duplication across projects

# ============================================
# CONFIGURATION
# ============================================
# Get script directory
_KUBE_TOOLS_SCRIPT_DIR="${BASH_SOURCE[0]:-$0}"
_KUBE_TOOLS_SCRIPT_DIR="$(cd "$(dirname "$_KUBE_TOOLS_SCRIPT_DIR")" && pwd)"

# Source tool versions
if [[ -f "$_KUBE_TOOLS_SCRIPT_DIR/tools.conf" ]]; then
    source "$_KUBE_TOOLS_SCRIPT_DIR/tools.conf"
else
    echo "[ERR] tools.conf not found in $_KUBE_TOOLS_SCRIPT_DIR" >&2
    return 1
fi

INSTALL_DIR="/tmp/kube-tools"
mkdir -p "$INSTALL_DIR"

# Detect OS and architecture
_detect_platform() {
    local os arch

    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        *)
            echo "Unsupported OS: $(uname -s)" >&2
            return 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)
            echo "Unsupported architecture: $(uname -m)" >&2
            return 1
            ;;
    esac

    echo "${os}_${arch}"
}

# Check if binary exists with correct version
_check_version() {
    local binary="$1"
    local expected_version="$2"
    local version_file="$INSTALL_DIR/.${binary}_version"

    if [[ -x "$INSTALL_DIR/$binary" ]] && [[ -f "$version_file" ]]; then
        local installed_version
        installed_version=$(cat "$version_file")
        if [[ "$installed_version" == "$expected_version" ]]; then
            return 0
        fi
    fi
    return 1
}

# Mark version as installed
_mark_version() {
    local binary="$1"
    local version="$2"
    echo "$version" > "$INSTALL_DIR/.${binary}_version"
}

# ============================================
# INSTALL FUNCTIONS
# ============================================

_install_tool() {
    local name="$1"
    local version="$2"
    local install_type="$3"
    local url_template="$4"
    local archive_path="$5"

    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"
    local os_title
    case "$os" in
        darwin) os_title="Darwin" ;;
        linux) os_title="Linux" ;;
    esac

    # Check if already installed
    if _check_version "$name" "$version"; then
        echo "[OK] $name $version already installed"
        return 0
    fi

    echo "[DL] Installing $name $version..."

    # Prepare URL
    local url="$url_template"
    url="${url//%VERSION%/$version}"
    url="${url//%OS%/$os}"
    url="${url//%ARCH%/$arch}"
    url="${url//%OS_TITLE%/$os_title}"

    # Prepare archive path if needed
    local path_in_archive="$archive_path"
    if [[ -n "$path_in_archive" ]]; then
        path_in_archive="${path_in_archive//%VERSION%/$version}"
        path_in_archive="${path_in_archive//%OS%/$os}"
        path_in_archive="${path_in_archive//%ARCH%/$arch}"
        path_in_archive="${path_in_archive//%OS_TITLE%/$os_title}"
    fi

    if [[ "$install_type" == "binary" ]]; then
        if curl -fsSL "$url" -o "$INSTALL_DIR/$name"; then
            chmod +x "$INSTALL_DIR/$name"
            _mark_version "$name" "$version"
            echo "[OK] $name $version installed"
        else
            echo "[ERR] Failed to install $name" >&2
            return 1
        fi
    elif [[ "$install_type" == "script" ]]; then
        if curl -fsSL "$url" -o "$INSTALL_DIR/$name.sh"; then
            _mark_version "$name" "$version"
            echo "[OK] $name $version installed"
        else
            echo "[ERR] Failed to install $name" >&2
            return 1
        fi
    elif [[ "$install_type" == "tarball" ]]; then
        # If archive_path is set, extract specific file
        # Otherwise extract all (or specific directory logic?)
        # Current logic mostly extracts specific binary or strips components.

        # Special handling for helm (strip components)
        if [[ "$name" == "helm" ]]; then
             if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" --strip-components=1 "$path_in_archive"; then
                chmod +x "$INSTALL_DIR/$name"
                _mark_version "$name" "$version"
                echo "[OK] $name $version installed"
             else
                echo "[ERR] Failed to install $name" >&2
                return 1
             fi
             return 0
        fi

        # Standard extraction
        if [[ -n "$path_in_archive" ]]; then
            # Extract specific file to stdout and write to destination
            # Note: tar -O extracts to stdout.
            # Some tars don't support -O with specific files easily or behave differently.
            # Let's try to extract to a temp dir to be safe and move.
            local tmp_dir
            tmp_dir=$(mktemp -d)
            if curl -fsSL "$url" | tar -xz -C "$tmp_dir"; then
                if [[ -f "$tmp_dir/$path_in_archive" ]]; then
                    mv "$tmp_dir/$path_in_archive" "$INSTALL_DIR/$name"
                    chmod +x "$INSTALL_DIR/$name"
                    _mark_version "$name" "$version"
                    echo "[OK] $name $version installed"
                    rm -rf "$tmp_dir"
                else
                    echo "[ERR] Binary '$path_in_archive' not found in archive for $name" >&2
                    ls -R "$tmp_dir" >&2
                    rm -rf "$tmp_dir"
                    return 1
                fi
            else
                echo "[ERR] Failed to download/extract $name" >&2
                rm -rf "$tmp_dir"
                return 1
            fi
        else
            # Extract everything to INSTALL_DIR (e.g. if tarball structure is flat or we want everything)
            # But usually we want a single binary.
            # If no path specified, assume binary name matches tool name at root?
            # Let's assume path_in_archive is required for tarballs unless we want full extraction.
            # For now, all our tarballs have path_in_archive.
            echo "[ERR] No archive path specified for tarball $name" >&2
            return 1
        fi
    else
        echo "[ERR] Unknown install type: $install_type" >&2
        return 1
    fi
}

# ============================================
# KUBECONFIG DETECTION
# ============================================

_detect_kubeconfig() {
    local kubeconfig_file=""

    # Search for kubeconfig file in script directory
    for pattern in "kubeconfig.yaml" "kubeconfig.yml" "kubeconfig" ".kubeconfig" "config.yaml" "config.yml"; do
        if [[ -f "$_KUBE_TOOLS_SCRIPT_DIR/$pattern" ]]; then
            kubeconfig_file="$_KUBE_TOOLS_SCRIPT_DIR/$pattern"
            break
        fi
    done

    # Also check for *kubeconfig* pattern (with nullglob to avoid errors)
    if [[ -z "$kubeconfig_file" ]]; then
        local f
        local matches
        matches=$(find "$_KUBE_TOOLS_SCRIPT_DIR" -maxdepth 1 -name "*kubeconfig*" -o -name "*kube-config*" 2>/dev/null | head -1)
        if [[ -n "$matches" ]] && [[ -f "$matches" ]]; then
            kubeconfig_file="$matches"
        fi
    fi

    if [[ -n "$kubeconfig_file" ]]; then
        export KUBECONFIG="$kubeconfig_file"
        echo "[OK] KUBECONFIG set to: $kubeconfig_file"
    fi
}

# ============================================
# MAIN INSTALLATION
# ============================================

_install_kube_tools() {
    echo "Installing Kubernetes tools in $INSTALL_DIR"
    echo "=================================================="

    if [[ -z "${TOOLS_METADATA:-}" ]]; then
        echo "[ERR] TOOLS_METADATA not found. Please check tools.conf" >&2
        return 1
    fi

    for entry in "${TOOLS_METADATA[@]}"; do
        # entry format: NAME|VAR_NAME|CHECK_TYPE|CHECK_SOURCE|INSTALL_TYPE|INSTALL_URL|ARCHIVE_PATH
        IFS='|' read -r name var_name _ _ install_type install_url archive_path <<< "$entry"

        # Get version from variable name
        local version
        eval version=\$$var_name

        if [[ -z "$version" ]]; then
            echo "[WARN] Version for $name ($var_name) is empty, skipping."
            continue
        fi

        _install_tool "$name" "$version" "$install_type" "$install_url" "$archive_path" || true
    done

    echo "=================================================="
    echo "Installation complete"

    # Add to PATH if not already present
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *)
            export PATH="$INSTALL_DIR:$PATH"
            echo "[OK] $INSTALL_DIR added to PATH"
            ;;
    esac
}

# Run installation
_install_kube_tools

# Detect and export kubeconfig
_detect_kubeconfig

# Source kube-ps1 if installed
if [[ -f "$INSTALL_DIR/kube-ps1.sh" ]]; then
    source "$INSTALL_DIR/kube-ps1.sh"
fi

# Show installed versions
echo ""
echo "Installed versions:"
echo "  kubectl:   $KUBECTL_VERSION"
echo "  kubectx:   $KUBECTX_VERSION"
echo "  kubens:    $KUBENS_VERSION"
echo "  helm:      $HELM_VERSION"
echo "  helmfile:  $HELMFILE_VERSION"
echo "  k9s:       $K9S_VERSION"
echo "  kustomize: $KUSTOMIZE_VERSION"
echo "  stern:     $STERN_VERSION"
echo "  yq:        $YQ_VERSION"
echo "  sops:      $SOPS_VERSION"
echo "  kube-ps1:  $KUBE_PS1_VERSION"
echo "  kubeshark: $KUBESHARK_VERSION"
echo "  kubeseal:  $KUBESEAL_VERSION"
echo ""
echo "Available: kubectl, kubectx, kubens, helm, helmfile, k9s, kustomize, stern, yq, sops, kubeshark, kubeseal"
echo "kube-ps1: use 'kube_ps1' in your PS1, e.g. PS1='[\$(kube_ps1)] \$ '"
