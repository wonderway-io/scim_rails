require 'spec_helper'

RSpec.describe ScimRails::ScimUsersController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe 'create' do
    let(:company) { create(:company) }

    context 'when unauthorized' do
      it 'returns scim+json content type' do
        post :create, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'fails with no credentials' do
        post :create, as: :json

        expect(response.status).to eq 401
      end

      it 'fails with invalid credentials' do
        request.env['HTTP_AUTHORIZATION'] =
          ActionController::HttpAuthentication::Basic.encode_credentials(
            'unauthorized', '123456'
          )

        post :create, as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when authorized' do
      before :each do
        http_login(company)
      end

      it 'returns scim+json content type' do
        post :create, params: {
          name: {
            givenName: 'New',
            familyName: 'User'
          },
          emails: [
            {
              value: 'new@example.com'
            }
          ]
        }, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'is successful with valid credentials' do
        expect(company.users.count).to eq 0

        post :create, params: {
          name: {
            givenName: 'New',
            familyName: 'User'
          },
          emails: [
            {
              value: 'new@example.com'
            }
          ]
        }, as: :json

        expect(response.status).to eq 201
        expect(company.users.count).to eq 1
        user = company.users.first
        expect(user.persisted?).to eq true
        expect(user.first_name).to eq 'New'
        expect(user.last_name).to eq 'User'
        expect(user.email).to eq 'new@example.com'
      end

      it 'ignores unconfigured params' do
        post :create, params: {
          name: {
            formattedName: 'New User',
            givenName: 'New',
            familyName: 'User'
          },
          emails: [
            {
              value: 'new@example.com'
            }
          ]
        }, as: :json

        expect(response.status).to eq 201
        expect(company.users.count).to eq 1
      end

      it 'returns 422 if required params are missing' do
        post :create, params: {
          name: {
            familyName: 'User'
          },
          emails: [
            {
              value: 'new@example.com'
            }
          ]
        }, as: :json

        expect(response.status).to eq 422
        expect(company.users.count).to eq 0
      end

      it 'returns 409 if user already exists' do
        create(:user, email: 'new@example.com', company: company)

        post :create, params: {
          name: {
            givenName: 'Not New',
            familyName: 'User'
          },
          emails: [
            {
              value: 'new@example.com'
            }
          ]
        }, as: :json

        expect(response.status).to eq 409
        expect(company.users.count).to eq 1
      end

      it 'creates and archives inactive user' do
        post :create, params: {
          id: 1,
          userName: 'test@example.com',
          name: {
            givenName: 'Test',
            familyName: 'User'
          },
          emails: [
            {
              value: 'test@example.com'
            }
          ],
          active: 'false'
        }, as: :json

        expect(response.status).to eq 201
        expect(company.users.count).to eq 1
        user = company.users.first
        expect(user.archived?).to eq true
      end
    end
  end
end
