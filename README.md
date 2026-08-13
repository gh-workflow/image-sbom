# Image SBOM attestation

Generate an SBOM for a container image and attach it to the image as a Cosign
attestation.

This action is useful when `docker/build-push-action` BuildKit SBOM generation
hits the attestation size limit, for example:

```text
sbom.spdx.json exceeds 41943040 bytes
```

Instead of using `sbom: true` on the Docker build step, push the image first and
run this action against the immutable digest reference.

## Usage

Set these permissions on the job or workflow:

```yaml
permissions:
  id-token: write
  packages: write
```

Run this after the image has been pushed:

```yaml
- name: Build and push
  id: build
  uses: docker/build-push-action@v7
  with:
    context: .
    push: true
    sbom: false
    tags: ghcr.io/${{ github.repository }}:latest

- name: Generate and attest SBOM
  uses: gh-workflow/image-sbom@v1
  with:
    image: ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `image` | Yes | | Image reference to scan and attest. Prefer an immutable digest reference. |
| `registry-username` | No | | Registry username used by Syft and Cosign for image registry access. |
| `registry-password` | No | | Registry password or token used by Syft and Cosign for image registry access. |
| `format` | No | `spdx-json` | SBOM format to generate. Supported values are `spdx-json` and `cyclonedx-json`. |

If either `registry-username` or `registry-password` is provided, both must be
provided. For GHCR images, use `${{ github.actor }}` and
`${{ secrets.GITHUB_TOKEN }}`. Do not embed credentials in the `image` reference.

The selected `format` controls the Cosign predicate type automatically:

| Format | Cosign predicate type |
| --- | --- |
| `spdx-json` | `spdxjson` |
| `cyclonedx-json` | `cyclonedx` |

## Permissions

The calling workflow needs `id-token: write` for Cosign keyless signing. For
GHCR images, it also needs `packages: write` so Cosign can push the attestation.

## Outputs

| Name | Description |
| --- | --- |
| `sbom-file` | Path to the generated SBOM file on the runner. |

## Image references

The image must already be available to Syft and Cosign. A digest reference is
recommended so the SBOM is attached to the exact image that was built.

## License

MIT
