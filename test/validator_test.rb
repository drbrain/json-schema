require_relative "support/test_helper"

class ValidatorTest < JSON::Schema::Test
  def test_json_backend_equals_nonexistent
    e = assert_raises JSON::Schema::NonexistentBackend do
      JSON::Validator.json_backend = "nonexistent"
    end

    assert_equal "nonexistent", e.backend

    if defined? MultiJson
      assert_match "not available to MultiJson", e.message
    else
      assert_match %r/\t(json|yajl)/, e.message
    end
  end
end
