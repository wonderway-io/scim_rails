module ScimRails
  class ScimConfigsController < ScimRails::ApplicationController
    skip_before_action :authorize_request

    def service_provider_config
      json_response(
        schemas:
          ['urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig'],
        documentationUri: 'https://tools.ietf.org/html/rfc7644',
        patch: { supported: true },
        bulk: { supported: false, maxOperations: 0, maxPayloadSize: 0 },
        filter: { supported: false, maxResults: 100 },
        changePassword: { supported: false },
        sort: { supported: false },
        etag: { supported: false },
        authenticationSchemes: [
          {
            type: 'httpbasic',
            name: 'Http Basic',
            description:
              'Authentication scheme using the HTTP Basic Standard',
            specUri: 'http://www.rfc-editor.org/info/rfc2617'
          },
          {
            type: 'oauthbearertoken',
            name: 'Oauth Bearer Token',
            description:
              'Authentication scheme using the OAuth Bearer Token Standard',
            specUri: 'http://www.rfc-editor.org/info/rfc6750',
            primary: true
          }
        ],
        meta: {
          location: request.original_url,
          resourceType: 'ServiceProviderConfig'
          # created: Time.zone.now.iso8601,
          # lastModified: Time.zone.now.iso8601
        }
      )
    end

    def schemas
      schema_types = [
        'urn:ietf:params:scim:schemas:core:2.0:User',
        *ScimRails::ScimSchemaParser.extra_schema_types
      ]

      json_response(
        schema_types.map do |schema_type|
          schema_type = schema_type.to_s
          schema_name = schema_type.rpartition(':')[2]
          {
            schemas: ['urn:ietf:params:scim:schemas:core:2.0:Schema'],
            id: schema_type,
            name: schema_name,
            description: schema_name.humanize,
            attributes: ScimRails::ScimSchemaParser.schema(
              if schema_type != 'urn:ietf:params:scim:schemas:core:2.0:User'
                schema_type
              end
            ),
            meta: {
              location:
                "/v2/Schemas/#{schema_type}",
              resourceType: 'Schema'
            }
          }
        end
      )
    end

    def resource_types
      json_response(
        [
          {
            schemas: ['urn:ietf:params:scim:schemas:core:2.0:ResourceType'],
            id: 'User',
            name: 'User',
            endpoint: '/Users',
            description: 'User Account',
            schema: 'urn:ietf:params:scim:schemas:core:2.0:User',
            schemaExtensions: [
              {
                schema:
                  'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
                required: false
              }
            ],
            meta: {
              location: "#{request.original_url}/User",
              resourceType: 'ResourceType'
            }
          }
        ]
      )
    end
  end
end
