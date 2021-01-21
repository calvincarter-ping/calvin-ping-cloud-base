#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingDelegatorService() {

  service_name="pingdelegator"

  # Get 1st delegator pod name
  delegator_pod_name=$(kubectl get pods \
        -n "${NAMESPACE}" \
        -l class=pingdelegator-server \
        -o=jsonpath="{.items[0].metadata.name}" |\
        tr -s '[[:space:]]')
  assertEquals "Failed to get pingdelegator pod name" 0 $?
  
  # Get delegator service port number
  delegator_pod_port=$(kubectl get service "${service_name}" \
                          -n "${NAMESPACE}" -o json |\
                          jq -r '.spec.ports[].port' |\
                          tr -s '[[:space:]]' '\n')
  assertEquals "Failed to get pingdelegator pod port" 0 $?

  exit_code=0
  for PORT in {1..10}
  do

    # Test service request
    kubectl exec -it "${delegator_pod_name}" -n "${NAMESPACE}" -- \
      curl -ssk -o /dev/null "https://${service_name}.${NAMESPACE}.svc.cluster.local:${delegator_pod_port}"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
      log "The Ping Delegated Admin service is inaccessible.  This is attempt ${i} of 10.  Wait 60 seconds and then try again..."
      sleep 60
    else
      break
    fi
  done

  assertEquals 0 $exit_code
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}