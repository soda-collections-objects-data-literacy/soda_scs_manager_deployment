uuid: f97a89a8-9809-472a-a233-09fc0213444b
langcode: en
status: true
dependencies: {  }
id: scs_sso
label: 'SCS SSO'
plugin: generic
settings:
  client_id: scs_manager
  client_secret: ${SCS_MANAGER_CLIENT_SECRET}
  iss_allowed_domains: '*'
  issuer_url: ''
  authorization_endpoint: 'https://${KC_SERVICE_NAME}.${SCS_SUBDOMAIN}.${SCS_BASE_DOMAIN}/realms/${KC_REALM}/protocol/openid-connect/auth'
  token_endpoint: 'https://${KC_SERVICE_NAME}.${SCS_SUBDOMAIN}.${SCS_BASE_DOMAIN}/realms/${KC_REALM}/protocol/openid-connect/token'
  userinfo_endpoint: 'https://${KC_SERVICE_NAME}.${SCS_SUBDOMAIN}.${SCS_BASE_DOMAIN}/realms/${KC_REALM}/protocol/openid-connect/userinfo'
  end_session_endpoint: 'https://${KC_SERVICE_NAME}.${SCS_SUBDOMAIN}.${SCS_BASE_DOMAIN}/realms/${KC_REALM}/protocol/openid-connect/logout'
  scopes:
    - openid
    - email
    - groups
