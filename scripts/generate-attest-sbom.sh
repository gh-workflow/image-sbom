#!/usr/bin/env bash
set -euo pipefail

signing_config="${RUNNER_TEMP}/cosign-signing-config.json"
cosign signing-config create \
  --with-default-services \
  --no-default-rekor \
  --out "${signing_config}"

cosign_args=(
  attest
  --yes
  --type "${PREDICATE_TYPE}"
  --signing-config "${signing_config}"
)

if [[ -n "${REGISTRY_USERNAME}" || -n "${REGISTRY_PASSWORD}" ]]; then
  if [[ -z "${REGISTRY_USERNAME}" || -z "${REGISTRY_PASSWORD}" ]]; then
    echo "::error::registry-username and registry-password must be provided together."
    exit 1
  fi

  cosign_args+=(
    --registry-username "${REGISTRY_USERNAME}"
    --registry-password "${REGISTRY_PASSWORD}"
  )
fi

while IFS= read -r image; do
  [[ -n "${image}" ]] || continue
  image_digest="${image##*@}"
  sbom_file="${SBOM_DIR}/${image_digest#sha256:}.${SBOM_EXT}"

  image_repo="${image%@sha256:*}"
  image_registry="${image_repo%%/*}"
  if [[ "${image_registry}" != *.* && "${image_registry}" != *:* && "${image_registry}" != "localhost" ]]; then
    image_registry="docker.io"
  fi

  if [[ -n "${REGISTRY_USERNAME}" ]]; then
    export SYFT_REGISTRY_AUTH_AUTHORITY="${image_registry}"
    export SYFT_REGISTRY_AUTH_USERNAME="${REGISTRY_USERNAME}"
    export SYFT_REGISTRY_AUTH_PASSWORD="${REGISTRY_PASSWORD}"
  fi

  "${SYFT_CMD}" scan "registry:${image}" -o "${FORMAT}" >"${sbom_file}"
  cosign "${cosign_args[@]}" --predicate "${sbom_file}" "${image}"
done <"${RESOLVED_IMAGES_FILE}"
