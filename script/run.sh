#!/bin/bash

[ -z "$REGION" ] && REGION="PROD"

if [ -z "${ATLASSIAN_STATUS_PAGE_KEY}" ]; then ERRORS="$ERRORS\nATLASSIAN_STATUS_PAGE_KEY is not populated. It should be a status page key"; fi
if [ -z "${ATLASSIAN_STATUS_PAGE_ID}" ]; then ERRORS="$ERRORS\nATLASSIAN_STATUS_PAGE_ID is not populated. It should be a status page id"; fi
if [ -z "${TF_VAR_api_endpoint}" ]; then ERRORS="$ERRORS\nTF_VAR_api_endpoint is not populated. It should be scylla public API"; fi
if [ -z "${TF_VAR_token}" ]; then ERRORS="$ERRORS\nTF_VAR_token is not populated. It should be scylla public api token"; fi

if [ -n "$ERRORS" ]; then
  echo -e "Following errors found:$ERRORS"
  exit 1
fi

tmpoutputfile=$(mktemp)
echo $tmpoutputfile >&2

function cleanup {
  terraform destroy -auto-approve 2>/dev/null 1>&2
  rm -f ${tmpoutputfile}
}
trap cleanup EXIT

function pending_incident() {
  curl -X GET -H "Authorization:OAuth ${ATLASSIAN_STATUS_PAGE_KEY}" \
  "https://api.statuspage.io/v1/pages/${ATLASSIAN_STATUS_PAGE_ID}/incidents/unresolved" 2>/dev/null | jq '.[]|select(.metadata.info.created_by == "status page agent").id' 2>/dev/null
}

function post_incident() {
  COMMAND_OUTPUT=$(cat ${tmpoutputfile} | jq -Rsa .)
  COMMAND_OUTPUT=${COMMAND_OUTPUT:1:${#COMMAND_OUTPUT}-2}

  curl "https://api.statuspage.io/v1/pages/${ATLASSIAN_STATUS_PAGE_ID}/incidents" \
    -H "Authorization: OAuth ${ATLASSIAN_STATUS_PAGE_KEY}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"incident\" : {
          \"name\": \"Failed to provision clusters\",
          \"status\": \"investigating\",
          \"metadata\": {\"info\": {\"created_by\": \"status page agent\"}},
          \"body\": \"Cluster provisioning failed on ${REGION}:\n\u2502$COMMAND_OUTPUT\"
        }}"
}

function update_incident() {
  INCIDENT=$1
  STATUS=$2
  TEXT=$3

  STATUS_STR=""
  if [ -n "${STATUS}" ]; then
    STATUS_STR="\"status\": \"${STATUS}\","
  fi

  curl "https://api.statuspage.io/v1/pages/${ATLASSIAN_STATUS_PAGE_ID}/incidents/${INCIDENT}" \
      -H "Authorization: OAuth ${ATLASSIAN_STATUS_PAGE_KEY}" \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "{\"incident\" : {
            ${STATUS_STR}
            \"body\": \"${TEXT}\"
          }}"

}

PENDING=$(pending_incident)
[ -n "${PENDING}" ] && PENDING=${PENDING:1:${#PENDING}-2}

if (terraform init -no-color; terraform apply -no-color -auto-approve) 2>${tmpoutputfile}; then
  echo "Clusters successfully provisioned"
  if [ -z "${PENDING}" ]; then
    exit
  fi
  echo "Resolve pending ticket"
  update_incident "${PENDING}" "resolved" "Issue disappeared, clusters successfully provisioned"
  exit
fi
cat "${tmpoutputfile}"
echo "Cluster failed to create"
if [ -n "${PENDING}" ]; then
  echo "There is already ongoing ticket, update it"
  update_incident "${PENDING}" "" "Issue still persists"
  exit
fi
echo "No pending ticket, create new one"
post_incident