module ScimRails::ScimPathParser
  def self.attribute_for(path,
    schema = ScimRails.config.mutable_user_attributes_schema
  )
    return nil if path.nil?

    steps =
      if path.include?(':')
        sub_schema, _, path = path.rpartition(':')
        [sub_schema] + path.split('.')
      else
        path.split('.')
      end

    schema.deep_symbolize_keys
    steps.inject(schema) do |object, step|
      next nil if object.nil?

      _, key, filter = step.match(/^(.*?)(\[.+\])?$/).to_a
      values = object[key.to_sym]
      next nil if values.nil?

      if values.is_a?(Array)
        if filter
          _, field, _, value = filter.match(/\[(.*?)\s(.*?)\s(.*?)\]/).to_a
          value = value.gsub('\"', '').to_sym
          values.find { |v| v[field.to_sym] == value }
        else
          values[0]
        end
      else
        values
      end
    end
  end

  # `path_for` is a recursive method used to find the "path" for
  # `.dig` to take when looking for a given attribute in the
  # params. It applies a depth first traversion of the
  # `mutable_user_attributes_schema` object to find the attribute.
  #
  # Example: `path_for(:given_name)` should return an array that looks
  # like [:names, 0, :givenName]. `.dig` can then use that path
  # against the params to translate the :name attribute to "John".
  def self.path_for(attribute,
    object = ScimRails.config.mutable_user_attributes_schema,
    path = []
  )
    at_path = path.empty? ? object : object.dig(*path)
    return path if at_path == attribute

    case at_path
    when Hash
      at_path.each do |key, _|
        found_path = path_for(attribute, object, [*path, key])
        return found_path if found_path
      end
      nil
    when Array
      at_path.each_with_index do |_, index|
        found_path = path_for(attribute, object, [*path, index])
        return found_path if found_path
      end
      nil
    end
  end
end
