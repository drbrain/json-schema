class JSON::Schema::SchemaMissing < JSON::Schema::SchemaError
  ##
  # The name of the schema that was not found

  attr_reader :name

  ##
  # The URI of the schema that was not found

  attr_reader :uri

  ##
  # Raised when a schema could not be found at either a +name+ or +uri+.  Both
  # are not allowed.

  def initialize(name: nil, uri: nil)
    raise ArgumentError, "Provide either name or uri, not both" if name and uri
    raise ArgumentError, "Provide either name or uri" unless name or uri

    @uri = uri
    @name = name

    super ""
  end

  def message # :nodoc:
    if @name
      "Unable to find a schema matching #{@name}"
    else
      <<-MESSAGE
Unable to find a schema for URI:

\t#{@uri}
      MESSAGE
    end
  end
end
