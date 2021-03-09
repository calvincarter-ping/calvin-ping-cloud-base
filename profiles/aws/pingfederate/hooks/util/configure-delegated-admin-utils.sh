#!/usr/bin/env sh

PF_API_404_MESSAGE="HTTP status code: 404"
TEMPLATES_DIR_PATH="${STAGING_DIR}"/templates/83
PF_API_HOST="https://${PF_ADMIN_HOST_PORT}/pf-admin-api/v1"

get_datastore() {
  DATA_STORES_RESPONSE=$(make_api_request -X GET "${PF_API_HOST}/dataStores") > /dev/null
}

get_pcv() {
  DA_PCV_RESPONSE=$(make_api_request -X GET \
  	"${PF_API_HOST}/passwordCredentialValidators/${DA_PCV_ID}") > /dev/null
}

set_pcv() {
  unset PD_DATASTORE_ID

  if ! get_datastore; then
    beluga_error "Something went wrong when attempting to get datastore response"
    return 1
  fi

  get_pcv

  # If API return 404 status code. Proceed to create PCV.
  if test $(echo "${DA_PCV_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating PCV"

    # Export datastore id. It is required within template create-password-credentials-validator.
    export PD_DATASTORE_ID=$(jq -n "${DATA_STORES_RESPONSE}" | jq -r '.items[] | select(.name=="pingdirectory-appintegrations") | .id')

		local pcv_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-password-credentials-validator.json)

    make_api_request -X POST -d "${pcv_payload}" \
		  "${PF_API_HOST}/passwordCredentialValidators" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "PCV, '${DA_PCV_ID}', successfully created"
  else
    beluga_log "PCV, '${DA_PCV_ID}', already exist"

    # Look to see if USER_BASE_DN has changed.
    if ! checkUserBaseDn; then
      return 1
    fi

    beluga_log "PCV, ${DA_PCV_ID}, is using search base '${USER_BASE_DN}'"
  fi
}

checkUserBaseDn() {
  # Change PCV search base if its different than PD USER_BASE_DN.
  local current_pcv_user_base_dn=$(jq -n "${DA_PCV_RESPONSE}" | jq -r '.configuration.fields[] | select(.name=="Search Base") | .value')

  if [[ "${current_pcv_user_base_dn}" != "${USER_BASE_DN}" ]]; then
    if ! change_pcv_search_base; then
      beluga_error "Something went wrong when attempting to change, ${DA_PCV_ID}, search base"
      return 1
    fi
  fi

  return 0
}

change_pcv_search_base() {
  beluga_log "Changing PCV, ${DA_PCV_ID}, search base. Its current value is '${current_pcv_user_base_dn}' and needs to be the same as PD USER_BASE_DN '${USER_BASE_DN}'"

  local new_user_base_dn_payload=$(jq -n "${DA_PCV_RESPONSE}" |\
  jq --arg user_base_dn "${USER_BASE_DN}" '(.configuration.fields[] | select(.name=="Search Base") | .value) |= $user_base_dn')

  make_api_request -X PUT -d "${new_user_base_dn_payload}" \
    "${PF_API_HOST}/passwordCredentialValidators/${DA_PCV_ID}" > /dev/null
  test $? -ne 0 && return 1

  beluga_log "PCV, ${DA_PCV_ID}, search base successfully updated to ${USER_BASE_DN}"
}

get_idp_adapter_html_form() {
  DA_IDP_ADAPTER_HTML_FORM_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/idp/adapters/${DA_IDP_ADAPTER_HTML_FORM_ID}") > /dev/null
}

set_idp_adapter_html_form() {

  get_idp_adapter_html_form

  # If API return 404 status code. Proceed to create IDP adapter HTML form.
  if test $(echo "${DA_IDP_ADAPTER_HTML_FORM_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating IDP adapter html form"

		local idp_adapter_html_form_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-idp-adapter-html-form.json)

    make_api_request -X POST -d "${idp_adapter_html_form_payload}" \
			"${PF_API_HOST}/idp/adapters" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "IDP adapter HTML form, '${DA_IDP_ADAPTER_HTML_FORM_ID}', successfully created"
  else
    beluga_log "IDP adapter HTML form, '${DA_IDP_ADAPTER_HTML_FORM_ID}', already exist"
  fi
}

get_idp_adapter_mapping() {
  DA_IDP_ADAPTER_MAPPING_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/idpAdapterMappings/${DA_IDP_ADAPTER_HTML_FORM_ID}") > /dev/null
}

set_idp_adapter_mapping() {

  get_idp_adapter_mapping

  # If API return 404 status code. Proceed to create IDP adapter mapping.
  if test $(echo "${DA_IDP_ADAPTER_MAPPING_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating IDP adapter mapping"

		local idp_adapter_mapping_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-idp-adapter-mapping.json)

    make_api_request -X POST -d "${idp_adapter_mapping_payload}" \
		  "${PF_API_HOST}/oauth/idpAdapterMappings" > /dev/null
    test $? -ne 0 && return 1
    
    beluga_log "IDP adapter mapping, '${DA_IDP_ADAPTER_HTML_FORM_ID}', successfully created"
  else
    beluga_log "IDP adapter mapping, '${DA_IDP_ADAPTER_HTML_FORM_ID}', already exist"
  fi
}

get_jwt() {
  DA_JWT_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/accessTokenManagers/${DA_JWT_ID}") > /dev/null
}

set_jwt() {
  unset DA_JWT_SYMMETRIC_KEY

  get_jwt
  
  # If API return 404 status code. Proceed to create JWT.
  if test $(echo "${DA_JWT_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating JWT"

    # Generate random symmetric key and export. It is required within template create-jwt.
    export DA_JWT_SYMMETRIC_KEY=$(dd if=/dev/urandom count=5 bs=8 | xxd -p | head -n 2 | tr -d '[:space:]')

		local create_jwt_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-jwt.json)

    make_api_request -X POST -d "${create_jwt_payload}" \
			"${PF_API_HOST}/oauth/accessTokenManagers" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "JWT, '${DA_JWT_ID}', successfully created"
  else    
    beluga_log "JWT, '${DA_JWT_ID}', already exist"
  fi
}

get_jwt_default_mapping() {
  local jwt_default_mapping_id="default%7C${DA_JWT_ID}"
  DA_JWT_DEFAULT_MAPPING_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/accessTokenMappings/${jwt_default_mapping_id}") > /dev/null
}

set_jwt_default_mapping() {

  get_jwt_default_mapping
  
  # If API return 404 status code. Proceed to create JWT default mapping.
  if test $(echo "${DA_JWT_DEFAULT_MAPPING_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating JWT default mapping"

		local jwt_default_mapping_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-jwt-mapping.json)

    make_api_request -X POST -d "${jwt_default_mapping_payload}" \
      "${PF_API_HOST}/oauth/accessTokenMappings" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "JWT default mapping, '${DA_JWT_ID}', successfully created"
  else
    beluga_log "JWT default mapping, '${DA_JWT_ID}', already exist"
  fi
}

get_oidc_policy() {
  DA_OIDC_POLICY_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/openIdConnect/policies/${DA_OIDC_POLICY_ID}") > /dev/null
}

set_oidc_policy() {

  get_oidc_policy

  # If API return 404 status code. Proceed to create OIDC policy.
  if test $(echo "${DA_OIDC_POLICY_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating OIDC policy"

		local oidc_policy_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-open-id-policy.json)

    make_api_request -X POST -d "${oidc_policy_payload}" \
			"${PF_API_HOST}/oauth/openIdConnect/policies" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "OIDC policy, '${DA_OIDC_POLICY_ID}', successfully created"
  else
    beluga_log "OIDC policy, '${DA_OIDC_POLICY_ID}', already exist"
  fi
}

get_exclusive_scope() {
  EXCLUSIVE_SCOPE_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/authServerSettings/scopes/exclusiveScopes/${DA_EXCLUSIVE_SCOPE_NAME}") > /dev/null
}

set_exclusive_scope() {

  get_exclusive_scope
  
  # If API return 404 status code. Proceed to create exclusive scope.
  if test $(echo "${EXCLUSIVE_SCOPE_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating exclusive scope"

		local exclusive_scope_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-exclusive-scope.json)

    make_api_request -X POST -d "${exclusive_scope_payload}" \
			"${PF_API_HOST}/oauth/authServerSettings/scopes/exclusiveScopes" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "Exclusive scope, '${DA_EXCLUSIVE_SCOPE_NAME}', created successfully"
  else
    beluga_log "Exclusive scope, '${DA_EXCLUSIVE_SCOPE_NAME}', already exist"
  fi
}

get_auth_server_settings() {
  AUTH_SERVER_SETTINGS_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/authServerSettings") > /dev/null
}

setAllowedOrigins() {

  if ! get_auth_server_settings; then
    beluga_error "Something went wrong when attempting to get auth server settings response"
    return 1
  fi
  
  # PD HTTP and PingDelegator hosts are the allowed origins. Build a list of the hosts
  # and append it to AUTH_SERVER_SETTINGS_PAYLOAD
  beluga_log "Updating allowed origins"
  AUTH_SERVER_SETTINGS_PAYLOAD="${AUTH_SERVER_SETTINGS_RESPONSE}"
  buildOriginList
  
  make_api_request -X PUT -d "${AUTH_SERVER_SETTINGS_PAYLOAD}" \
			"${PF_API_HOST}/oauth/authServerSettings" > /dev/null
  test $? -ne 0 && return 1

  beluga_log "Auth server settings updated successfully"
}

buildOriginList() {

  local descriptor_file="${STAGING_DIR}/topology/descriptor.json"

  # if deploying in multi_cluster environment, then use PDs descriptor.json to get the public host names per region.
  if is_multi_cluster; then
    for region in $(jq 'keys[]' "${descriptor_file}"); do
      # Get PD hostname from descriptor file.
      local pd_hostname=$(jq . "${descriptor_file}" | jq .[$region] | jq -r '.hostname')

      # Construct DA hostname.
      local da_hostname="${PD_DELEGATOR_PUBLIC_HOSTNAME%%.*}.${pd_hostname#*.}"

      # Construct PD HTTP hostname.
      local pd_http_hostname="${PD_HTTP_PUBLIC_HOSTNAME%%.*}.${pd_hostname#*.}"

      # Add PD and DA hostname to allowed origin settings.
      for url in "https://${da_hostname}" "https://${pd_http_hostname}"; do
        addOrigin "${url}"
      done
    done
  else
    # Add PD and DA hostname to allowed origin settings.
    for url in "https://${PD_DELEGATOR_PUBLIC_HOSTNAME}" "https://${PD_HTTP_PUBLIC_HOSTNAME}"; do
      addOrigin "${url}"
    done
  fi
}

addOrigin() {
  local url="$1"

  # If url does NOT exist within payload, then add it to .allowedOrigins JSON property.
  # This means only add new urls as allowed origin.
  local host_name_already_exist=$(jq -n "${AUTH_SERVER_SETTINGS_PAYLOAD}" | jq --arg url "${url}" '.allowedOrigins | contains([$url])')
  if [[ "${host_name_already_exist}" == "false" ]]; then
    AUTH_SERVER_SETTINGS_PAYLOAD=$(jq -n "${AUTH_SERVER_SETTINGS_PAYLOAD}" | jq --arg url "${url}" '.allowedOrigins |= .+ [$url]')
  fi
}

get_implicit_grant_type_client() {
  DA_IMPLICIT_CLIENT_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/clients/${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}") > /dev/null
}

set_implicit_grant_type_client() {

  get_implicit_grant_type_client

  # If API return 404 status code. Proceed to create implicit grant type client.
  if test $(echo "${DA_IMPLICIT_CLIENT_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating implicit grant type"

    local implicit_grant_type_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-implicit-grant-type.json)

    # Build a list of all DA hostname(s) and merge it to redirectUris JSON property.
    REDIRECT_URIS=$(envsubst < ${TEMPLATES_DIR_PATH}/redirect-uris-template.json)
    buildRedirectUriList

    # Join API JSON payload with redirectUris list.
		implicit_grant_type_payload=$(echo "${implicit_grant_type_payload}" ${REDIRECT_URIS} | jq -s add)

    make_api_request -X POST -d "${implicit_grant_type_payload}" \
			"${PF_API_HOST}/oauth/clients" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "Implicit grant type, '${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}', created successfully"
  else
    beluga_log "Implicit grant type, '${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}', already exist"
  fi
}

buildRedirectUriList() {
  local descriptor_file="${STAGING_DIR}/topology/descriptor.json"
  
  # if deploying in multi_cluster environment, then use PDs descriptor.json to get the public host names per region.
  if is_multi_cluster; then
    for region in $(jq 'keys[]' "${descriptor_file}"); do

      # Get PD hostname from descriptor file.
      local pd_hostname=$(jq . "${descriptor_file}" | jq .[$region] | jq -r '.hostname')

      # Construct DA hostname.
      local da_hostname="${PD_DELEGATOR_PUBLIC_HOSTNAME%%.*}.${pd_hostname#*.}"

      # Append to redirectUris list.
      addRedirectUri "https://${da_hostname}:443/*"
      addRedirectUri "https://${da_hostname}/*"
    done
  else
    # Append to redirectUris list.
    addRedirectUri "https://${PD_DELEGATOR_PUBLIC_HOSTNAME}:443/*"
    addRedirectUri "https://${PD_DELEGATOR_PUBLIC_HOSTNAME}/*"
  fi
}

addRedirectUri() {
  local url="$1"
  REDIRECT_URIS=$(jq -n "${REDIRECT_URIS}" | jq --arg url "${url}" '.redirectUris |= .+ [$url]' )
}

get_oauth_token_validator_client() {
  DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/oauth/clients/${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}") > /dev/null
}

set_oauth_token_validator_client() {

  get_oauth_token_validator_client

  # If API return 404 status code. Proceed to create access token validation grant type client.
  if test $(echo "${DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

		beluga_log "Creating OAuth token validator client"

		local oauth_token_val_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-authorization-server-grant-type.json)

    make_api_request -X POST -d "${oauth_token_val_payload}" \
			"${PF_API_HOST}/oauth/clients" > /dev/null
    test $? -ne 0 && return 1

    beluga_log "OAuth token validator client, '${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}', created successfully"
  else
    beluga_log "OAuth token validator client, '${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}', already exist"

    # Sync password with PD.
    # This is done just in case password has been changed when injecting secret.
    if ! sync_oauth_token_validator_password; then
      beluga_error "Something went wrong when synchronizing oauth token secret with PD"
      return 1
    fi

    beluga_log "OAuth token validator client password synced successfully with PingDirectory"
  fi
}

sync_oauth_token_validator_password() {
  local oauth_token_val_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/sync-oauth-token-validator-password.json)
  make_api_request -X PUT -d "${oauth_token_val_payload}" \
		"${PF_API_HOST}/oauth/clients/${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}/clientAuth/clientSecret" > /dev/null
}

getVirtualHostNames() {
  DA_VIRTUAL_HOST_RESPONSE=$(make_api_request -X GET \
		"${PF_API_HOST}/virtualHostNames") > /dev/null
}

setVirtualHosts() {

  if ! is_multi_cluster; then
    beluga_log "Not in multi cluster mode. Skip configuration of virtual host"
    return 0
  fi

  if ! getVirtualHostNames; then
    beluga_error "Something went wrong when attempting to get virtual host names response"
    return 1
  fi

  beluga_log "Updating virtual hosts"

  # Build a list of all PF hostname(s) that are not within the primary region and append it to DA_VIRTUAL_HOST_PAYLOAD
  # The BaseURL in PF is what the primary region uses. Any other region will need to be a virtual host.
  DA_VIRTUAL_HOST_PAYLOAD="${DA_VIRTUAL_HOST_RESPONSE}"
  buildVirtualHostList
  
  make_api_request -X PUT -d "${DA_VIRTUAL_HOST_PAYLOAD}" \
		"${PF_API_HOST}/virtualHostNames" > /dev/null
  test $? -ne 0 && return 1

  beluga_log "Virtual host settings updated successfully"
}

buildVirtualHostList() {
  local descriptor_file="${STAGING_DIR}/topology/descriptor.json"

  # if deploying in multi_cluster environment, then use PDs descriptor.json to get the public host names per region.
  for region in $(jq 'keys[]' "${descriptor_file}"); do
    # Get PD hostname from descriptor file.
    local pd_hostname=$(jq . "${descriptor_file}" | jq .[$region] | jq -r '.hostname')

    # Construct PF Engine hostname.
    local pf_hostname="${PF_ENGINE_PUBLIC_HOSTNAME%%.*}.${pd_hostname#*.}"

    # Only add secondary or more regions as a virtual host. 
    # This if condition is skipping primary region which is PF_ENGINE_PUBLIC_HOSTNAME.
    if [[ "${pf_hostname}" != "${PF_ENGINE_PUBLIC_HOSTNAME}" ]]; then
      addVirtualHost "${pf_hostname}"
    fi
  done
}

addVirtualHost() {
  local url="$1"

  # If url does NOT exist within payload, then add it to .virtualHostNames JSON property.
  # This means only add new virtual hosts.
  local virtual_host_name_already_exist=$(jq -n "${DA_VIRTUAL_HOST_PAYLOAD}" | \
    jq --arg url "${url}" '.virtualHostNames | contains([$url])')
  
  if [[ "${virtual_host_name_already_exist}" == "false" ]]; then
    DA_VIRTUAL_HOST_PAYLOAD=$(jq -n "${DA_VIRTUAL_HOST_PAYLOAD}" | \
      jq --arg url "${url}" '.virtualHostNames |= .+ [$url]' )
  fi
}