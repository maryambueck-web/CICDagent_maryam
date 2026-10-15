#!/usr/bin/env bash
# One-time setup for the company deployment pilot. Run by a project owner (needs IAM admin rights).
# Idempotent. Review before running; it changes IAM in the project below.
# Usage: PROJECT=cicdagent REGION=europe-west1 APPROVERS="group:release-approvers@example.com" ./company-iam-setup.sh
set -euo pipefail

PROJECT="${PROJECT:-cicdagent}"
REGION="${REGION:-europe-west1}"
SERVICE="${SERVICE:-cicdagent-sample-staging}"
REPO="${REPO:-cicdagent-images}"
DEPLOYER="cicd-deployer@${PROJECT}.iam.gserviceaccount.com"
RUNTIME="cicd-runtime@${PROJECT}.iam.gserviceaccount.com"
: "${APPROVERS:?set APPROVERS to a space-separated list of members, e.g. group:release-approvers@example.com}"

case "$APPROVERS" in
  *"$DEPLOYER"*|*"$RUNTIME"*) echo "approvers must not include the deployer or runtime identity" >&2; exit 1;;
esac

# Private staging service must exist so the deployer only needs service-scoped Cloud Run roles.
if ! gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" >/dev/null 2>&1; then
  gcloud run deploy "$SERVICE" --project "$PROJECT" --region "$REGION" \
    --image=us-docker.pkg.dev/cloudrun/container/hello \
    --service-account="$RUNTIME" --no-allow-unauthenticated --max-instances=1 --quiet
fi

# Deployer: only what the pipeline needs.
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$DEPLOYER" \
  --role=roles/logging.logWriter --condition=None --quiet >/dev/null
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$DEPLOYER" \
  --role=roles/developerconnect.readTokenAccessor --condition=None --quiet >/dev/null
gcloud artifacts repositories add-iam-policy-binding "$REPO" --location "$REGION" --project "$PROJECT" \
  --member="serviceAccount:$DEPLOYER" --role=roles/artifactregistry.writer --quiet >/dev/null
for role in roles/run.developer roles/run.invoker; do
  gcloud run services add-iam-policy-binding "$SERVICE" --region "$REGION" --project "$PROJECT" \
    --member="serviceAccount:$DEPLOYER" --role="$role" --quiet >/dev/null
done
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME" --project "$PROJECT" \
  --member="serviceAccount:$DEPLOYER" --role=roles/iam.serviceAccountUser --quiet >/dev/null
# The health check mints an ID token by impersonating the deployer itself.
gcloud iam service-accounts add-iam-policy-binding "$DEPLOYER" --project "$PROJECT" \
  --member="serviceAccount:$DEPLOYER" --role=roles/iam.serviceAccountTokenCreator --quiet >/dev/null

# Approvers: may approve or reject builds, nothing else here. Deployer and runtime get no approver role.
for m in $APPROVERS; do
  gcloud projects add-iam-policy-binding "$PROJECT" --member="$m" \
    --role=roles/cloudbuild.builds.approver --condition=None --quiet >/dev/null
done

echo "Done. Runtime service account keeps no project roles."
