class JSON::Schema::UnknownBackend < JSON::Schema::Error
  ##
  # The unknown backend

  attr_reader :backend

  ##
  # Raised when the user tries to use a JSON +backend+ that is not known

  def initialize(backend)
    @backend = backend

    super <<-MESSAGE
The JSON backend "#{backend}" is not known

The following backends are available:
\t#{JSON::Validator.available_json_backends.join "\n\t"}
    MESSAGE
  end
end
