require_relative "support/test_helper"

class UriUtilTest < JSON::Schema::Test
  include JSON::Util::URI

  def teardown
    clear_cache
  end

  def test_normalized_uri
    str = "https://www.google.com/search"
    uri = Addressable::URI.new(scheme: 'https',
                               host: 'www.google.com',
                               path: 'search')
    assert_equal uri, normalized_uri(str, '/home')
  end

  def test_normalized_uri_with_empty_fragment
    str = "https://www.google.com/search#"
    uri = Addressable::URI.new(scheme: 'https',
                               host: 'www.google.com',
                               path: 'search',
                               fragment: nil)
    assert_equal uri, normalized_uri(str, '/home')
  end

  def test_normalized_uri_with_fragment
    str = "https://www.google.com/search#foo"
    uri = Addressable::URI.new(scheme: 'https',
                               host: 'www.google.com',
                               path: 'search',
                               fragment: 'foo')
    assert_equal uri, normalized_uri(str, '/home')
  end

  def test_normalized_uri_for_absolute_path
    str = "/foo/bar.json"
    uri = Addressable::URI.new(scheme: 'file',
                               host: '',
                               path: '/foo/bar.json')
    assert_equal uri, normalized_uri(str, '/home')
  end

  def test_normalized_uri_for_relative_path
    str = "foo/bar.json"
    uri = Addressable::URI.new(scheme: 'file',
                               host: '',
                               path: '/home/foo/bar.json')
    assert_equal uri, normalized_uri(str, '/home')

    uri = Addressable::URI.new(scheme: 'file',
                               host: '',
                               path: '/other/foo/bar.json')
    assert_equal uri, normalized_uri(str, '/other')
  end

  def test_normalized_uri_for_file_path_with_host
    str = "file://localhost/foo/bar.json"
    uri = Addressable::URI.new(scheme: 'file',
                               host: 'localhost',
                               path: '/foo/bar.json')
    assert_equal uri, normalized_uri(str, '/home')
  end

  def test_uri_parse
    str = "https://www.google.com/search"
    uri = Addressable::URI.new(scheme: 'https',
                               host: 'www.google.com',
                               path: 'search')
    assert_equal uri, parse(str)
  end

  def test_invalid_uri_parse
    uri = ":::::::"
    assert_raises(JSON::Schema::UriError) do
      parse(uri)
    end
  end

  def test_parse_cache
    cached_uri = parse('foo')

    assert_equal(cached_uri, parse('foo'))

    clear_cache

    refute_same cached_uri, parse('foo')
  end

  def test_validator_clear_cache_for_parse
    cached_uri = parse('foo')

    assert_equal(cached_uri, parse('foo'))

    validation_errors({"type" => "string"}, "foo", :clear_cache => true)

    refute_same cached_uri, parse('foo')
  end

  def test_ref_fragment_path
    uri = '#some-thing'
    base = 'http://www.example.com/foo/#bar'

    assert_equal uri('http://www.example.com/foo/#some-thing'), normalize_ref(uri, base)
    assert_equal uri('http://www.example.com/foo/#'), absolutize_ref(uri, base)
  end

  def test_ref_file_path
    uri = '/some/thing'
    base = 'http://www.example.com/foo/#bar'

    assert_equal uri('http://www.example.com/some/thing#'), normalize_ref(uri, base)
    assert_equal uri('http://www.example.com/some/thing#'), absolutize_ref(uri, base)
  end

  def test_ref_uri
    uri = 'http://foo-bar.com'
    base = 'http://www.example.com/foo/#bar'

    assert_equal uri('http://foo-bar.com/#'), normalize_ref(uri, base)
    assert_equal uri('http://foo-bar.com/#'), absolutize_ref(uri, base)
  end

  def test_ref_uri_with_path
    uri = 'http://foo-bar.com/some/thing'
    base = 'http://www.example.com/foo/#bar'

    assert_equal uri('http://foo-bar.com/some/thing#'), normalize_ref(uri, base)
    assert_equal uri('http://foo-bar.com/some/thing#'), absolutize_ref(uri, base)
  end

  def test_ref_uri_with_fragment
    uri = 'http://foo-bar.com/some/thing#foo'
    base = 'http://www.example.com/hello/#world'

    assert_equal uri('http://foo-bar.com/some/thing#foo'), normalize_ref(uri, base)
    assert_equal uri('http://foo-bar.com/some/thing#'), absolutize_ref(uri, base)
  end

  def test_ref_uri_with_fragment_and_base_with_no_fragment
    uri = 'http://foo-bar.com/some/thing#foo'
    base = 'http://www.example.com/hello'

    assert_equal uri('http://foo-bar.com/some/thing#foo'), normalize_ref(uri, base)
    assert_equal uri('http://foo-bar.com/some/thing#'), absolutize_ref(uri, base)
  end

  def test_ref_relative_path
    uri = 'hello/world'
    base = 'http://www.example.com/foo/#bar'

    assert_equal uri('http://www.example.com/foo/hello/world#'), normalize_ref(uri, base)
    assert_equal uri('http://www.example.com/foo/hello/world#'), absolutize_ref(uri, base)
  end

  def test_ref_addressable_uri_with_host
    uri = Addressable::URI.new(:host => 'foo-bar.com')
    base = 'http://www.example.com/hello/#world'

    assert_equal uri('http://www.example.com/foo-bar.com#'), normalize_ref(uri, base)
    assert_equal uri('http://www.example.com/hello/#world'), absolutize_ref(uri, base)
  end

  def test_ref_addressable_uri_with_host_and_path
    uri = Addressable::URI.new(:host => 'foo-bar.com', :path => '/hello/world')
    base = 'http://www.example.com/a/#b'

    assert_equal uri('http://www.example.com/foo-bar.com/hello/world#'), normalize_ref(uri, base)
    assert_equal uri('http://www.example.com/hello/world'), absolutize_ref(uri, base)
  end

  def test_ref_addressable_uri_with_shceme_host_and_path
    uri = Addressable::URI.new(:scheme => 'https', :host => 'foo-bar.com', :path => '/hello/world')
    base = 'http://www.example.com/a/#b'

    assert_equal uri('https://foo-bar.com/hello/world#'), normalize_ref(uri, base)
    assert_equal uri('https://foo-bar.com/hello/world'), absolutize_ref(uri, base)
  end
end
