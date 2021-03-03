#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

is_multi_cluster() {
  return 0
}

testSadPathVirtualHostsFailure() {
  getVirtualHosts() {
    return 1
  }

  setVirtualHosts > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testSadPathCreateVirtualHosts() {
  getVirtualHosts() {
    return 0
  }

  make_api_request() {
    return 1
  }

  setVirtualHosts > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateVirtualHosts() {
  getVirtualHosts() {
    return 0
  }

  make_api_request() {
    return 0
  }

  setVirtualHosts > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
