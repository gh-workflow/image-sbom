#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?}"
: "${SBOM_DIR:?}"
: "${EXPECTED_MEDIA:?}"
: "${EXPECTED_IMAGES:?}"
: "${EXPECTED_NON_RUNNABLE:?}"
: "${RUNNER_TEMP:?}"

inspect_json="$(docker buildx imagetools inspect --raw "${IMAGE}")"
media_type="$(jq -r '.mediaType // ""' <<<"${inspect_json}")"

case "${EXPECTED_MEDIA}" in
  manifest)
    case "${media_type}" in
      application/vnd.oci.image.manifest.v1+json | application/vnd.docker.distribution.manifest.v2+json)
        resolved_images=("${IMAGE}")
        ;;
      *)
        echo "Expected image manifest, got ${media_type}." >&2
        exit 1
        ;;
    esac
    ;;
  index)
    case "${media_type}" in
      application/vnd.oci.image.index.v1+json | application/vnd.docker.distribution.manifest.list.v2+json)
        image_repo="${IMAGE%@sha256:*}"
        mapfile -t resolved_images < <(
          jq -r --arg image_repo "${image_repo}" '
            .manifests[]
            | select(.platform.os != null and .platform.architecture != null)
            | select(.platform.os != "unknown" and .platform.architecture != "unknown")
            | select(.annotations["vnd.docker.reference.type"] != "attestation-manifest")
            | "\($image_repo)@\(.digest)"
          ' <<<"${inspect_json}"
        )
        non_runnable_count="$(
          jq -r '
            [
              .manifests[]
              | select(
                  .annotations["vnd.docker.reference.type"] == "attestation-manifest"
                  or .platform.os == "unknown"
                  or .platform.architecture == "unknown"
                )
            ]
            | length
          ' <<<"${inspect_json}"
        )"
        ;;
      *)
        echo "Expected image index, got ${media_type}." >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported EXPECTED_MEDIA '${EXPECTED_MEDIA}'." >&2
    exit 1
    ;;
esac

if [[ "${#resolved_images[@]}" -ne "${EXPECTED_IMAGES}" ]]; then
  echo "Expected ${EXPECTED_IMAGES} runnable image(s), got ${#resolved_images[@]}." >&2
  printf '%s\n' "${resolved_images[@]}" >&2
  exit 1
fi

if [[ "${EXPECTED_MEDIA}" == "manifest" ]]; then
  non_runnable_count=0
fi

if [[ "${non_runnable_count}" -ne "${EXPECTED_NON_RUNNABLE}" ]]; then
  echo "Expected ${EXPECTED_NON_RUNNABLE} non-runnable manifest(s), got ${non_runnable_count}." >&2
  exit 1
fi

mapfile -t sbom_files < <(find "${SBOM_DIR}" -type f -name '*.spdx.json' | sort)
if [[ "${#sbom_files[@]}" -ne "${EXPECTED_IMAGES}" ]]; then
  echo "Expected ${EXPECTED_IMAGES} SBOM file(s), got ${#sbom_files[@]}." >&2
  printf '%s\n' "${sbom_files[@]}" >&2
  exit 1
fi

for sbom_file in "${sbom_files[@]}"; do
  jq -e '.SPDXID == "SPDXRef-DOCUMENT"' "${sbom_file}" >/dev/null
done

for image in "${resolved_images[@]}"; do
  attestation_file="${RUNNER_TEMP}/attestations-${image##*@}.json"
  cosign download attestation "${image}" >"${attestation_file}"
  jq -e '
    select(
      .dsseEnvelope.payload
      | @base64d
      | fromjson
      | .predicate.SPDXID == "SPDXRef-DOCUMENT"
    )
  ' "${attestation_file}" >/dev/null
done
