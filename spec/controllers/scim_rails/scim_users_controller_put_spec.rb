require 'spec_helper'

RSpec.describe ScimRails::ScimUsersController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  def put_params(active: true)
    {
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
      active: active
    }
  end

  describe 'put update' do
    let(:company) { create(:company) }

    context 'when unauthorized' do
      it 'returns scim+json content type' do
        put :put, params: { id: 1 }, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'fails with no credentials' do
        put :put, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end

      it 'fails with invalid credentials' do
        request.env['HTTP_AUTHORIZATION'] =
          ActionController::HttpAuthentication::Basic.encode_credentials(
            'unauthorized', '123456'
          )

        put :put, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when authorized' do
      let!(:user) { create(:user, id: 1, company: company) }

      before :each do
        http_login(company)
      end

      it 'returns scim+json content type' do
        put :put, params: put_params, as: :json

        expect(response.media_type).to eq 'application/scim+json'
      end

      it 'is successful with with valid credentials' do
        put :put, params: put_params, as: :json

        expect(response.status).to eq 200
      end

      it 'deprovisions an active record' do
        request.content_type = 'application/scim+json'
        put :put, params: put_params(active: false), as: :json

        expect(response.status).to eq 200
        expect(user.reload.active?).to eq false
      end

      it 'reprovisions an inactive record' do
        user.archive!
        expect(user.reload.active?).to eq false
        request.content_type = 'application/scim+json'
        put :put, params: put_params(active: true), as: :json

        expect(response.status).to eq 200
        expect(user.reload.active?).to eq true
      end

      it 'returns :not_found for id that cannot be found' do
        put :put, params: { id: 'fake_id' }, as: :json

        expect(response.status).to eq 404
      end

      it 'returns :not_found for a correct id but unauthorized company' do
        new_company = create(:company)
        create(:user, company: new_company, id: 1000)

        put :put, params: { id: 1000 }, as: :json

        expect(response.status).to eq 404
      end

      it 'is returns 422 with incomplete request' do
        put :put, params: {
          id: 1,
          userName: 'test@example.com',
          emails: [
            {
              value: 'test@example.com'
            }
          ],
          active: 'true'
        }, as: :json

        expect(response.status).to eq 422
      end
    end
  end
end
