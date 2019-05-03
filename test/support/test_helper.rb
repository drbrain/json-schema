if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'minitest/autorun'
require 'webmock/minitest'

$LOAD_PATH.unshift(File.expand_path('../../../lib', __FILE__))
require 'json-schema'

Dir[File.join(File.expand_path('../', __FILE__), '*.rb')].each do |support_file|
  require support_file unless support_file == __FILE__
end

class JSON::Schema::Test < Minitest::Test
  def suppress_warnings
    old_verbose = $VERBOSE
    $VERBOSE = nil
    begin
      yield
    ensure
      $VERBOSE = old_verbose
    end
  end

  def schema_fixture_path(filename)
    File.join(File.dirname(__FILE__), '../schemas', filename)
  end

  def data_fixture_path(filename)
    File.join(File.dirname(__FILE__), '../data', filename)
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
