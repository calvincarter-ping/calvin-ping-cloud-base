#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

ADD_USER_LDIF_FILE="${PROJECT_DIR}"/ci-scripts/test/integration/pingdelegator/templates/add-users.ldif
DELETE_USER_LDIF_FILE="${PROJECT_DIR}"/ci-scripts/test/integration/pingdelegator/templates/delete-users.ldif

SERVER="pingdirectory-0"
CONTAINER="pingdirectory"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  TEST_LDIF_FILE=/tmp/01-test-admin-login.ldif
  touch ${TEST_LDIF_FILE}

  TEST_PF_HTML_FORM=$(mktemp -t "pf-admin-login-form-XXXXXXXXXX")

  add_users
}

oneTimeTearDown() {
  # Need this to suppress tearDown on script EXIT
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0

  delete_users

  # Remove test file from test environment and cluster
  rm ${TEST_LDIF_FILE}
  rm ${TEST_PF_HTML_FORM}

  kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${NAMESPACE}" -- \
          sh -c "rm ${TEST_LDIF_FILE} > /dev/null"
  
  unset TEST_LDIF_FILE
  unset TEST_PF_HTML_FORM
}

# Helper Methods

add_users() {
  kubectl cp ${ADD_USER_LDIF_FILE} "${SERVER}:${TEST_LDIF_FILE}" -c "${CONTAINER}" -n "${NAMESPACE}"
  kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${NAMESPACE}" -- \
    sh -c "ldapmodify --defaultAdd --ldifFile ${TEST_LDIF_FILE}"
}

delete_users() {
  kubectl cp ${DELETE_USER_LDIF_FILE} "${SERVER}:${TEST_LDIF_FILE}" -c "${CONTAINER}" -n "${NAMESPACE}"
  kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${NAMESPACE}" -- \
    sh -c "ldapdelete --filename ${TEST_LDIF_FILE}"
}

login() {
  local pf_login_url="${PINGFEDERATE_AUTH_ENDPOINT}/as/authorization.oauth2"
  local client_id="client_id=dadmin"
  local da_redirect_uri="redirect_uri=https%3A%2F%2Fpingdelegator-calvincarter.calvin.ping-demo.com%2Fdelegator%23%2Fcallback"
  local response_type="response_type=token%20id_token"
  local scope="scope=openid%20urn%3Apingidentity%3Adirectory-delegated-admin"
  local nonce="nonce=50040bd1c8084c97b2b7f727003fa3e4"

  local pf_form_url="${pf_login_url}?${client_id}&${da_redirect_uri}&${response_type}&${scope}&${nonce}"

  local pf_cookie=$(curl -kc - "${pf_form_url}" -o ${TEST_PF_HTML_FORM} | awk '/PF/{print $NF}')
  
  local pf_action_url=$(awk '/\/resume\/as\/authorization.ping/' ${TEST_PF_HTML_FORM} | awk -F '"' '$0=$4')

  echo "${PINGFEDERATE_AUTH_ENDPOINT}${pf_action_url}"

  # Use PF cookie and attempt to log admin user in by filling out form
  ACCESS_TOKEN_CALLBACK=$(curl -Ls "${PINGFEDERATE_AUTH_ENDPOINT}${pf_action_url}" \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "cookie: PF=${pf_cookie}" \
  -d pf.username=administrator \
  -d pf.pass=2Federate \
  -d pf.ok=clicked \
  -d pf.adapterId=daidphtml \
  -o /dev/null \
  -w "%{http_code}" \
  -w %{url_effective})
}

testLogin() {

  ACCESS_TOKEN_CALLBACK=

  # Login
  login
  assertEquals 0 $?

  echo "${ACCESS_TOKEN_CALLBACK}" | grep access_token > /dev/null
  assertEquals 0 $?

  # Use token to perform user lookup from PD

  local access_token=$(echo "${ACCESS_TOKEN_CALLBACK}" | awk -v FS="(access_token=|&)" '{print $2}')

  echo "${access_token}"

  local pd_response=$(curl -k "${PINGDIRECTORY_API}/dadmin/v2/users?filter=user.0" \
  -H "authorization: Bearer ${access_token}")
  assertEquals 0 $?

  local found_uid=$(echo "${pd_response}" | jq -r '.data[].attributes.uid[0]')

  assertEquals "user.0" "${found_uid}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
