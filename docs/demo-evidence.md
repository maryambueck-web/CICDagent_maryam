# Demo evidence (personal pilot project)

Recorded from the personal demo setup. These identifiers belong to that project and are not defaults for another environment.

Evidence (project `project-cd16ff87-2947-4d1f-985`, us-east1):

- **Rejection:** build `b81e5c74-70b7-403c-9340-379ef6b8da71` on `383e340` stayed `PENDING`, was rejected, ended `CANCELLED` and never started. Nothing was pushed or deployed; the service stayed on revision `00001`.
- **Approval (candidate flow):** build `7f68ed87-37ac-4afd-8357-89f4a00aeb16` on `14dcaf94419a06caf106d6c5aed2bbc27bf8454f` was `PENDING` with no step started, then approved. All eight steps succeeded: the candidate passed its check at `https://candidate---cicdagent-sample-demo-wbt3lytofq-ue.a.run.app`, then revision `cicdagent-sample-demo-00006-qak` was promoted to 100% and passed the live check.
- **Failed candidate is not promoted:** build `fb9aead8-3532-45b9-9d80-8ee07ea95957` (same commit, ready path overridden to a nonexistent path through a trigger substitution, no code change) was approved. The candidate revision `00005-fir` was created with 0% traffic, `verify-candidate` failed, `promote` never ran, and live traffic stayed 100% on `00004-vr9`.
- **Deployer cannot approve:** during pending build `55004aec-b49e-4677-8ce6-bb4afd2800f1`, an approval attempt as `cicd-deployer` returned `403 PERMISSION_DENIED` and the build stayed `PENDING`. That build then failed closed at the `test` step (a slim-image `curl` gap, fixed in #16) before anything was deployed.
- **Earlier run:** build `12d61fe7-1ea6-4350-8e5d-d061b9dad980` (PR #14) used the earlier direct deploy with a post-switch check.
- **Earlier finding:** the first health check used `/healthz`, which Cloud Run's front end answers with its own 404 before the app sees it, so `/ready` is used instead (PR #14).