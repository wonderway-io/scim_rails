require 'spec_helper'

RSpec.describe ScimRails::ScimUsersController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe 'show' do
    let(:company) { create(:company) }

    context 'when unauthorized' do
      it 'returns scim+json content type' do
        get :show, params: { id: 1 }, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'fails with no credentials' do
        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end

      it 'fails with invalid credentials' do
        request.env['HTTP_AUTHORIZATION'] =
          ActionController::HttpAuthentication::Basic.encode_credentials(
            'unauthorized', '123456'
          )

        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when authorized' do
      before :each do
        http_login(company)
      end

      it 'returns scim+json content type' do
        get :show, params: { id: 1 }, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'is successful with valid credentials' do
        create(:user, id: 1, company: company)
        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 200
      end

      it 'returns :not_found for id that cannot be found' do
        get :show, params: { id: 'fake_id' }, as: :json

        expect(response.status).to eq 404
      end

      it 'returns :not_found for a correct id but unauthorized company' do
        new_company = create(:company)
        create(:user, company: new_company, id: 1)

        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 404
      end
    end
  end
end
