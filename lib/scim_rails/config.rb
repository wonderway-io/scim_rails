module ScimRails
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Config.new
    end
  end

  # Class containing configuration of ScimRails
  class Config
    ALGO_NONE = 'none'.freeze

    attr_writer \
      :basic_auth_model,
      :mutable_user_attributes_schema,
      :scim_users_model

    attr_accessor \
      :basic_auth_model_authenticatable_attribute,
      :basic_auth_model_searchable_attribute,
      :mutable_user_attributes,
      :on_error,
      :on_retrieve_user,
      :on_validate_auth_model,
      :queryable_user_attributes,
      :scim_users_created_at_field,
      :scim_users_updated_at_field,
      :scim_users_list_order,
      :scim_users_scope,
      :signing_secret,
      :signing_algorithm,
      :user_attributes,
      :user_deprovision_method,
      :user_reprovision_method,
      :user_schema

    def initialize
      @basic_auth_model = 'Company'
      @scim_users_list_order = :id
      @scim_users_created_at_field = :created_at
      @scim_users_updated_at_field = :updated_at
      @scim_users_model = 'User'
      @signing_algorithm = ALGO_NONE
      @user_schema = {}
      @user_attributes = []
    end

    def scim_users_id_field
      user_schema[:id] || :id
    end

    def mutable_user_attributes_schema
      @mutable_user_attributes_schema || @user_schema
    end

    def basic_auth_model
      @basic_auth_model.constantize
    end

    def scim_users_model
      @scim_users_model.constantize
    end
  end
end
