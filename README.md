# CICDagent_maryam
## CI and review controls

- `tests`: review-guidance and `.gemini/config.yaml` validation.
- `zizmor` and `trufflehog`: independent scanners (workflow audit, secret scan; TruffleHog is pinned by action SHA and `version`).
- `security`: aggregate check that fails unless both scanners succeed (failure, error, cancel or skip all fail it).
- Required checks on `main`: `tests` and `security`, enforced for admins.
- `Scanner self-test` (manual, `workflow_dispatch`): proves both scanners fail on a known-bad fixture and on a scanner error. Fixtures are generated at runtime; the synthetic token was never issued.

## AI review behavior

Tested on disposable PR #10 (https://github.com/maryambueck-web/CICDagent_maryam/pull/10, closed unmerged): both reviewers reviewed the first commit; after a second push only Copilot reviewed again.

- **Gemini** reviews new PRs automatically. It does not re-review pushes; comment `/gemini review` to request a fresh Gemini review manually.
- **Copilot** reviews new PRs and every subsequent push automatically, through the repository ruleset "Copilot review on every push". The ruleset excludes draft PRs.
- **AI feedback is advisory.** Neither reviewer is a required check.
- **Merge eligibility** is controlled by the required `tests` and `security` checks.

## Known gaps

- **Gemini re-review on push:** not automatic. A workflow commenting `/gemini review` was tried and Gemini ignored comments posted by `github-actions[bot]`, so it was not adopted.
- **Human approval:** not yet configured. There are no required PR reviews or CODEOWNERS; merging needs only green checks.
- **Production deployment gates:** not yet configured. No deployment workflow, environments, or approval gates exist. Add protected environments with required reviewers before deploying.
- **Scanner limits:** zizmor runs with `online-audits: false`; the TruffleHog container image tag is not digest-pinned.
