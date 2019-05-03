#!/usr/bin/env ruby
### http://mput.dip.jp/mput/uuid.txt

# Copyright(c) 2005 URABE, Shyouhei.
#
# Permission is hereby granted, free of  charge, to any person obtaining a copy
# of  this code, to  deal in  the code  without restriction,  including without
# limitation  the rights  to  use, copy,  modify,  merge, publish,  distribute,
# sublicense, and/or sell copies of the code, and to permit persons to whom the
# code is furnished to do so, subject to the following conditions:
#
#        The above copyright notice and this permission notice shall be
#        included in all copies or substantial portions of the code.
#
# THE  CODE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND, EXPRESS  OR
# IMPLIED,  INCLUDING BUT  NOT LIMITED  TO THE  WARRANTIES  OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE  AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHOR  OR  COPYRIGHT  HOLDER BE  LIABLE  FOR  ANY  CLAIM, DAMAGES  OR  OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF  OR IN CONNECTION WITH  THE CODE OR THE  USE OR OTHER  DEALINGS IN THE
# CODE.
#
# 2009-02-20:  Modified by Pablo Lorenzoni <pablo@propus.com.br>  to  correctly
# include the version in the raw_bytes.


require 'digest/md5'
require 'digest/sha1'
require 'tmpdir'

module JSON::Util

  # Pure ruby UUID generator, which is compatible with RFC4122
  UUID = Struct.new :raw_bytes

end

class JSON::Util::UUID
  private_class_method :new

  class << self
    def mask v, str # :nodoc
      nstr = str.bytes.to_a
      version = [0, 16, 32, 48, 64, 80][v]
      nstr[6] &= 0b00001111
      nstr[6] |= version
      nstr[8] &= 0b00111111
      nstr[8] |= 0b10000000
      str = ''
      nstr.each { |s| str << s.chr }
      str
    end

    private :mask

    # v5 UUID generation (using SHA1).
    # Namespace object is another UUID, json-schema only uses one to generate
    # URNs for schemas.
    def create_v5 str, namespace
      sha1 = Digest::SHA1.new
      sha1.update namespace.raw_bytes
      sha1.update str
      sum = sha1.digest
      raw = mask 5, sum[0..15]
      ret = new raw
      ret.freeze
      ret
    end

    # hexadecimal dump into 16-octet object.
    def parse obj
      str = obj.to_s.sub %r/\Aurn:uuid:/, ''
      str.gsub! %r/[^0-9A-Fa-f]/, ''
      raw = str[0..31].lines.to_a.pack 'H*'
      ret = new raw
      ret.freeze
      ret
    end
  end

  # The 'primitive deconstructor'
  def unpack
    raw_bytes.unpack "NnnCCa6"
  end

  def inspect
    "#<JSON::Util::UUID #{to_s}>"
  end

  # Generate the string representation (a.k.a GUID) of this UUID
  def to_s
    a = unpack
    tmp = a[-1].unpack 'C*'
    a[-1] = sprintf '%02x%02x%02x%02x%02x%02x', *tmp
    "%08x-%04x-%04x-%02x%02x-%s" % a
  end
  alias guid to_s

  # Convert into a RFC4122-comforming URN representation
  def to_uri
    "urn:uuid:" + self.to_s
  end
  alias urn to_uri

  # Convert into 128-bit unsigned integer
  def to_int
    tmp = self.raw_bytes.unpack "C*"
    tmp.inject do |r, i|
      r * 256 | i
    end
  end
  alias to_i to_int

  # Gets the version of this UUID
  # returns nil if bad version
  def version
    a = unpack
    v = (a[2] & 0xF000).to_s(16)[0].chr.to_i
    return v if (1..5).include? v
    return nil
  end

  # Two  UUIDs  are  said  to  be  equal if  and  only  if  their  (byte-order
  # canonicalized) integer representations are equivallent.  Refer RFC4122 for
  # details.
  def == other
    to_i == other.to_i
  end

  include Comparable
  # UUIDs are comparable (don't know what benefits are there, though).
  def <=> other
    to_s <=> other.to_s
  end

  NAMESPACE = parse "8c4c3f97-c108-40a9-9f1a-93f94f825c76"
end
