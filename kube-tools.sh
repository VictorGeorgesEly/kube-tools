#!/bin/bash
# Bash/zsh compatible - Source this to install K8s DevOps tools
# Binaries installed in /tmp/kube-tools to avoid duplication across projects

# ============================================
# TOOL VERSIONS (update here)
# ============================================
KUBECTL_VERSION="1.35.0"
KUBECTX_VERSION="0.9.5"
KUBENS_VERSION="0.9.5"
HELM_VERSION="4.0.4"
HELMFILE_VERSION="1.2.3"
K9S_VERSION="0.50.16"
KUSTOMIZE_VERSION="kustomize/v5.8.0"
STERN_VERSION="1.33.1"
YQ_VERSION="TestB"
SOPS_VERSION="3.11.0"
KUBE_PS1_VERSION="0.9.0"
KUBESHARK_VERSION="52.11.0"
KUBESEAL_VERSION="0.34.0"

# ============================================
# CONFIGURATION
# ============================================
INSTALL_DIR="/tmp/kube-tools"
mkdir -p "$INSTALL_DIR"

# Get script directory for kubeconfig detection
_KUBE_TOOLS_SCRIPT_DIR="${BASH_SOURCE[0]:-${(%):-%x}}"
_KUBE_TOOLS_SCRIPT_DIR="$(cd "$(dirname "$_KUBE_TOOLS_SCRIPT_DIR")" && pwd)"

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

_install_kubectl() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "kubectl" "$KUBECTL_VERSION"; then
        echo "[OK] kubectl $KUBECTL_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing kubectl $KUBECTL_VERSION..."
    local url="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${os}/${arch}/kubectl"

    if curl -fsSL "$url" -o "$INSTALL_DIR/kubectl"; then
        chmod +x "$INSTALL_DIR/kubectl"
        _mark_version "kubectl" "$KUBECTL_VERSION"
        echo "[OK] kubectl $KUBECTL_VERSION installed"
    else
        echo "[ERR] Failed to install kubectl" >&2
        return 1
    fi
}

_install_kubectx() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    # kubectx
    if _check_version "kubectx" "$KUBECTX_VERSION"; then
        echo "[OK] kubectx $KUBECTX_VERSION already installed"
    else
        echo "[DL] Installing kubectx $KUBECTX_VERSION..."
        local url="https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_${os}_${arch}.tar.gz"

        if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" kubectx; then
            chmod +x "$INSTALL_DIR/kubectx"
            _mark_version "kubectx" "$KUBECTX_VERSION"
            echo "[OK] kubectx $KUBECTX_VERSION installed"
        else
            echo "[ERR] Failed to install kubectx" >&2
            return 1
        fi
    fi

    # kubens
    if _check_version "kubens" "$KUBENS_VERSION"; then
        echo "[OK] kubens $KUBENS_VERSION already installed"
    else
        echo "[DL] Installing kubens $KUBENS_VERSION..."
        local url="https://github.com/ahmetb/kubectx/releases/download/v${KUBENS_VERSION}/kubens_v${KUBENS_VERSION}_${os}_${arch}.tar.gz"

        if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" kubens; then
            chmod +x "$INSTALL_DIR/kubens"
            _mark_version "kubens" "$KUBENS_VERSION"
            echo "[OK] kubens $KUBENS_VERSION installed"
        else
            echo "[ERR] Failed to install kubens" >&2
            return 1
        fi
    fi
}

_install_helm() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "helm" "$HELM_VERSION"; then
        echo "[OK] helm $HELM_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing helm $HELM_VERSION..."
    local url="https://get.helm.sh/helm-v${HELM_VERSION}-${os}-${arch}.tar.gz"

    if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" --strip-components=1 "${os}-${arch}/helm"; then
        chmod +x "$INSTALL_DIR/helm"
        _mark_version "helm" "$HELM_VERSION"
        echo "[OK] helm $HELM_VERSION installed"
    else
        echo "[ERR] Failed to install helm" >&2
        return 1
    fi
}

_install_helmfile() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "helmfile" "$HELMFILE_VERSION"; then
        echo "[OK] helmfile $HELMFILE_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing helmfile $HELMFILE_VERSION..."
    local url="https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_${os}_${arch}.tar.gz"

    if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" helmfile; then
        chmod +x "$INSTALL_DIR/helmfile"
        _mark_version "helmfile" "$HELMFILE_VERSION"
        echo "[OK] helmfile $HELMFILE_VERSION installed"
    else
        echo "[ERR] Failed to install helmfile" >&2
        return 1
    fi
}

_install_k9s() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "k9s" "$K9S_VERSION"; then
        echo "[OK] k9s $K9S_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing k9s $K9S_VERSION..."
    local os_name
    case "$os" in
        darwin) os_name="Darwin" ;;
        linux) os_name="Linux" ;;
    esac

    local url="https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_${os_name}_${arch}.tar.gz"

    if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" k9s; then
        chmod +x "$INSTALL_DIR/k9s"
        _mark_version "k9s" "$K9S_VERSION"
        echo "[OK] k9s $K9S_VERSION installed"
    else
        echo "[ERR] Failed to install k9s" >&2
        return 1
    fi
}

_install_kustomize() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "kustomize" "$KUSTOMIZE_VERSION"; then
        echo "[OK] kustomize $KUSTOMIZE_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing kustomize $KUSTOMIZE_VERSION..."
    local url="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${os}_${arch}.tar.gz"

    if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" kustomize; then
        chmod +x "$INSTALL_DIR/kustomize"
        _mark_version "kustomize" "$KUSTOMIZE_VERSION"
        echo "[OK] kustomize $KUSTOMIZE_VERSION installed"
    else
        echo "[ERR] Failed to install kustomize" >&2
        return 1
    fi
}

_install_stern() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "stern" "$STERN_VERSION"; then
        echo "[OK] stern $STERN_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing stern $STERN_VERSION..."
    local url="https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_${os}_${arch}.tar.gz"

    if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" stern; then
        chmod +x "$INSTALL_DIR/stern"
        _mark_version "stern" "$STERN_VERSION"
        echo "[OK] stern $STERN_VERSION installed"
    else
        echo "[ERR] Failed to install stern" >&2
        return 1
    fi
}

_install_yq() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "yq" "$YQ_VERSION"; then
        echo "[OK] yq $YQ_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing yq $YQ_VERSION..."
    local url="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${os}_${arch}"

    if curl -fsSL "$url" -o "$INSTALL_DIR/yq"; then
        chmod +x "$INSTALL_DIR/yq"
        _mark_version "yq" "$YQ_VERSION"
        echo "[OK] yq $YQ_VERSION installed"
    else
        echo "[ERR] Failed to install yq" >&2
        return 1
    fi
}

_install_sops() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "sops" "$SOPS_VERSION"; then
        echo "[OK] sops $SOPS_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing sops $SOPS_VERSION..."
    local url="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${os}.${arch}"

    if curl -fsSL "$url" -o "$INSTALL_DIR/sops"; then
        chmod +x "$INSTALL_DIR/sops"
        _mark_version "sops" "$SOPS_VERSION"
        echo "[OK] sops $SOPS_VERSION installed"
    else
        echo "[ERR] Failed to install sops" >&2
        return 1
    fi
}

_install_kube_ps1() {
    if _check_version "kube-ps1" "$KUBE_PS1_VERSION"; then
        echo "[OK] kube-ps1 $KUBE_PS1_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing kube-ps1 $KUBE_PS1_VERSION..."
    local url="https://raw.githubusercontent.com/jonmosco/kube-ps1/v${KUBE_PS1_VERSION}/kube-ps1.sh"

    if curl -fsSL "$url" -o "$INSTALL_DIR/kube-ps1.sh"; then
        _mark_version "kube-ps1" "$KUBE_PS1_VERSION"
        echo "[OK] kube-ps1 $KUBE_PS1_VERSION installed"
    else
        echo "[ERR] Failed to install kube-ps1" >&2
        return 1
    fi
}

_install_kubeshark() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "kubeshark" "$KUBESHARK_VERSION"; then
        echo "[OK] kubeshark $KUBESHARK_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing kubeshark $KUBESHARK_VERSION..."
    # kubeshark uses different naming: darwin/linux and amd64/arm64
    local url="https://github.com/kubeshark/kubeshark/releases/download/v${KUBESHARK_VERSION}/kubeshark_${os}_${arch}"

    if curl -fsSL "$url" -o "$INSTALL_DIR/kubeshark"; then
        chmod +x "$INSTALL_DIR/kubeshark"
        _mark_version "kubeshark" "$KUBESHARK_VERSION"
        echo "[OK] kubeshark $KUBESHARK_VERSION installed"
    else
        echo "[ERR] Failed to install kubeshark" >&2
        return 1
    fi
}

_install_kubeseal() {
    local platform
    platform=$(_detect_platform) || return 1
    local os="${platform%_*}"
    local arch="${platform#*_}"

    if _check_version "kubeseal" "$KUBESEAL_VERSION"; then
        echo "[OK] kubeseal $KUBESEAL_VERSION already installed"
        return 0
    fi

    echo "[DL] Installing kubeseal $KUBESEAL_VERSION..."
    local url="https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-${os}-${arch}.tar.gz"

    if curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR" kubeseal; then
        chmod +x "$INSTALL_DIR/kubeseal"
        _mark_version "kubeseal" "$KUBESEAL_VERSION"
        echo "[OK] kubeseal $KUBESEAL_VERSION installed"
    else
        echo "[ERR] Failed to install kubeseal" >&2
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

    # Install all tools (errors don't terminate shell)
    _install_kubectl || true
    _install_kubectx || true
    _install_helm || true
    _install_helmfile || true
    _install_k9s || true
    _install_kustomize || true
    _install_stern || true
    _install_yq || true
    _install_sops || true
    _install_kube_ps1 || true
    _install_kubeshark || true
    _install_kubeseal || true

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
