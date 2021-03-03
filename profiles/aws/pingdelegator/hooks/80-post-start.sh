#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"


# At a minimum, you must configure the following on PingFederate Server to support DA:
# 1) Configure PingFederate as the identity provider for Delegated Admin.
# 2) Configure PingFederate as the OAuth server for Delegated Admin.
# 3) Register Delegated Admin as a client.
# 4) Register PingDirectory Server as an OAuth token validator client.


# Configure DAs jwt, policy, implicit and authorization server clients
# beluga_log "post-start: Configure DAs jwt, policy, implicit and authorization server clients"
# sh "${HOOKS_DIR}/84-client-implicit-grant-type.sh"
