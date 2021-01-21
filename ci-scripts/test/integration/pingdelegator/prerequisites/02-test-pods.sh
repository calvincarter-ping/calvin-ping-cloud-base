#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingDelegatorPod() {

  pod_label_name="class=pingdelegator-server"

  # Get all pingdelegator pod names
  delegator_pod_names=$(kubectl get pods \
                          -n "${NAMESPACE}" \
                          -l ${pod_label_name} \
                          -o=jsonpath="{.items[*].metadata.name}" |\
                          tr -s '[[:space:]]' ' ')
  assertEquals "Failed to get pingdelegator pod name" 0 $?


  # Get delegator pod port number. e.g. 6443 
  delegator_pod_port=$(kubectl get pods \
                          -n "${NAMESPACE}" \
                          -l ${pod_label_name} \
                          -o jsonpath="{.items[0].spec.containers[*].ports[*].containerPort}" |\
                          tr -s '[[:space:]]')
  assertEquals "Failed to get pingdelegator pod port" 0 $?

  for pod_name in ${delegator_pod_names}
  do

    # Test local pod connection
    kubectl exec -it "${pod_name}" -n "${NAMESPACE}" -- \
      curl -ssk -o /dev/null "https://localhost:${delegator_pod_port}"
    exit_code=$?

    assertEquals "The Ping Delegated Admin pod '${pod_name}:${delegator_pod_port}' connection is inaccessible." 0 $exit_code
  done
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}