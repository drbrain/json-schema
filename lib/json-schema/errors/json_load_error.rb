class JSON::Schema::JsonLoadError < JSON::Schema::Error

  ##
  # URI json-schema tried to load JSON data from

  attr_reader :uri

  ##
  # Creates a new json-schema error to indicate loading JSON data from +uri+
  # failed.
  #
  # See #cause for further details on why loading failed

  def initialize(uri)
    @uri = uri

    super ""
  end

  def message # :nodoc:
    <<-MESSAGE
Failed to load JSON from #{@uri} due to:

\t#{cause.message}
    MESSAGE
  end
end
