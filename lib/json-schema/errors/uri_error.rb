class JSON::Schema::UriError < JSON::Schema::Error
  ##
  # URI there was an error for.  May not be any type of URI object

  attr_reader :uri

  ##
  # Raised when there was an error with +uri+

  def initialize(uri)
    @uri = uri

    super ""
  end

  def message # :nodoc:
    <<-MESSAGE
Error handling #{@uri} due to:

\t#{cause.message}
    MESSAGE
  end
end
