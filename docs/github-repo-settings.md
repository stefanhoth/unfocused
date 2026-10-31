# GitHub repo settings

One-time manual steps that can't live as files in the repo.

1. **Settings → General → Pull Requests**: allow squash merging only; enable **Allow auto-merge** and **Automatically delete head branches**.
2. **Settings → Rules → Rulesets → Import a ruleset**: import `.github/rulesets/main-branch-protection.json`. Its required checks (`Lint`, `Build`, `Test`, `Conventional commit title`) must match the job names in `.github/workflows/` exactly; update both together.
3. **Renovate**: install the [Renovate GitHub app](https://github.com/apps/renovate) for this repository.
4. **Release secrets** (set): `SIGNING_CERT_P12_BASE64` (the self-signed code-signing certificate as base64 PKCS#12) and `SIGNING_CERT_PASSWORD`. The certificate lives outside the repo in `~/Library/Application Support/unfocused-dev/signing/` on the author's Mac. Keep it: a new certificate makes macOS forget the Accessibility grant once.
5. **Cask updates**: the Release workflow's last job pushes the updated cask straight to `main` with a write deploy key (personal repos can't put "GitHub Actions" on a bypass list).
   - Create the key: `ssh-keygen -t ed25519 -N "" -C "unfocused cask" -f /tmp/cask_key`
   - Add the public half as a deploy key with write access: `gh repo deploy-key add /tmp/cask_key.pub --allow-write --title "Release: cask"`
   - Store the private half as a secret: `gh secret set CASK_DEPLOY_KEY < /tmp/cask_key`, then `rm /tmp/cask_key /tmp/cask_key.pub`
   - Settings → Rules → Protect main → Bypass list → tick **Deploy keys** (mode: Always).

   Without these, the release is still published, but the cask job fails and the cask has to be updated through a normal PR (`scripts/write-cask.sh <version> <sha256> > Casks/unfocused.rb`).
