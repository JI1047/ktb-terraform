#!/usr/bin/env bash
set -euo pipefail

# Destroy Terraform stacks in reverse dependency order.
# Usage:
#   ./scripts/destroy-all.sh plan
#   ./scripts/destroy-all.sh apply
#   ./scripts/destroy-all.sh apply --auto-approve

MODE="${1:-plan}"
shift || true
EXTRA_ARGS=("$@")

STACKS=(
  "infra/cdn"
  "infra/compute"
  "infra/security"
  "infra/network"
)

if ! command -v terraform >/dev/null 2>&1; then
  echo "[ERROR] terraform is not installed."
  exit 1
fi

if [[ "$MODE" != "plan" && "$MODE" != "apply" ]]; then
  echo "[ERROR] MODE must be one of: plan, apply"
  exit 1
fi

run_stack() {
  local stack="$1"
  if [[ ! -d "$stack" ]]; then
    echo "[SKIP] $stack (directory not found)"
    return 0
  fi

  echo ""
  echo "=== $stack ==="

  terraform -chdir="$stack" init -input=false >/dev/null

  if [[ "$MODE" == "plan" ]]; then
    terraform -chdir="$stack" plan -destroy -input=false "${EXTRA_ARGS[@]}"
  else
    terraform -chdir="$stack" destroy -input=false "${EXTRA_ARGS[@]}"
  fi
}

for s in "${STACKS[@]}"; do
  run_stack "$s"
done

echo ""
echo "Done: $MODE completed for all stacks in reverse order."
