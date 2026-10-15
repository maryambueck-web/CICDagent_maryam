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

## Known gaps and limitations

- **Gemini re-review on push:** not automatic. Gemini reviews PR creation; Copilot handles automatic re-review of pushes. A workflow commenting `/gemini review` was tried and Gemini ignored comments posted by `github-actions[bot]`, so it was not adopted. Use the manual `/gemini review` comment.
- **Human approval of PRs:** not configured. There are no required PR reviews or CODEOWNERS; merging needs only green checks.
- **Deployment approver separation:** approval uses one account; two-person separation is not enforced. Approver IAM (`roles/cloudbuild.builds.approver` for approvers only) is not configured.
- **Health verification happens after traffic switches:** the `/ready` check runs after `gcloud run deploy` has routed 100% of traffic to the new revision. Testing a candidate revision (`--no-traffic` plus a tagged URL) and promoting only on success is a planned improvement.
- **Scanner limits:** zizmor runs with `online-audits: false`; the TruffleHog container image tag is not digest-pinned.

## Production deployment (demo pilot)

Status: a **functioning demo pilot**. It deploys a sample app to a separate demo Cloud Run service, not to production.

- **GitHub side stays disabled:** `.github/workflows/deploy.yml` is manual-only and guarded by the repo variable `DEPLOY_ENABLED` (unset). No GitHub-side GCP credentials exist.
- **Why Cloud Build approval:** GitHub's `production` environment cannot require reviewers on this private free-plan repo (the API rejects it).
- **Pipeline (`cloudbuild.yaml`):** private GitHub connection (Developer Connect) -> approval-required trigger on `main` -> app tests -> container build -> Artifact Registry (tagged with the commit SHA) -> Cloud Run (private, no unauthenticated access) -> authenticated `/ready` check requiring HTTP 200, the exact body `{"status":"ok"}` and the deployed commit SHA.
- **Identities:** a dedicated deployer service account (log writer, Artifact Registry writer on one repo, `run.developer` and `run.invoker` on the demo service, `serviceAccountUser` on the runtime account) and a runtime service account with no roles.

Evidence (project `project-cd16ff87-2947-4d1f-985`, us-east1):

- **Rejection:** build `b81e5c74-70b7-403c-9340-379ef6b8da71` on `383e340` stayed `PENDING`, was rejected, ended `CANCELLED` and never started. Nothing was pushed or deployed; the service stayed on revision `00001`.
- **Approval:** build `12d61fe7-1ea6-4350-8e5d-d061b9dad980` on merge commit `d8814bec1f9bdedba48b13e0db64980bfeb1efc2` (PR #14) was `PENDING` with no step started, then approved. Tests, build, push, deploy and the `/ready` check all succeeded. Revision `cicdagent-sample-demo-00004-vr9` is Ready with 100% of traffic on image tag `d8814bec...`.
- **Earlier finding:** the first health check used `/healthz`, which Cloud Run's front end answers with its own 404 before the app sees it, so `/ready` is used instead (PR #14).

Before company rollout: restrict approver and deployer permissions (approver role only for approvers, a second person for approval) and add tests tailored to each application.
