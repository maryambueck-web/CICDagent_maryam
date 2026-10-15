# CICDagent_maryam
## CI and review controls

- `tests`: review-guidance and `.gemini/config.yaml` validation.
- `zizmor` and `trufflehog`: independent scanners (workflow audit, secret scan; TruffleHog is pinned by action SHA and `version`).
- `security`: aggregate check that fails unless both scanners succeed (failure, error, cancel or skip all fail it).
- Required checks on `main`: `tests`, `security` and `app-tests`, enforced for admins.
- `Scanner self-test` (manual, `workflow_dispatch`): proves both scanners fail on a known-bad fixture and on a scanner error. Fixtures are generated at runtime; the synthetic token was never issued.

## AI review behavior

Tested on disposable PR #10 (PR #10, closed unmerged): both reviewers reviewed the first commit; after a second push only Copilot reviewed again.

- **Gemini** reviews new PRs automatically. It does not re-review pushes; comment `/gemini review` to request a fresh Gemini review manually.
- **Copilot** reviews new PRs and every subsequent push automatically, through the repository ruleset "Copilot review on every push". The ruleset excludes draft PRs.
- **AI feedback is advisory.** Neither reviewer is a required check.
- **Merge eligibility** is controlled by the required `tests`, `security` and `app-tests` checks.

## Known gaps and limitations

- **Gemini re-review on push:** not automatic. Gemini reviews PR creation; Copilot handles automatic re-review of pushes. A workflow commenting `/gemini review` was tried and Gemini ignored comments posted by `github-actions[bot]`, so it was not adopted. Use the manual `/gemini review` comment.
- **Human approval of PRs:** not configured. There are no required PR reviews or CODEOWNERS; merging needs only green checks.
- **Approver separation:** the deployer service account cannot approve builds (enforced and tested, see evidence). In this one-person demo the human approver is still the project owner, so two-person separation is not enforced. For a company, grant `roles/cloudbuild.builds.approver` to a dedicated group such as `release-approvers@<company-domain>` and keep the approvers distinct from the people who merge.
- **Candidate cleanup and scanning:** after a failed candidate the zero-traffic `candidate`-tagged revision remains until the next deploy moves the tag. Container-image vulnerability scanning (for example Artifact Registry scanning) is not enabled; application scanning is `npm audit` (high or critical fails) plus the existing zizmor and TruffleHog scanners.
- **Scanner limits:** zizmor runs with `online-audits: false`; the TruffleHog container image tag is not digest-pinned.

## Production deployment (demo pilot)

Status: a **functioning demo pilot**. It deploys a sample app to a separate demo Cloud Run service, not to production.

- **GitHub side stays disabled:** `.github/workflows/deploy.yml` is manual-only and guarded by the repo variable `DEPLOY_ENABLED` (unset). No GitHub-side GCP credentials exist.
- **Adapting it:** all names are Cloud Build substitutions in `cloudbuild.yaml` (`_REGION`, `_SERVICE`, `_DEPLOYER`, `_IMAGE`, `_READY_PATH`); override them on the trigger. The GitHub deploy workflow reads `GCP_CLOUD_RUN_SERVICE`, `GCP_REGION`, `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_DEPLOY_SERVICE_ACCOUNT` from repo variables and stays disabled until `DEPLOY_ENABLED` is `true`.
- **Why Cloud Build approval:** GitHub's `production` environment cannot require reviewers on this private free-plan repo (the API rejects it).
- **Pipeline (`cloudbuild.yaml`):** private GitHub connection (Developer Connect) -> approval-required trigger on `main` -> app tests -> `npm audit` -> container build -> Artifact Registry (tagged with the commit SHA) -> Cloud Run **candidate** revision (`--no-traffic`, tagged `candidate`, private) -> authenticated check of the candidate's tagged URL (`/ready` returns 200 with exactly `{"status":"ok"}`, and `/` reports a version equal to the commit SHA) -> promote to 100% only if that passes -> same check on the live service. `scripts/check-ready.sh` is the shared check and is itself tested.
- **Identities:** a dedicated deployer service account (for example `cicd-deployer`; log writer, Artifact Registry writer on one repo, `run.developer` and `run.invoker` on the demo service, `serviceAccountUser` on the runtime account) and a runtime service account with no roles.

Evidence from the demo run (build IDs, commits, revisions and the project it ran in) is recorded in [docs/demo-evidence.md](docs/demo-evidence.md). Summary: a rejected build never started; an approved build deployed a no-traffic candidate, verified it, then promoted it; a failing candidate was not promoted; and the deployer identity could not approve builds.

Application-specific tests (`app/server.test.js`) cover the `/ready` contract, query-string handling, the version reported, Dockerfile policy (non-root, pinned base major, no `:latest`), no unexpected runtime dependencies, and the readiness script's pass and fail paths.

**Where the tests run:** the readiness-script test needs `curl`. The slim Node image used by the Cloud Build `test` step has no `curl`, so that one test is skipped there (7 of 8 tests run). It does run in the required GitHub `app-tests` check, where `curl` is available, so a regression in the script still blocks the merge. Cloud Build's `test` step is a second gate on the deployed commit, not the only one.

Before company rollout: use a real approver group and a second person, restrict who can edit triggers and IAM, replace these sample tests with tests tailored to each application, and enable container-image scanning.
