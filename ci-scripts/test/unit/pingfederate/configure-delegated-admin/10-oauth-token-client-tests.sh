#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

get_oauth_token_validator_client() {
  export DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE="HTTP status code: 404"
}

testSadPathCreateImplicitClient() {
  make_api_request() {
    return 1
  }

  set_oauth_token_validator_client > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateImplicitClient() {
  make_api_request() {
    return 0
  }

  set_oauth_token_validator_client > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
