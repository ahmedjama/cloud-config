#!/usr/bin/env bash
# multipass-launcher.sh
# REQUIRED: <cloud-init-file>
# OPTIONAL: <vm-name> --mount <host>:<vm> [ubuntu] [cpus] [mem] [disk]
# If no VM name → auto-generate (e.g. web-abc123)

set -euo pipefail

# -------------------------------------------------
# 1. Resolve script directory
# -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------
# 2. Defaults
# -------------------------------------------------
DEFAULT_UBUNTU="24.04"
DEFAULT_CPUS=2
DEFAULT_MEM="4G"
DEFAULT_DISK="20G"
MOUNT_SPEC=""

# -------------------------------------------------
# 3. Usage
# -------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [vm-name] <cloud-init-file> [--mount <host>:<vm>] [ubuntu] [cpus] [mem] [disk]

Required:
  <cloud-init-file> – File in same folder as this script

Optional:
  [vm-name]         – If omitted, auto-generated (e.g. web-abc123)
  --mount <host>:<vm> – Mount host dir into VM
  [ubuntu]          – Default: $DEFAULT_UBUNTU
  [cpus] [mem] [disk] – Default: $DEFAULT_CPUS, $DEFAULT_MEM, $DEFAULT_DISK

Examples:
  $0 cloud-init-web.yaml
  $0 web-prod cloud-init-web.yaml --mount ./code:/home/ubuntu/app
  $0 api cloud-init-api.yaml 22.04 4 8G 30G

Available cloud-init files:
$(ls "$SCRIPT_DIR"/cloud-init-*.yaml 2>/dev/null | sed 's|.*/|  |' || echo "  (none)")

EOF
  exit 1
}

[[ $# -ge 1 ]] || usage

# -------------------------------------------------
# 4. Parse arguments
# -------------------------------------------------
VM_NAME=""
CLOUD_INIT_FILE=""

# First non-flag arg is either VM name or cloud-init file
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mount)
      [[ -n "${2:-}" ]] || { echo "Error: --mount requires <host>:<vm>"; usage; }
      MOUNT_SPEC="$2"
      shift 2
      ;;
    --*)
      echo "Unknown flag: $1"
      usage
      ;;
    *)
      if [[ -z "$VM_NAME" ]]; then
        VM_NAME="$1"
      elif [[ -z "$CLOUD_INIT_FILE" ]]; then
        CLOUD_INIT_FILE="$SCRIPT_DIR/$1"
      else
        echo "Too many positional args"
        usage
      fi
      shift
      ;;
  esac
done

# -------------------------------------------------
# 5. Auto-generate VM name if not provided
# -------------------------------------------------
if [[ -z "$VM_NAME" ]]; then
  # Extract prefix from cloud-init file (e.g. cloud-init-web.yaml → web)
  PREFIX=$(basename "$CLOUD_INIT_FILE" .yaml | sed 's/cloud-init-//')
  [[ "$PREFIX" == "cloud-init" ]] && PREFIX="vm"
  SUFFIX=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
  VM_NAME="${PREFIX}-${SUFFIX}"
  echo "No VM name provided → using auto-generated: $VM_NAME"
fi

# -------------------------------------------------
# 6. Validate cloud-init file
# -------------------------------------------------
[[ -f "$CLOUD_INIT_FILE" ]] || {
  echo "Error: Cloud-init file not found: $CLOUD_INIT_FILE"
  echo "Available in $SCRIPT_DIR:"
  ls "$SCRIPT_DIR"/cloud-init-*.yaml 2>/dev/null | sed 's|^|  |' || echo "  (none)"
  exit 1
}

# -------------------------------------------------
# 7. Parse optional resource args (after cloud-init)
# -------------------------------------------------
# Re-parse remaining args (they are after cloud-init file)
ARGS=()
for arg in "$@"; do
  [[ "$arg" != "--mount" && ! "$arg" =~ ^--mount= ]] && ARGS+=("$arg")
done

UBUNTU_VERSION="${ARGS[0]:-$DEFAULT_UBUNTU}"
CPUS="${ARGS[1]:-$DEFAULT_CPUS}"
MEM="${ARGS[2]:-$DEFAULT_MEM}"
DISK="${ARGS[3]:-$DEFAULT_DISK}"

# -------------------------------------------------
# 8. Launch VM
# -------------------------------------------------
echo "Launching VM: $VM_NAME"
echo "  Ubuntu: $UBUNTU_VERSION"
echo "  Config: $CLOUD_INIT_FILE"
echo "  Resources: $CPUS CPU, $MEM RAM, $DISK disk"
[[ -n "$MOUNT_SPEC" ]] && echo "  Mount: $MOUNT_SPEC"

multipass launch "$UBUNTU_VERSION" \
  --name "$VM_NAME" \
  --cpus "$CPUS" \
  --memory "$MEM" \
  --disk "$DISK" \
  --cloud-init "$CLOUD_INIT_FILE" \
  --timeout 3600

multipass exec "$VM_NAME" -- cloud-init status --wait

# -------------------------------------------------
# 9. Optional: Mount
# -------------------------------------------------
if [[ -n "$MOUNT_SPEC" ]]; then
  IFS=':' read -r HOST_PATH VM_PATH <<< "$MOUNT_SPEC"
  [[ -d "$HOST_PATH" ]] || { echo "Error: Host path not found: $HOST_PATH"; exit 1; }

  echo "Mounting $HOST_PATH → $VM_NAME:$VM_PATH"
  multipass mount "$HOST_PATH" "$VM_NAME":"$VM_PATH"
fi

# -------------------------------------------------
# 10. Final output
# -------------------------------------------------
IP=$(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}')
echo "=================================================="
echo "VM READY: $VM_NAME"
echo "  Ubuntu: $UBUNTU_VERSION"
echo "  IP: $IP"
echo "  SSH: ssh ubuntu@$IP"
[[ -n "$MOUNT_SPEC" ]] && echo "  Mounted: $MOUNT_SPEC"
echo "  Cloud-init: $CLOUD_INIT_FILE"
echo "=================================================="