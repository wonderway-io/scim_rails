require 'spec_helper'

RSpec.describe ScimRails::ScimUsersController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  def patch_params(id:, active: false)
    {
      id: id,
      Operations: [
        {
          op: 'replace',
          value: {
            active: active
          }
        }
      ]
    }
  end

  describe 'patch update' do
    let(:company) { create(:company) }

    context 'when unauthorized' do
      it 'returns scim+json content type' do
        patch :patch, params: patch_params(id: 1), as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'fails with no credentials' do
        patch :patch, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 401
      end

      it 'fails with invalid credentials' do
        request.env['HTTP_AUTHORIZATION'] =
          ActionController::HttpAuthentication::Basic.encode_credentials(
            'unauthorized', '123456'
          )

        patch :patch, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when authorized' do
      let!(:user) { create(:user, id: 1, company: company) }

      before :each do
        http_login(company)
      end

      it 'returns scim+json content type' do
        patch :patch, params: patch_params(id: 1), as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'is successful with valid credentials' do
        patch :patch, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 200
      end

      it 'returns :not_found for id that cannot be found' do
        patch :patch, params: patch_params(id: 'fake_id'), as: :json

        expect(response.status).to eq 404
      end

      it 'returns :not_found for a correct id but unauthorized company' do
        new_company = create(:company)
        create(:user, company: new_company, id: 1000)

        patch :patch, params: patch_params(id: 1000), as: :json

        expect(response.status).to eq 404
      end

      it 'successfully archives user from replace' do
        expect(company.users.count).to eq 1
        user = company.users.first
        expect(user.archived?).to eq false

        patch :patch, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 200
        expect(company.users.count).to eq 1
        user.reload
        expect(user.archived?).to eq true
      end

      it 'successfully archives user from operations' do
        expect(company.users.count).to eq 1
        user = company.users.first
        expect(user.archived?).to eq false

        patch :patch, params: {
          id: 1,
          Operations: [
            {
              'op': 'add',
              'path': 'active',
              'value': 'False'
            }
          ]
        }, as: :json

        expect(response.status).to eq 200
        expect(company.users.count).to eq 1
        user.reload
        expect(user.archived?).to eq true
      end

      it 'successfully restores user' do
        expect(company.users.count).to eq 1
        user = company.users.first.tap(&:archive!)
        expect(user.archived?).to eq true

        patch :patch,
          params: patch_params(id: 1, active: true),
          as: :json

        expect(response.status).to eq 200
        expect(company.users.count).to eq 1
        user.reload
        expect(user.archived?).to eq false
      end

      it 'is case insensetive for op value' do
        # Note, this is for backward compatibility. op should always
        # be lower case and support for case insensitivity will be removed
        patch :patch, params: {
          id: 1,
          Operations: [
            {
              op: 'Replace',
              value: {
                active: false
              }
            }
          ]
        }, as: :json

        expect(response.status).to eq 200
      end

      it 'successfully updates a users name' do
        patch :patch, params: {
          id: 1,
          Operations: [
            {
              'op': 'Add',
              'path': 'name.familyName',
              'value': 'User Family Name'
            }
          ]
        }, as: :json

        expect(response.status).to eq 200
        expect(user.reload.last_name).to eq 'User Family Name'
      end

      it 'successfully runs multiple operations' do
        patch :patch, params: {
          id: 1,
          Operations: [
            {
              'op': 'Add',
              'path': 'name.familyName',
              'value': 'User Family Name'
            },
            {
              'op': 'Add',
              'path': 'name.givenName',
              'value': 'Otto II'
            }
          ]
        }, as: :json

        expect(response.status).to eq 200
        expect(user.reload.first_name).to eq 'Otto II'
        expect(user.reload.last_name).to eq 'User Family Name'
      end

      it 'returns 422 when value is missing' do
        patch :patch, params: {
          id: 1,
          Operations: [
            {
              op: 'replace'
            }
          ]
        }, as: :json

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)
        expect(response_body.dig('schemas', 0)).to eq(
          'urn:ietf:params:scim:api:messages:2.0:Error'
        )
      end
    end
  end
end
