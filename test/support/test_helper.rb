if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'minitest/autorun'
require 'webmock/minitest'

require 'json-schema'

Dir[File.join(File.expand_path('../', __FILE__), '*.rb')].each do |support_file|
  require support_file unless support_file == __FILE__
end

class JSON::Schema::Test < Minitest::Test
  def schema_fixture_path(filename)
    File.expand_path "../schemas/#{filename}", __dir__
  end

  def data_fixture_path(filename)
    File.expand_path "../data/#{filename}", __dir__
  end

  def assert_valid(schema, data, options = {}, msg = "#{data.inspect} should be valid for schema:\n#{schema.inspect}")
    errors = validation_errors(schema, data, options)

    assert_empty errors, message
  end

  def assert_validate(schema, data,
                      message = "#{data.inspect} should be valid for:\n#{schema.inspect}",
                      options: {})
    valid = JSON::Validator.validate schema, data, options

    assert valid, message
  end

  def refute_valid(schema, data, options = {}, msg = "#{data.inspect} should be invalid for schema:\n#{schema.inspect}")
    errors = validation_errors(schema, data, options)
    refute_equal([], errors, msg)
  end

  def refute_validate(schema, data,
                      message = "#{data.inspect} should be valid for:\n#{schema.inspect}",
                      options: {})
    valid = JSON::Validator.validate schema, data, options

    refute valid, message
  end

  def validation_errors(schema, data, options)
    options = { :clear_cache => true, :validate_schema => true }.merge(options)
    JSON::Validator.fully_validate(schema, data, options)
  end
end
