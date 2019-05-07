class JSON::Schema::SchemaParseError < JSON::Schema::Error
  ##
  # The schema that was not parsable

  attr_reader :schema

  ##
  # Raised when a schema cannot be parsed beyond parsing the JSON that defines
  # the schema

  def initialize(schema)
    @schema = schema

    super ""
  end

  def message
    <<-MESSAGE
Cannot parse schema of type #{@schema.class}:

#{@schema.inspect}
    MESSAGE
  end
end
