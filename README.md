# kube-tools

Auto-install Kubernetes DevOps tools in `/tmp/kube-tools`. Source this script to get all tools ready.

## Usage

```bash
source kube-tools.sh
```

## Tools

| Tool | Description |
|------|-------------|
| kubectl | Kubernetes CLI |
| kubectx | Switch between clusters |
| kubens | Switch between namespaces |
| helm | Package manager |
| helmfile | Deploy Helm charts declaratively |
| k9s | Terminal UI |
| kustomize | Kubernetes native configuration |
| stern | Multi-pod log tailing |
| yq | YAML processor |
| sops | Secrets encryption |
| kube-ps1 | Prompt with context/namespace |
| kubeshark | Network traffic analyzer |
| kubeseal | Sealed Secrets CLI |

## Features

- Caches binaries in `/tmp/kube-tools` (shared across projects)
- Skips download if correct version already installed
- Auto-exports `KUBECONFIG` if a kubeconfig file is found in the same directory
- Compatible with **bash** and **zsh**, **macOS ARM64** and **Linux amd64/arm64**

## Update versions

Edit the version variables at the top of `kube-tools.sh`.

