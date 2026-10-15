# CICDagent_maryam
## CI and review controls

- `tests`: review-guidance and `.gemini/config.yaml` validation.
- `zizmor` and `trufflehog`: independent scanners (workflow audit, secret scan; TruffleHog is pinned by action SHA and `version`).
- `security`: aggregate check that fails unless both scanners succeed (failure, error, cancel or skip all fail it).
- Required checks on `main`: `tests`, `security` and `app-tests`, enforced for admins.
- `Scanner self-test` (manual, `workflow_dispatch`): proves both scanners fail on a known-bad fixture and on a scanner error. Fixtures are generated at runtime; the synthetic token was never issued.

## AI review behavior

Tested on disposable PR #10 (https://github.com/maryambueck-web/CICDagent_maryam/pull/10, closed unmerged): both reviewers reviewed the first commit; after a second push only Copilot reviewed again.

- **Gemini** reviews new PRs automatically. It does not re-review pushes; comment `/gemini review` to request a fresh Gemini review manually.
- **Copilot** reviews new PRs and every subsequent push automatically, through the repository ruleset "Copilot review on every push". The ruleset excludes draft PRs.
- **AI feedback is advisory.** Neither reviewer is a required check.
- **Merge eligibility** is controlled by the required `tests`, `security` and `app-tests` checks.

## Known gaps

- **Gemini re-review on push:** not automatic. A workflow commenting `/gemini review` was tried and Gemini ignored comments posted by `github-actions[bot]`, so it was not adopted.
- **Human approval:** not yet configured. There are no required PR reviews or CODEOWNERS; merging needs only green checks.
- **Production deployment gates:** not yet configured. See "Production deployment (disabled)" below.
- **Scanner limits:** zizmor runs with `online-audits: false`; the TruffleHog container image tag is not digest-pinned.

## Production deployment (disabled)

- `.github/workflows/deploy.yml` is manual-only and its deploy job is guarded by the repo variable `DEPLOY_ENABLED` (unset, so it never runs). No GCP deployment credentials (Workload Identity pool, deploy service account) are provisioned.
- GitHub's `production` environment cannot require reviewers on this private free-plan repo (the API rejects it), so human approval is planned through **Cloud Build approval** (or an eligible GitHub Enterprise/organization setup).
- Verified on 2026-10-15 in the GCP project with a throwaway no-op manual trigger (`--require-approval`) running as a service account with no IAM roles. Before approval the build stayed `PENDING` with no start time and its step never ran. A rejected build ended `CANCELLED` and never started. After approval (REST `builds:approve`; this gcloud version has no `builds approve` command) the build started and succeeded. The trigger and service account were deleted afterwards.
- Not yet done: a real deploy trigger, approver IAM (`roles/cloudbuild.builds.approver` for approvers only), and a non-self-approval policy (the test used a single account).
