require 'spec_helper'

RSpec.describe ScimRails::ScimUsersController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe 'index' do
    let(:company) { create(:company) }

    context 'when unauthorized' do
      it 'returns scim+json content type' do
        get :index, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'fails with no credentials' do
        get :index, as: :json

        expect(response.status).to eq 401
      end

      it 'fails with invalid credentials' do
        request.env['HTTP_AUTHORIZATION'] =
          ActionController::HttpAuthentication::Basic.encode_credentials(
            'unauthorized', '123456'
          )

        get :index, as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when when authorized' do
      before :each do
        http_login(company)
      end

      it 'returns scim+json content type' do
        get :index, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'is successful with valid credentials' do
        get :index, as: :json

        expect(response.status).to eq 200
      end

      it 'returns all results' do
        create_list(:user, 10, company: company)

        get :index, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body.dig('schemas',
          0
        )
              ).to eq 'urn:ietf:params:scim:api:messages:2.0:ListResponse'
        expect(response_body['totalResults']).to eq 10
      end

      it 'defaults to 100 results' do
        create_list(:user, 300, company: company)

        get :index, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 300
        expect(response_body['Resources'].count).to eq 100
      end

      it 'paginates results' do
        create_list(:user, 400, company: company)
        expect(company.users.first.id).to eq 1

        get :index, params: {
          startIndex: 101,
          count: 200
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 400
        expect(response_body['Resources'].count).to eq 200
        expect(response_body.dig('Resources', 0, 'id')).to eq 101
      end

      it 'paginates results by configurable scim_users_list_order' do
        allow(ScimRails.config).to(
          receive(:scim_users_list_order).and_return({ created_at: :desc })
        )

        create_list(:user, 400, company: company)
        expect(company.users.first.id).to eq 1

        get :index, params: {
          startIndex: 1,
          count: 10
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 400
        expect(response_body['Resources'].count).to eq 10
        expect(response_body.dig('Resources', 0, 'id')).to eq 400
      end

      it 'filters results by provided email filter' do
        create(:user, email: 'test1@example.com', company: company)
        create(:user, email: 'test2@example.com', company: company)

        get :index, params: {
          filter: 'email eq test1@example.com'
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 1
        expect(response_body['Resources'].count).to eq 1
      end

      it 'applies filters on attributes if specified' do
        allow(ScimRails.config).to(
          receive(:user_attribute_filters)
          .and_return({ email: :downcase })
        )

        create(:user, email: 'test1@example.com', company: company)
        create(:user, email: 'test2@example.com', company: company)

        get :index, params: {
          filter: 'email eq TeSt1@example.com'
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 1
        expect(response_body['Resources'].count).to eq 1
      end

      it 'applies filters on attributes if specified (callback)' do
        allow(ScimRails.config).to(
          receive(:user_attribute_filters)
          .and_return({ email: ->(email) { email.downcase } })
        )

        create(:user, email: 'test1@example.com', company: company)
        create(:user, email: 'test2@example.com', company: company)

        get :index, params: {
          filter: 'email eq TeSt1@example.com'
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 1
        expect(response_body['Resources'].count).to eq 1
      end

      it 'filters results by provided name filter' do
        create(:user, first_name: 'Chidi', last_name: 'Anagonye',
                      company: company
        )
        create(:user, first_name: 'Eleanor', last_name: 'Shellstrop',
                      company: company
        )

        get :index, params: {
          filter: 'familyName eq Shellstrop'
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 1
        expect(response_body['Resources'].count).to eq 1
      end

      it 'returns no results for unfound filter parameters' do
        get :index, params: {
          filter: 'familyName eq fake_not_there'
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body['totalResults']).to eq 0
        expect(response_body['Resources'].count).to eq 0
      end

      it 'returns no results for undefined filter queries' do
        get :index, params: {
          filter: 'address eq 101 Nowhere USA'
        }, as: :json
        expect(response.status).to eq 400
        response_body = JSON.parse(response.body)
        expect(response_body.dig('schemas',
          0
        )
              ).to eq 'urn:ietf:params:scim:api:messages:2.0:Error'
      end
    end
  end
end
