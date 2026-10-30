# GitHub repo settings

One-time manual steps that can't live as files in the repo.

1. **Settings → General → Pull Requests**: allow squash merging only; enable **Allow auto-merge** and **Automatically delete head branches**.
2. **Settings → Rules → Rulesets → Import a ruleset**: import `.github/rulesets/main-branch-protection.json`. Its required checks (`Lint`, `Build`, `Test`, `Conventional commit title`) must match the job names in `.github/workflows/` exactly; update both together.
3. **Renovate**: install the [Renovate GitHub app](https://github.com/apps/renovate) for this repository.
4. **Release secrets** (added with the release pipeline): the self-signed code-signing certificate and its password, as Actions secrets.
