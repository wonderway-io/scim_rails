require 'spec_helper'

RSpec.describe ScimRails::ScimUsersController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe 'delete' do
    let(:company) { create(:company) }
    let!(:user) { create(:user, id: 1, company: company) }

    context 'when unauthorized' do
      it 'returns scim+json content type' do
        delete :delete, params: { id: 1 }, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'fails with no credentials' do
        delete :delete, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end

      it 'fails with invalid credentials' do
        request.env['HTTP_AUTHORIZATION'] =
          ActionController::HttpAuthentication::Basic.encode_credentials(
            'unauthorized', '123456'
          )

        delete :delete, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when authorized' do
      before :each do
        http_login(company)
      end

      it 'is successful with valid credentials' do
        user = company.users.first
        expect(user.active?).to be true

        delete :delete, params: { id: 1 }, as: :json

        expect(response.status).to eq 204
        expect(user.reload.active?).to be false
      end

      it 'returns 404 for invalid id' do
        delete :delete, params: { id: 123 }, as: :json

        expect(response.status).to eq 404
      end
    end
  end
end
