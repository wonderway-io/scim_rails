module ScimRails::ScimSchemaParser
  def self.returned_schema
    ScimRails.config.user_schema
  end

  def self.mutable_schema
    ScimRails.config.mutable_user_attributes_schema
  end

  def self.user_class
    ScimRails.config.scim_users_model
  end

  def self.required?(key)
    user_class
      .validators_on(key)
      .map(&:class)
      .include?(ActiveRecord::Validations::PresenceValidator)
  end

  def self.unique?(key)
    user_class
      .validators_on(key)
      .map(&:class)
      .include?(ActiveRecord::Validations::UniquenessValidator)
  end

  def self.mutability_deferred(sub_attributes)
    sub_mutability = sub_attributes.pluck :mutability
    are_read_write_able = sub_mutability.include? :readWrite
    are_readable = sub_mutability.include? :readOnly
    are_writable = sub_mutability.include? :writeOnly

    if are_read_write_able || (are_readable && are_writable)
      :readWrite
    elsif are_writable
      :writeOnly
    else
      :readOnly
    end
  end

  # "readOnly", "readWrite", "writeOnly", ("immutable")
  def self.mutability(path)
    is_mutable = mutable_schema.dig(*path)
    is_returned = returned_schema.dig(*path)
    if is_mutable && is_returned
      :readWrite
    elsif is_mutable
      :writeOnly
    else
      :readOnly
    end
  end

  # Possible types according to scim reference:
  # string", "boolean", "decimal", "integer", "dateTime", "reference",
  # "complex".
  def self.column_to_type(column_type)
    # Possible values in rails (db agnositc):
    # primary_key, :string, :text, :integer, :bigint, :float, :decimal,
    # :numeric, :datetime, :time, :date, :binary, :boolean
    case column_type.to_sym
    when :primary_key, :integer, :bigint
      :integer
    when :float, :decimal, :numeric
      :deciman
    when :datetime, :date, :time
      :dateTime
    when :boolean, :binary
      :boolean
    else
      :string
    end
  end

  def self.value_to_type(value)
    datetime_classes = [Date, DateTime, Time, ActiveSupport::TimeWithZone]
    if [true, false].include? value
      :boolean
    elsif value.is_a? Float
      :decimal
    elsif value.is_a? Integer
      :integer
    elsif datetime_classes.include?(value.class)
      :datetime
    else
      :string
    end
  end

  def self.parse_attribute(key, value, path = [])
    column = value.is_a?(Array) ? value.first : value
    type =
      if value.is_a?(Hash) || (value.is_a?(Array) && value.first.is_a?(Hash))
        :complex
      elsif user_class.columns_hash[column.to_s].present?
        column_to_type user_class.columns_hash[column.to_s].type
      else
        value_to_type user_class.new.public_send(column)
      end

    sub_attributes =
      if type != :complex
        nil
      elsif value.is_a?(Hash)
        value.map do |sub_key, sub_value|
          parse_attribute(sub_key, sub_value, [*path, key])
        end
      elsif value.is_a?(Array)
        value.first.map do |sub_key, sub_value|
          parse_attribute(sub_key, sub_value, [*path, key, 0])
        end
      end

    {
      # actual name
      name: key,
      # humanized name
      description: key.to_s.humanize,
      # string", "boolean", "decimal", "integer", "dateTime", "reference",
      # "complex".
      type: type,
      # if complex
      subAttributes: sub_attributes,
      # if array
      multiValued: value.is_a?(Array),
      # bool
      required:
        if type == :complex
          sub_attributes.any? { |attribute| attribute[:required] }
        else
          required?(column)
        end,
      # bool
      caseExact: true,
      # "readOnly", "readWrite", "writeOnly", ("immutable")
      mutability:
        if type == :complex
          mutability_deferred(sub_attributes)
        else
          mutability([*path, key])
        end,
      # "always", "never", ("default", "request")
      returned: returned_schema.dig(*path, key) ? :always : :never,
      # "none", "server", "global"
      uniqueness:
        if type != :complex
          unique?(column) ? :server : :none
        else
          :none
        end

      # not needed / implemented
      # canonicalValues: # possible values? e.g. ["work" and "home"] OPTIONAL
      # referenceTypes: # type of reference not supported
    }.compact
  end

  def self.extra_schema_types
    returned_schema
      .deep_merge(mutable_schema)
      .keys
      .select { |key| key.to_s.include?(':') }
  end

  def self.schema(id = nil)
    complete_schema = returned_schema
      .deep_merge(mutable_schema)
      .except(:schemas, :meta)

    complete_schema = complete_schema[id.to_sym] if id.present?
    return [] if complete_schema.nil?

    complete_schema
      .map { |key, value| parse_attribute(key, value) }
      .reject { |attribute| attribute[:name].to_s.include?(':') }
  end
end
