class JSON::Schema::JsonParseError < JSON::Schema::Error

  ##
  # The JSON parsing backend

  attr_reader :backend

  ##
  # The JSON input sent to the parser

  attr_reader :input

  ##
  # Creates a new JsonParseError that was trying to parse +input+ using
  # +backend+.

  def initialize(input, backend)
    @input   = input
    @backend = backend

    super ""
  end

  def message # :nodoc:
    <<-MESSAGE
Failed to parse JSON using #{backend}:

\t#{cause.message}
    MESSAGE
  end
end
