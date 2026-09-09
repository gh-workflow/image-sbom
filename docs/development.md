# Development

## Repository rulesets

Import the rulesets in [`.github/rulesets/`](../.github/rulesets/) into the
GitHub repository before using this project for development.

## Linting

Keep changes compliant with both linters.

[Super-Linter](https://github.com/super-linter/super-linter) provides the
project's fast, reasonably strict baseline checks. It runs automatically for
pull requests and pushes, including the release workflow.

[MegaLinter](https://github.com/oxsecurity/megalinter) provides broader, more
strict checks and is run on demand through **CI: lint (self-hosted
megalinter)**. Prefer the `self-hosted` runner option after starting a
self-hosted runner: its cached MegaLinter image avoids downloading the large
image again on each run. The first run downloads the image; subsequent runs
normally take about one to two minutes.

## Dependency updates and releases

The repository automatically maintains its GitHub Actions dependencies:

```text
Dependabot PR → PR tests → merge-commit auto-merge → version tag → CI: Release → GitHub release
```

- **Dependabot** checks GitHub Actions dependencies periodically and groups
  updates into one pull request.
- **PR tests** run the normal lint and live-test workflows.
- **CI: Dependabot auto merge** verifies the Dependabot author and enables
  merge-commit auto-merge. GitHub merges after the ruleset requirements pass.
- **CI: Dependabot release trigger** runs after that merge, creates the next
  patch tag, and starts **CI: Release** for the tag.
- **CI: Release** validates the tag, runs lint and live tests again, moves the
  major tag (for example, `v1`), and publishes the GitHub release.

The release trigger ignores pushes not associated with a merged Dependabot pull
request.

### Required repository settings

- Enable **Allow auto-merge** under **Settings** > **General** > **Pull
  Requests**. Merge commits must also be enabled.
- Under **Settings** > **Actions** > **General** > **Workflow permissions**,
  enable **Allow GitHub Actions to create and approve pull requests**. This is
  required for MegaLinter to open pull requests containing automatic fixes.
