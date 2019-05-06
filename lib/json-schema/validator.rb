require 'open-uri'
require 'pathname'
require 'bigdecimal'
require 'digest/sha1'
require 'date'
require 'thread'
require 'yaml'

require 'json-schema/schema/reader'
require 'json-schema/util/uri'
require 'json-schema/util/uuid'

module JSON

  class Validator

    @@schemas = {}
    @@cache_schemas = true
    @@default_opts = {
      :list => false,
      :version => nil,
      :validate_schema => false,
      :record_errors => false,
      :errors_as_objects => false,
      :insert_defaults => false,
      :clear_cache => false,
      :strict => false,
      :parse_data => true
    }
    @@validators = {}
    @@default_validator = nil
    @available_json_backends = []
    @@json_backend = nil
    @@serializer = nil
    @@mutex = Mutex.new

    def initialize(schema_data, data, opts={})
      @options = @@default_opts.clone.merge(opts)
      @errors = []

      validator = self.class.validator_for_name(@options[:version])
      @options[:version] = validator
      @options[:schema_reader] ||= self.class.schema_reader

      @validation_options = @options[:record_errors] ? {:record_errors => true} : {}
      @validation_options[:insert_defaults] = true if @options[:insert_defaults]
      @validation_options[:strict] = true if @options[:strict] == true
      @validation_options[:clear_cache] = true if !@@cache_schemas || @options[:clear_cache]

      @@mutex.synchronize { @base_schema = initialize_schema(schema_data) }
      @original_data = data
      @data = initialize_data(data)
      @@mutex.synchronize { build_schemas(@base_schema) }

      # validate the schema, if requested
      if @options[:validate_schema]
        if @base_schema.schema["$schema"]
          base_validator = self.class.validator_for_name(@base_schema.schema["$schema"])
        end
        metaschema = base_validator ? base_validator.metaschema : validator.metaschema
        # Don't clear the cache during metaschema validation!
        self.class.validate!(metaschema, @base_schema.schema, {:clear_cache => false})
      end

      # If the :fragment option is set, try and validate against the fragment
      if opts[:fragment]
        @base_schema = schema_from_fragment(@base_schema, opts[:fragment])
      end
    end

    def schema_from_fragment(base_schema, fragment)
      schema_uri = base_schema.uri
      fragments = fragment.split("/")

      # ensure the first element was a hash, per the fragment spec
      if fragments.shift != "#"
        raise ArgumentError, "Invalid fragment, #{fragment.inspect} must start with \"#\""
      end

      schema = base_schema

      fragments.inject [] do |path, current|
        path << current

        case schema
        when JSON::Schema
          if !schema.schema.has_key?(current)
            raise JSON::Schema::SchemaFragmentError.new(fragment, base_schema, path)
          end
          schema = schema.schema[current]
        when Hash
          if !schema.has_key?(current)
            raise JSON::Schema::SchemaFragmentError.new(fragment, base_schema, path)
          end
          schema = JSON::Schema.new(schema[current],schema_uri,@options[:version])
        when Array
          fragment_index = current.to_i
          schema = schema[fragment_index]

          if schema.nil?
            raise JSON::Schema::SchemaFragmentError.new(fragment, base_schema, path)
          end
          schema = JSON::Schema.new(schema, schema_uri,@options[:version])
        else
          raise JSON::Schema::SchemaFragmentError.new(fragment, base_schema, path)
        end

        path
      end

      if @options[:list]
        schema.to_array_schema
      elsif schema.is_a?(Hash)
        JSON::Schema.new(schema, schema_uri, @options[:version])
      else
        schema
      end
    end

    # Run a simple true/false validation of data against a schema
    def validate
      @base_schema.validate(@data,[],self,@validation_options)

      if @options[:record_errors]
        if @options[:errors_as_objects]
          @errors.map{|e| e.to_hash}
        else
          @errors.map{|e| e.to_string}
        end
      else
        true
      end
    ensure
      if @validation_options[:clear_cache] == true
        self.class.clear_cache
      end
      if @validation_options[:insert_defaults]
        self.class.merge_missing_values(@data, @original_data)
      end
    end

    def load_ref_schema(parent_schema, ref)
      schema_uri = JSON::Util::URI.absolutize_ref(ref, parent_schema.uri)
      return true if self.class.schema_loaded?(schema_uri)

      validator = self.class.validator_for_uri(schema_uri, false)
      schema_uri = JSON::Util::URI.file_uri(validator.metaschema) if validator

      schema = @options[:schema_reader].read(schema_uri)
      self.class.add_schema(schema)
      build_schemas(schema)
    end

    # Build all schemas with IDs, mapping out the namespace
    def build_schemas(parent_schema)
      schema = parent_schema.schema

      # Build ref schemas if they exist
      if schema["$ref"]
        load_ref_schema(parent_schema, schema["$ref"])
      end

      case schema["extends"]
      when String
        load_ref_schema(parent_schema, schema["extends"])
      when Array
        schema['extends'].each do |type|
          handle_schema(parent_schema, type)
        end
      end

      # Check for schemas in union types
      ["type", "disallow"].each do |key|
        if schema[key].is_a?(Array)
          schema[key].each do |type|
            if type.is_a?(Hash)
              handle_schema(parent_schema, type)
            end
          end
        end
      end

      # Schema properties whose values are objects, the values of which
      # are themselves schemas.
      %w[definitions properties patternProperties].each do |key|
        next unless value = schema[key]
        value.each do |k, inner_schema|
          handle_schema(parent_schema, inner_schema)
        end
      end

      # Schema properties whose values are themselves schemas.
      %w[additionalProperties additionalItems dependencies extends].each do |key|
        next unless schema[key].is_a?(Hash)
        handle_schema(parent_schema, schema[key])
      end

      # Schema properties whose values may be an array of schemas.
      %w[allOf anyOf oneOf not].each do |key|
        next unless value = schema[key]
        Array(value).each do |inner_schema|
          handle_schema(parent_schema, inner_schema)
        end
      end

      # Items are always schemas
      if schema["items"]
        items = schema["items"].clone
        items = [items] unless items.is_a?(Array)

        items.each do |item|
          handle_schema(parent_schema, item)
        end
      end

      # Convert enum to a ArraySet
      if schema["enum"].is_a?(Array)
        schema["enum"] = ArraySet.new(schema["enum"])
      end

    end

    # Either load a reference schema or create a new schema
    def handle_schema(parent_schema, obj)
      if obj.is_a?(Hash)
        schema_uri = parent_schema.uri.dup
        schema = JSON::Schema.new(obj, schema_uri, parent_schema.validator)
        if obj['id']
          self.class.add_schema(schema)
        end
        build_schemas(schema)
      end
    end

    def validation_error(error)
      @errors.push(error)
    end

    def validation_errors
      @errors
    end

    if !defined?(MultiJson)
      if Gem::Specification::find_all_by_name('yajl-ruby').any?
        require 'yajl'
        @available_json_backends << 'yajl'
        @@json_backend = 'yajl'
      else
        require 'json'
        @available_json_backends << 'json'
        @@json_backend = 'json'
      end

      if @@json_backend == 'yajl'
        @@serializer = lambda{|o| Yajl::Encoder.encode(o) }
      elsif @@json_backend == 'json'
        @@serializer = lambda{|o| JSON.dump(o) }
      else
        @@serializer = lambda{|o| YAML.dump(o) }
      end
    end

    class << self
      attr_reader :available_json_backends

      def validate(schema, data,opts={})
        begin
          validate!(schema, data, opts)
        rescue JSON::Schema::ValidationError, JSON::Schema::SchemaError
          return false
        end
      end

      def validate_json(schema, data, opts={})
        validate(schema, data, opts.merge(:json => true))
      end

      def validate_uri(schema, data, opts={})
        validate(schema, data, opts.merge(:uri => true))
      end

      def validate!(schema, data,opts={})
        validator = new(schema, data, opts)
        validator.validate
      end

      def validate2(schema, data, opts={})
        warn "[DEPRECATION NOTICE] JSON::Validator#validate2 has been replaced by JSON::Validator#validate! and will be removed in version >= 3. Please use the #validate! method instead."
        validate!(schema, data, opts)
      end

      def validate_json!(schema, data, opts={})
        validate!(schema, data, opts.merge(:json => true))
      end

      def validate_uri!(schema, data, opts={})
        validate!(schema, data, opts.merge(:uri => true))
      end

      def fully_validate(schema, data, opts={})
        validate!(schema, data, opts.merge(:record_errors => true))
      end

      def fully_validate_schema(schema, opts={})
        data = schema
        schema = validator_for_name(opts[:version]).metaschema
        fully_validate(schema, data, opts)
      end

      def fully_validate_json(schema, data, opts={})
        fully_validate(schema, data, opts.merge(:json => true))
      end

      def fully_validate_uri(schema, data, opts={})
        fully_validate(schema, data, opts.merge(:uri => true))
      end

      def schema_reader
        @@schema_reader ||= JSON::Schema::Reader.new
      end

      def schema_reader=(reader)
        @@schema_reader = reader
      end

      def clear_cache
        @@schemas = {}
        JSON::Util::URI.clear_cache
      end

      def schemas
        @@schemas
      end

      def add_schema(schema)
        @@schemas[schema_key_for(schema.uri)] ||= schema
      end

      def schema_for_uri(uri)
        # We only store normalized uris terminated with fragment #, so we can try whether
        # normalization can be skipped
        @@schemas[uri] || @@schemas[schema_key_for(uri)]
      end

      def schema_loaded?(schema_uri)
        !schema_for_uri(schema_uri).nil?
      end

      def schema_key_for(uri)
        key = Util::URI.normalized_uri(uri).to_s
        key.end_with?('#') ? key : "#{key}#"
      end

      def cache_schemas=(val)
        warn "[DEPRECATION NOTICE] Schema caching is now a validation option. Schemas will still be cached if this is set to true, but this method will be removed in version >= 3. Please use the :clear_cache validation option instead."
        @@cache_schemas = val == true ? true : false
      end

      def validators
        @@validators
      end

      def default_validator
        @@default_validator
      end

      def validator_for_uri(schema_uri, raise_not_found=true)
        return default_validator unless schema_uri
        u = JSON::Util::URI.parse(schema_uri)
        validator = validators["#{u.scheme}://#{u.host}#{u.path}"]
        if validator.nil? && raise_not_found
          raise JSON::Schema::SchemaError.new("Schema not found: #{schema_uri}")
        else
          validator
        end
      end

      def validator_for_name(schema_name, raise_not_found=true)
        return default_validator unless schema_name
        schema_name = schema_name.to_s
        validator = validators.values.detect do |v|
          Array(v.names).include?(schema_name)
        end
        if validator.nil? && raise_not_found
          raise JSON::Schema::SchemaError.new("The requested JSON schema #{schema_name} is not supported")
        else
          validator
        end
      end

      def validator_for(schema_uri)
        warn "[DEPRECATION NOTICE] JSON::Validator#validator_for has been replaced by JSON::Validator#validator_for_uri and will be removed in version >= 3. Please use the #validator_for_uri method instead."
        validator_for_uri(schema_uri)
      end

      def register_validator(v)
        @@validators["#{v.uri.scheme}://#{v.uri.host}#{v.uri.path}"] = v
      end

      def register_default_validator(v)
        @@default_validator = v
      end

      def register_format_validator(format, validation_proc, versions = (@@validators.flat_map{ |k, v| v.names.first } + [nil]))
        custom_format_validator = JSON::Schema::CustomFormat.new(validation_proc)
        versions.each do |version|
          validator = validator_for_name(version)
          validator.formats[format.to_s] = custom_format_validator
        end
      end

      def deregister_format_validator(format, versions = (@@validators.flat_map{ |k, v| v.names.first } + [nil]))
        versions.each do |version|
          validator = validator_for_name(version)
          validator.formats[format.to_s] = validator.default_formats[format.to_s]
        end
      end

      def restore_default_formats(versions = (@@validators.flat_map{ |k, v| v.names.first } + [nil]))
        versions.each do |version|
          validator = validator_for_name(version)
          validator.formats = validator.default_formats.clone
        end
      end

      def json_backend
        if defined?(MultiJson)
          MultiJson.respond_to?(:adapter) ? MultiJson.adapter : MultiJson.engine
        else
          @@json_backend
        end
      end

      def json_backend=(backend)
        if defined?(MultiJson)
          backend =
            if backend == 'json'
              'json_gem'
            else
              backend
            end

          begin
            if MultiJson.respond_to? :use
              MultiJson.use backend
            else
              MultiJson.engine = backend
            end
          rescue MultiJson::AdapterError
            raise JSON::Schema::NonexistentBackend, backend
          end
        else
          backend = backend.to_s
          if @available_json_backends.include?(backend)
            @@json_backend = backend
          else
            raise JSON::Schema::NonexistentBackend, backend
          end
        end
      end

      def parse(s)
        if defined?(MultiJson)
          begin
            MultiJson.respond_to?(:adapter) ? MultiJson.load(s) : MultiJson.decode(s)
          rescue MultiJson::ParseError
            raise JSON::Schema::JsonParseError.new s, "multijson"
          end
        else
          case @@json_backend.to_s
          when 'json'
            begin
              JSON.parse(s, :quirks_mode => true)
            rescue JSON::ParserError
              raise JSON::Schema::JsonParseError.new s, @@json_backend
            end
          when 'yajl'
            begin
              json = StringIO.new(s)
              parser = Yajl::Parser.new
              parser.parse(json) or raise JSON::Schema::JsonParseError.new s, @@json_backend
            rescue Yajl::ParseError
              raise JSON::Schema::JsonParseError.new s, json_backend
            end
          else
            raise JSON::Schema::UnknownBackend, @@json_backend
          end
        end
      end

      def merge_missing_values(source, destination)
        case destination
        when Hash
          source.each do |key, source_value|
            destination_value = destination[key] || destination[key.to_sym]
            if destination_value.nil?
              destination[key] = source_value
            else
              merge_missing_values(source_value, destination_value)
            end
          end
        when Array
          source.each_with_index do |source_value, i|
            destination_value = destination[i]
            merge_missing_values(source_value, destination_value)
          end
        end
      end
    end

    private

    def serialize schema
      if defined?(MultiJson)
        MultiJson.respond_to?(:dump) ? MultiJson.dump(schema) : MultiJson.encode(schema)
      else
        @@serializer.call(schema)
      end
    end

    def fake_uri schema
      uuid = JSON::Util::UUID.create_v5 schema, JSON::Util::UUID::NAMESPACE
      uuid.to_s
    end

    def initialize_schema(schema)
      if schema.is_a?(String)
        begin
          # Build a fake URI for this
          schema_uri = JSON::Util::URI.parse(fake_uri(schema))
          schema = JSON::Schema.new(self.class.parse(schema), schema_uri, @options[:version])
          if @options[:list] && @options[:fragment].nil?
            schema = schema.to_array_schema
          end
          self.class.add_schema(schema)
        rescue JSON::Schema::JsonParseError
          # Build a uri for it
          schema_uri = Util::URI.normalized_uri(schema)
          if !self.class.schema_loaded?(schema_uri)
            schema = @options[:schema_reader].read(schema_uri)
            schema = JSON::Schema.stringify(schema)

            if @options[:list] && @options[:fragment].nil?
              schema = schema.to_array_schema
            end

            self.class.add_schema(schema)
          else
            schema = self.class.schema_for_uri(schema_uri)
            if @options[:list] && @options[:fragment].nil?
              schema = schema.to_array_schema
              schema.uri = JSON::Util::URI.parse(fake_uri(serialize(schema.schema)))
              self.class.add_schema(schema)
            end
            schema
          end
        end
      elsif schema.is_a?(Hash)
        schema_uri = JSON::Util::URI.parse(fake_uri(serialize(schema)))
        schema = JSON::Schema.stringify(schema)
        schema = JSON::Schema.new(schema, schema_uri, @options[:version])
        if @options[:list] && @options[:fragment].nil?
          schema = schema.to_array_schema
        end
        self.class.add_schema(schema)
      else
        raise JSON::Schema::SchemaParseError, "Invalid schema - must be either a string or a hash"
      end

      schema
    end

    def initialize_data(data)
      if @options[:parse_data]
        if @options[:json]
          data = self.class.parse(data)
        elsif @options[:uri]
          json_uri = Util::URI.normalized_uri(data)
          data = self.class.parse(custom_open(json_uri))
        elsif data.is_a?(String)
          begin
            data = self.class.parse(data)
          rescue JSON::Schema::JsonParseError
            begin
              json_uri = Util::URI.normalized_uri(data)
              data = self.class.parse(custom_open(json_uri))
            rescue JSON::Schema::JsonLoadError, JSON::Schema::UriError
              # Silently discard the error - use the data as-is
            end
          end
        end
      end
      JSON::Schema.stringify(data)
    end

    def custom_open(uri)
      uri = Util::URI.normalized_uri(uri) if uri.is_a?(String)
      if uri.absolute? && Util::URI::SUPPORTED_PROTOCOLS.include?(uri.scheme)
        begin
          open(uri.to_s).read
        rescue OpenURI::HTTPError, Timeout::Error
          raise JSON::Schema::JsonLoadError, uri
        end
      else
        begin
          File.read(JSON::Util::URI.unescaped_path(uri))
        rescue SystemCallError
          raise JSON::Schema::JsonLoadError, uri
        end
      end
    end
  end
end
