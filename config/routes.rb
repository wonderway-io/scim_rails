ScimRails::Engine.routes.draw do
  # Config controller
  get 'scim/v2/ServiceProviderConfig',
    action: :service_provider_config,
    controller: 'scim_configs'
  get 'scim/v2/ResourceTypes',
    action: :resource_types,
    controller: 'scim_configs'
  get 'scim/v2/Schemas', action: :schemas, controller: 'scim_configs'

  # Users controller
  get     'scim/v2/Users',      action: :index,   controller: 'scim_users'
  post    'scim/v2/Users',      action: :create,  controller: 'scim_users'
  get     'scim/v2/Users/:id',  action: :show,    controller: 'scim_users'
  put     'scim/v2/Users/:id',  action: :put,     controller: 'scim_users'
  patch   'scim/v2/Users/:id',  action: :patch,   controller: 'scim_users'
  delete  'scim/v2/Users/:id',  action: :delete,  controller: 'scim_users'
end
