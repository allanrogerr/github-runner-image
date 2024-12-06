#!/bin/bash

REPOSITORY_URL=https://github.com/$(sed -E "s/^repos\/|^orgs\///g" <<< $OWNER_REPO_OR_ORG) # e.g. https://github.com/allanrogerr/minio or https://github.com/miniohq
echo OWNER_REPO_OR_ORG $OWNER_REPO_OR_ORG
echo REPOSITORY_URL $REPOSITORY_URL
echo GH_TOKEN $GH_TOKEN
echo GH_RUNNER_USER $GH_RUNNER_USER
echo GH_RUNNER_OPTIONS $GH_RUNNER_OPTIONS

# First generate a registration token (see https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-a-registration-token-for-a-repository)
REGISTRATION_TOKEN=`curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/${OWNER_REPO_OR_ORG}/actions/runners/registration-token | jq -r .token`

cd /home/$GH_RUNNER_USER/actions-runner

./config.sh --url "$REPOSITORY_URL" \
--token "$REGISTRATION_TOKEN" \
--name "$(hostname)" \
--work "${OWNER_REPO_OR_ORG//\//_}_work" \
--replace \
--unattended \
$GH_RUNNER_OPTIONS

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token ${REGISTRATION_TOKEN}
}

trap 'cleanup; exit 0' INT TERM KILL SIGINT SIGTERM SIGKILL

./run.sh & wait $!