#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: show-sbom.sh [--packages] [--platform <platform>] <image>

Print the SPDX SBOM attested to a published image.

Options:
  --packages          Print package name, version, and supplier as tab-separated values
  --platform <value>  Platform to print (default: linux/amd64)
  -h, --help          Show this help and exit
USAGE
  exit 1
}

die() {
  echo "[show-sbom] $*" >&2
  exit 1
}

IMAGE_REF=""
PLATFORM="linux/amd64"
PACKAGES_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages)
      PACKAGES_ONLY=true
      shift
      ;;
    --platform)
      [[ $# -ge 2 ]] || die "--platform requires a value"
      PLATFORM="$2"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option '$1'"
      ;;
    *)
      if [[ -n "${IMAGE_REF}" ]]; then
        die "Unexpected extra argument '$1'"
      fi
      IMAGE_REF="$1"
      shift
      ;;
  esac
done

[[ -n "${IMAGE_REF}" ]] || usage
command -v docker >/dev/null 2>&1 || die "docker is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v cosign >/dev/null 2>&1 || die "cosign is required"

IMAGE_REPOSITORY="${IMAGE_REF%@sha256:*}"
if [[ "${IMAGE_REF}" != *@sha256:* ]]; then
  image_last_path="${IMAGE_REF##*/}"
  if [[ "${image_last_path}" == *:* ]]; then
    IMAGE_REPOSITORY="${IMAGE_REF%:*}"
  fi
fi

IMAGE_MANIFEST="$(docker buildx imagetools inspect "${IMAGE_REF}" --raw)"
IMAGE_MEDIA_TYPE="$(jq -r '.mediaType // ""' <<<"${IMAGE_MANIFEST}")"

case "${IMAGE_MEDIA_TYPE}" in
  application/vnd.oci.image.index.v1+json | application/vnd.docker.distribution.manifest.list.v2+json)
    IMAGE_DIGEST="$(
      jq -r --arg platform "${PLATFORM}" '
        .manifests[]
        | select(.platform.os + "/" + .platform.architecture == $platform)
        | select(.annotations["vnd.docker.reference.type"] != "attestation-manifest")
        | .digest
      ' <<<"${IMAGE_MANIFEST}" |
        head -n 1
    )"
    ;;
  application/vnd.oci.image.manifest.v1+json | application/vnd.docker.distribution.manifest.v2+json)
    IMAGE_DIGEST="$(
      docker buildx imagetools inspect "${IMAGE_REF}" |
        awk '$1 == "Digest:" { print $2; exit }'
    )"
    ;;
  *)
    die "Unsupported image media type '${IMAGE_MEDIA_TYPE}' for '${IMAGE_REF}'"
    ;;
esac

[[ -n "${IMAGE_DIGEST}" ]] || die "No image found for platform '${PLATFORM}' in '${IMAGE_REF}'"

SPDX_SBOM="$(
  cosign download attestation "${IMAGE_REPOSITORY}@${IMAGE_DIGEST}" |
    jq -se '
      [
        .[]
        | .dsseEnvelope.payload
        | @base64d
        | fromjson
        | select(.predicateType == "https://spdx.dev/Document")
        | .predicate
      ]
      | if length == 0 then error("No SPDX SBOM attestation found") else .[0] end
    '
)" || die "No SPDX SBOM attestation found for '${IMAGE_REF}' on platform '${PLATFORM}'"

if [[ "${PACKAGES_ONLY}" == true ]]; then
  printf 'NAME\tVERSION\tSUPPLIER\n'
  printf '%s\n' "${SPDX_SBOM}" |
    jq -r '.packages[] | [.name, .versionInfo, (.supplier // "")] | @tsv'
else
  printf '%s\n' "${SPDX_SBOM}"
fi
