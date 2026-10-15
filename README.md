# CICDagent_maryam
## CI and review controls

- `tests`: review-guidance and `.gemini/config.yaml` validation.
- `zizmor` and `trufflehog`: independent scanners (workflow audit, secret scan; TruffleHog is pinned by action SHA and `version`).
- `security`: aggregate check that fails unless both scanners succeed (failure, error, cancel or skip all fail it).
- Required checks on `main`: `tests` and `security`, enforced for admins.
- `Scanner self-test` (manual, `workflow_dispatch`): proves both scanners fail on a known-bad fixture and on a scanner error. Fixtures are generated at runtime; the synthetic token was never issued.

## Known gaps

- **AI re-review:** Gemini reviews a PR when it is opened. Pushes to an open PR do not trigger a new review; comment `/gemini review`.
  Gemini feedback is advisory and not a required check.
- **Human approval:** no required PR reviews or CODEOWNERS yet. Merging needs only green checks.
- **Production deployment:** no deployment workflow, environments, or approval gates exist. Add protected environments with required reviewers before deploying.
- **Scanner limits:** zizmor runs with `online-audits: false`; the TruffleHog container image tag is not digest-pinned.
