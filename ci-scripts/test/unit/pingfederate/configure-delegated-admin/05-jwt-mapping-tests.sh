#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

get_jwt_default_mapping() {
  export DA_JWT_DEFAULT_MAPPING_RESPONSE="HTTP status code: 404"
}

testSadPathCreateJwtMapping() {
  make_api_request() {
    return 1
  }

  set_jwt_default_mapping > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateJwtMapping() {
  make_api_request() {
    return 0
  }

  set_jwt_default_mapping > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
