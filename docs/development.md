# Development

## Repository rulesets

Import the rulesets in [`.github/rulesets/`](../.github/rulesets/) into the
GitHub repository before using this project for development.

## Linting

Changes must satisfy both linters.

<!-- markdownlint-disable MD013 -->
| Workflow                              | When it runs                                                     | What to do                                                      |
|---------------------------------------|------------------------------------------------------------------|-----------------------------------------------------------------|
| **CI: lint (super-linter)**           | Automatically for pull requests, pushes to `main`, and releases. | Nothing: fix any reported issues in your branch.                |
| **CI: lint (self-hosted megalinter)** | Manually.                                                        | Run it before merging changes that may need its broader checks. |
<!-- markdownlint-enable MD013 -->

### Run MegaLinter

1. Go to **Actions** → **CI: lint (self-hosted megalinter)** → **Run
   workflow**.
2. Select the branch to check.
3. Select the runner:
   - `self-hosted` when an appropriate runner is available. Its cached
     MegaLinter image makes later runs take about one to two minutes.
   - `ubuntu-latest` otherwise. It downloads the large image for each run.
4. Select `fix_mode`:
   - `pull_request` (default) creates or updates a `lint-autofix/<branch>` PR
     with MegaLinter's automatic fixes.
   - `none` reports issues without creating a fix PR.

The run uploads its reports as the **MegaLinter reports** artifact.

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
