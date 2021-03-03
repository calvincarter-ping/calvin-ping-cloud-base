#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  pod_label_name="role=pingdelegator"

  # Get all pingdelegator pod names
  delegator_pod_names=$(kubectl get pods \
                          -n "${NAMESPACE}" \
                          -l ${pod_label_name} \
                          -o=jsonpath="{.items[*].metadata.name}")
  assertEquals "Failed to get pingdelegator pod name" 0 $?
  delegator_pod_names=$(echo "${delegator_pod_names}" | tr -s '[[:space:]]' '\n')
  readonly FIRST_DELEGATOR_POD_NAME=$(echo "${delegator_pod_names}" | head -n 1)

  readonly DA_LOG_STREAM_SUFFIX="${FIRST_DELEGATOR_POD_NAME}_${NAMESPACE}_pingdelegator"
}

testStreamsExist() {
  local log_stream_prefixes="pingdelegator_nginx_access_logs"

  local success=0
  if ! log_streams_exist "${log_stream_prefixes}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

testLogEventsExist() {
  local log_stream="pingdelegator_nginx_access_logs.$DA_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/access.log
  local pod="$FIRST_DELEGATOR_POD_NAME"
  local container=pingdelegator

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

testDefaultLogEventsExist() {
  local log_stream="$DA_LOG_STREAM_SUFFIX"
  local full_pathname=unused_placeholder_variable
  local pod="$FIRST_DELEGATOR_POD_NAME"
  local container=pingdelegator
  local default=true

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}" "${default}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
