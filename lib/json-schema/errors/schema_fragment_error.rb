class JSON::Schema::SchemaFragmentError < JSON::Schema::SchemaError
  ##
  # Complete fragment reference in the +schema+

  attr_accessor :fragment

  ##
  # Fragment path where the error was encountered

  attr_accessor :path

  ##
  # The schema the fragment is being looked up in

  attr_accessor :schema

  def initialize(fragment, schema, path)
    @fragment = fragment
    @path     = path
    @schema   = schema

    super ""
  end

  def message # :nodoc:
    path_string = "#/#{@path.join "/"}"

    message = <<-MESSAGE
Unable to determine schema referenced by fragment at:

\t#{path_string}

For schema:

#{schema_dump}
    MESSAGE

    if path_string != @fragment
      message << <<-FULL_FRAGMENT

Full fragment:

\t#{fragment}
      FULL_FRAGMENT
    end

    message
  end

  def schema_dump # :nodoc:
    case @schema
    when JSON::Schema
      "\t#{@schema.uri}"
    else
      "\t#{@schema.inspect}"
    end
  end
end
