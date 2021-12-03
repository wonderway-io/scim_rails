require 'spec_helper'

RSpec.describe ScimRails::ScimPathParser do
  let(:user_schema) do
    {
      title: :job,
      name: {
        givenName: :first_name,
        familyName: :last_name
      },
      emails: [
        {
          type: :work,
          value: :email
        }
      ],
      'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User': {
        employeeNumber: :employee_id
      }
    }
  end

  describe 'attribute_for' do
    it 'with a different schema' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' \
        ':employeeNumber',
        user_schema
      )
      expect(attribute).to eq :employee_id
    end

    it 'with a filter' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        'emails[type eq \"work\"].value',
        user_schema
      )
      expect(attribute).to eq :email
    end

    it 'when filter not present in schema' do
      user_schema[:emails][0].delete :type
      attribute = ScimRails::ScimPathParser.attribute_for(
        'emails[type eq \"work\"].value',
        user_schema
      )
      expect(attribute).to be_nil
    end

    it 'with a not found filter' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        'emails[type eq \"something\"].value',
        user_schema
      )
      expect(attribute).to be_nil
    end

    it 'with a nested path' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        'name.givenName',
        user_schema
      )
      expect(attribute).to eq :first_name
    end

    it 'with a nested path that has not been found' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        'name.somethingElse',
        user_schema
      )
      expect(attribute).to be_nil
    end

    it 'with a simple path' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        'title',
        user_schema
      )
      expect(attribute).to eq :job
    end

    it 'with no path' do
      attribute = ScimRails::ScimPathParser.attribute_for(
        nil,
        user_schema
      )
      expect(attribute).to eq nil
    end
  end

  describe 'path_for' do
    it 'no attribute' do
      path = ScimRails::ScimPathParser.path_for(nil, user_schema)
      expect(path).to be_nil
    end

    it 'with a nested attribute' do
      path = ScimRails::ScimPathParser.path_for(:first_name, user_schema)
      expect(path).to eq [:name, :givenName]
    end

    it 'with an attribute that is not present' do
      path = ScimRails::ScimPathParser.path_for(:middle_name, user_schema)
      expect(path).to be_nil
    end

    it 'with an attribute inside an array' do
      path = ScimRails::ScimPathParser.path_for(:email, user_schema)
      expect(path).to eq [:emails, 0, :value]
    end
  end
end
