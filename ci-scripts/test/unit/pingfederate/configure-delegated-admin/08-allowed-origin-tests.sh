#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

buildOriginList() {
  return 0
}

testSadPathAuthServerSettingsFailure() {
  get_auth_server_settings() {
    return 1
  }

  setAllowedOrigins > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testSadPathCreateAllowedOrigins() {
  get_auth_server_settings() {
    return 0
  }

  make_api_request() {
    return 1
  }

  setAllowedOrigins > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateAllowedOrigins() {
  get_auth_server_settings() {
    return 0
  }

  make_api_request() {
    return 0
  }

  setAllowedOrigins > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}