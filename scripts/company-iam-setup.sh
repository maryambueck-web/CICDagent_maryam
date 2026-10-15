#!/usr/bin/env bash
# Company deployment pilot: owner-run IAM setup, in separate stages so each can be reviewed and run on its own.
# Needs rights to administer IAM and Cloud Run in the project. Idempotent. Nothing here grants approval to the deployer.
#
#   scripts/company-iam-setup.sh bootstrap          # create the private staging service (needs run.admin + actAs on the runtime SA)
#   scripts/company-iam-setup.sh grants             # deployer roles, scoped to repo/service/SA where supported
#   APPROVERS="group:release-approvers@example.com" scripts/company-iam-setup.sh approvers
#   CONNECTION=<name> scripts/company-iam-setup.sh connection-token   # only after the repo connection method is confirmed
#
# Variables: PROJECT (cicdagent), REGION (europe-west1), SERVICE (cicdagent-sample-staging), REPO (cicdagent-images).
# The runtime service account intentionally gets NO project roles: the sample app calls no Google Cloud APIs.
set -euo pipefail

PROJECT="${PROJECT:-cicdagent}"
REGION="${REGION:-europe-west1}"
SERVICE="${SERVICE:-cicdagent-sample-staging}"
REPO="${REPO:-cicdagent-images}"
DEPLOYER="cicd-deployer@${PROJECT}.iam.gserviceaccount.com"
RUNTIME="cicd-runtime@${PROJECT}.iam.gserviceaccount.com"
stage="${1:?usage: $0 bootstrap|grants|approvers|connection-token}"

case "$stage" in
  bootstrap)
    # The deployer's roles are scoped to this service, so the service must exist before they are granted.
    if gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" >/dev/null 2>&1; then
      echo "service $SERVICE already exists"
    else
      gcloud run deploy "$SERVICE" --project "$PROJECT" --region "$REGION" \
        --image=us-docker.pkg.dev/cloudrun/container/hello \
        --service-account="$RUNTIME" --no-allow-unauthenticated --max-instances=1 --quiet
    fi
    ;;

  grants)
    gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" >/dev/null \
      || { echo "run '$0 bootstrap' first" >&2; exit 1; }
    gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$DEPLOYER" \
      --role=roles/logging.logWriter --condition=None --quiet >/dev/null
    gcloud artifacts repositories add-iam-policy-binding "$REPO" --location "$REGION" --project "$PROJECT" \
      --member="serviceAccount:$DEPLOYER" --role=roles/artifactregistry.writer --quiet >/dev/null
    for role in roles/run.developer roles/run.invoker; do
      gcloud run services add-iam-policy-binding "$SERVICE" --region "$REGION" --project "$PROJECT" \
        --member="serviceAccount:$DEPLOYER" --role="$role" --quiet >/dev/null
    done
    gcloud iam service-accounts add-iam-policy-binding "$RUNTIME" --project "$PROJECT" \
      --member="serviceAccount:$DEPLOYER" --role=roles/iam.serviceAccountUser --quiet >/dev/null
    # The health check mints its own ID token by impersonating the deployer.
    gcloud iam service-accounts add-iam-policy-binding "$DEPLOYER" --project "$PROJECT" \
      --member="serviceAccount:$DEPLOYER" --role=roles/iam.serviceAccountTokenCreator --quiet >/dev/null
    echo "deployer grants applied; runtime account has no project roles"
    ;;

  approvers)
    : "${APPROVERS:?set APPROVERS to a space-separated list of human members or a group}"
    for m in $APPROVERS; do
      case "$m" in
        *"$DEPLOYER"*|*"$RUNTIME"*|serviceAccount:*) echo "refusing service account approver: $m" >&2; exit 1;;
      esac
      gcloud projects add-iam-policy-binding "$PROJECT" --member="$m" \
        --role=roles/cloudbuild.builds.approver --condition=None --quiet >/dev/null
    done
    echo "approver role granted; deployer and runtime hold no approver role"
    ;;

  connection-token)
    # Deliberately not part of 'grants'. Developer Connect connections expose no resource-level IAM here
    # (getIamPolicy returned 404 when tested), so this binding is project-wide unless limited by a condition.
    # Confirm the connection method first; the binding is limited to the named connection by resource name.
    : "${CONNECTION:?set CONNECTION to the Developer Connect connection id}"
    gcloud developer-connect connections describe "$CONNECTION" --location "$REGION" --project "$PROJECT" >/dev/null \
      || { echo "connection $CONNECTION not found in $REGION" >&2; exit 1; }
    gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$DEPLOYER" \
      --role=roles/developerconnect.readTokenAccessor \
      --condition="title=only-$CONNECTION,expression=resource.name.startsWith('projects/${PROJECT}/locations/${REGION}/connections/${CONNECTION}')" \
      --quiet >/dev/null
    echo "readTokenAccessor granted with a resource-name condition. Verify with a real trigger run; if the condition blocks access, ask the owner whether to use an unconditioned project grant instead."
    ;;

  *) echo "unknown stage: $stage" >&2; exit 1;;
esac
