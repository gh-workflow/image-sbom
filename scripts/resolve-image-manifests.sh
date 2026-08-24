#!/usr/bin/env bash
set -euo pipefail

image_repo="${IMAGE}"
if [[ "${image_repo}" == *@sha256:* ]]; then
  image_repo="${image_repo%@sha256:*}"
else
  last_path="${image_repo##*/}"
  if [[ "${last_path}" == *:* ]]; then
    image_repo="${image_repo%:*}"
  fi
fi

image_registry="${image_repo%%/*}"
local_registry="localhost" # DevSkim: ignore DS162092
if [[ "${image_registry}" != *.* && "${image_registry}" != *:* && "${image_registry}" != "${local_registry}" ]]; then
  image_registry="docker.io"
fi

if [[ -n "${REGISTRY_USERNAME}" || -n "${REGISTRY_PASSWORD}" ]]; then
  if [[ -z "${REGISTRY_USERNAME}" || -z "${REGISTRY_PASSWORD}" ]]; then
    echo "::error::registry-username and registry-password must be provided together."
    exit 1
  fi

  docker login "${image_registry}" \
    --username "${REGISTRY_USERNAME}" \
    --password-stdin <<<"${REGISTRY_PASSWORD}"
fi

inspect_json="$(docker buildx imagetools inspect --raw "${IMAGE}")"
media_type="$(jq -r '.mediaType // ""' <<<"${inspect_json}")"

case "${media_type}" in
  application/vnd.oci.image.index.v1+json | application/vnd.docker.distribution.manifest.list.v2+json)
    mapfile -t resolved_images < <(
      jq -r --arg image_repo "${image_repo}" '
        .manifests[]
        | select(.platform.os != null and .platform.architecture != null)
        | select(.platform.os != "unknown" and .platform.architecture != "unknown")
        | select(.annotations["vnd.docker.reference.type"] != "attestation-manifest")
        | "\($image_repo)@\(.digest)"
      ' <<<"${inspect_json}"
    )
    ;;
  application/vnd.oci.image.manifest.v1+json | application/vnd.docker.distribution.manifest.v2+json)
    digest="$(
      docker buildx imagetools inspect "${IMAGE}" |
        awk '$1 == "Digest:" { print $2; exit }'
    )"
    if [[ -z "${digest}" ]]; then
      echo "::error::Could not resolve digest for ${IMAGE}."
      exit 1
    fi
    resolved_images=("${image_repo}@${digest}")
    ;;
  *)
    echo "::error::Unsupported image media type '${media_type}' for ${IMAGE}."
    exit 1
    ;;
esac

if [[ "${#resolved_images[@]}" -eq 0 ]]; then
  echo "::error::No runnable image manifests found in ${IMAGE}."
  exit 1
fi

resolved_images_file="${SBOM_DIR}/resolved-images.txt"
printf '%s\n' "${resolved_images[@]}" >"${resolved_images_file}"
