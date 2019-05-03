require_relative "support/test_helper"

class MinItemsTest < JSON::Schema::Test
  def test_minitems_nils
    schema = {
      "type" => "array",
      "minItems" => 1,
      "items" => { "type" => "object" }
    }

    errors = JSON::Validator.fully_validate(schema, [nil])

    assert_equal errors.length, 1
    error = errors.first

    refute_match "minimum", error
    assert_match "null", error
  end
end
