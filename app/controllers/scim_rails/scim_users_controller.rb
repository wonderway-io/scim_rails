module ScimRails
  class ScimUsersController < ScimRails::ApplicationController
    before_action :load_user, except: [:index, :create]
    after_action :update_status, except: [:index]

    def index
      users = company_users.order(ScimRails.config.scim_users_list_order)
      users = apply_filters(users)

      counts = ScimCount.new(
        start_index: params[:startIndex],
        limit: params[:count],
        total: users.count
      )

      json_scim_response(object: users, counts: counts)
    end

    def create
      # If user exists => fail
      username_key = ScimRails.config.queryable_user_attributes[:userName]
      username_value = permitted_user_params[username_key]
      raise ScimRails::ExceptionHandler::Uniqueness \
        if company_users.exists?(username_key => username_value)

      # Try to retrieve existing user that might have been archived
      if ScimRails.config.on_retrieve_user.respond_to?(:call)
        @user = ScimRails.config.on_retrieve_user.call(
          @company,
          permitted_user_params
        )
      end

      # If user can be recovered => recover
      if @user.present?
        @user.public_send(ScimRails.config.user_reprovision_method)
        @user.update! permitted_user_params
      # Create user
      else
        @user = company_users.create!(permitted_user_params)
      end

      ScimRails.config.on_created_user.call(@user) \
        if ScimRails.config.on_created_user.respond_to?(:call)

      json_scim_response(object: @user, status: :created)
    end

    def show
      json_scim_response(object: @user)
    end

    def put
      @user.update!(permitted_user_params)
      json_scim_response(object: @user)
    end

    def patch
      @user.transaction do
        (params['Operations'] || []).each do |operation|
          # add / replace / remove
          op = operation['op']
          # e.g. name.familyName or addresses[type eq \"work\"]
          path = operation['path']
          attribute = ScimRails::ScimPathParser.attribute_for(path)
          # e.g. my@user.com
          value = operation['value']
          raise ScimRails::ExceptionHandler::UnsupportedPatchRequest \
            if value.nil?

          case op.downcase.to_sym
          when :add, :replace
            if path.nil?
              params = permitted_user_params(value).compact
              @user.update! params
            elsif attribute.present?
              @user.update! attribute => value
            end
          when :remove
            raise ScimRails::ExceptionHandler::NoTarget if path.nil?
            next if attribute.nil?
            @user.update! attribute => nil
          end
        end
      end

      json_scim_response(object: @user)
    end

    def delete
      @user.public_send(ScimRails.config.user_deprovision_method)

      ScimRails.config.on_deleted_user.call(@user) \
        if ScimRails.config.on_deleted_user.respond_to?(:call)

      head :no_content
    end

  private

    def load_user
      @user = company_users.find_by!(
        ScimRails.config.scim_users_id_field => params[:id]
      )
    end

    def company_users
      @company.public_send(ScimRails.config.scim_users_scope)
    end

    def apply_filters(users)
      return users if params[:filter].blank?

      query = ScimRails::ScimQueryParser.new(params[:filter])

      column_name = ScimRails.config.scim_users_model.connection
        .quote_column_name(query.attribute)
      users.where(
        "#{column_name} #{query.operator} ?",
        query.parameter
      )
    end

    def permitted_user_params(user_params = params)
      ScimRails.config
        .mutable_user_attributes
        .each.with_object({}) do |attribute, hash|
          hash[attribute] = user_params.dig(
            *ScimRails::ScimPathParser.path_for(attribute)
          )
        end
    end

    def update_status
      return if active?.nil?
      @user.public_send(ScimRails.config.user_reprovision_method) if active?
      @user.public_send(ScimRails.config.user_deprovision_method) unless active?
    end

    def active?
      to_bool = ->(value) { [1, true, 'TRUE', 'True', 'true'].include?(value) }

      if params['Operations'].present?
        params['Operations'].each do |operation|
          if (
            operation['path'].nil? &&
            operation['value'].try { |value| value.include?('active') }
          )
            return to_bool.call(operation['value']['active'])
          end

          return to_bool.call(operation['value']) \
            if operation['path'] == 'active'
        end
      elsif params.include? :active
        to_bool.call(params[:active])
      end
    end
  end
end
