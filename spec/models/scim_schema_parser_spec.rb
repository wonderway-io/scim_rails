require 'spec_helper'

RSpec.describe ScimRails::ScimSchemaParser do
  before(:each) do
    allow(ScimRails::ScimSchemaParser).to receive(:returned_schema)
      .and_return(
        schemas: ['urn:ietf:params:scim:schemas:core:2.0:User'],
        id: :id,
        userName: :email,
        name: {
          givenName: :first_name,
          familyName: :last_name
        },
        emails: [
          {
            value: :email
          }
        ],
        active: :unarchived?,
        'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User': {
          division: :team
        }
      )

    allow(ScimRails::ScimSchemaParser).to receive(:mutable_schema)
      .and_return(
        name: {
          givenName: :first_name,
          familyName: :last_name
        },
        emails: [
          {
            value: :email
          }
        ]
      )
  end

  it 'ignores a schema attribute' do
    expect(ScimRails::ScimSchemaParser.schema.pluck(:name)).not_to include(
      :'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'
    )
  end

  it 'does not return subAttributes for a non complex field' do
    username = ScimRails::ScimSchemaParser.schema
      .find { |attribute| attribute[:name] == :userName }

    expect(username).not_to include :subAttributes
  end

  it 'parses a method attribute by looking at the default value' do
    parsed = ScimRails::ScimSchemaParser.parse_attribute(:active, :unarchived?)
    expect(parsed).to eq(
      name: :active,
      description: 'Active',
      type: :boolean,
      multiValued: false,
      required: false,
      caseExact: true,
      mutability: :readOnly,
      returned: :always,
      uniqueness: :none
    )
  end

  it 'parses a simple attribute correctly' do
    parsed = ScimRails::ScimSchemaParser.parse_attribute(:userName, :email)
    expect(parsed).to eq(
      name: :userName,
      description: 'Username',
      type: :string,
      multiValued: false,
      required: true,
      caseExact: true,
      mutability: :readOnly,
      returned: :always,
      uniqueness: :server
    )
  end

  it 'parses attribute within an array correctly' do
    parsed = ScimRails::ScimSchemaParser.parse_attribute(:emails,
      [value: :email]
    )
    expect(parsed).to eq(
      name: :emails,
      description: 'Emails',
      type: :complex,
      subAttributes: [
        {
          name: :value,
          description: 'Value',
          type: :string,
          multiValued: false,
          required: true,
          caseExact: true,
          mutability: :readWrite,
          returned: :always,
          uniqueness: :server
        }
      ],
      multiValued: true,
      required: true,
      caseExact: true,
      mutability: :readWrite,
      returned: :always,
      uniqueness: :none
    )
  end

  it 'parses a complex attribute correctly' do
    parsed = ScimRails::ScimSchemaParser.parse_attribute(:name,
      givenName: :first_name,
      familyName: :last_name
    )

    expect(parsed).to eq(
      name: :name,
      description: 'Name',
      type: :complex,
      subAttributes: [
        {
          name: :givenName,
          description: 'Givenname',
          type: :string,
          multiValued: false,
          required: true,
          caseExact: true,
          mutability: :readWrite,
          returned: :always,
          uniqueness: :none
        },
        {
          name: :familyName,
          description: 'Familyname',
          type: :string,
          multiValued: false,
          required: true,
          caseExact: true,
          mutability: :readWrite,
          returned: :always,
          uniqueness: :none
        }
      ],
      multiValued: false,
      required: true,
      caseExact: true,
      mutability: :readWrite,
      returned: :always,
      uniqueness: :none
    )
  end
end
