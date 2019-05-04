class JSON::Schema::NonexistentBackend < JSON::Schema::Error
  ##
  # The nonexistent backend

  attr_reader :backend

  ##
  # Raised when the user tries to use a JSON +backend+ that does not exist

  def initialize(backend)
    @backend = backend

    message =
      if defined? MultiJson
        <<-MESSAGE
The JSON backend "#{backend}" is not available to MultiJson
        MESSAGE
      else
        <<-MESSAGE
The JSON backend "#{backend}" does not exist

The following backends are available:
\t#{JSON::Validator.available_json_backends.join "\n\t"}
        MESSAGE
      end

    super message
  end
end
