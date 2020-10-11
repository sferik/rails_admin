require 'forwardable'
require 'stringio'

class FakeIO
  attr_reader :original_filename, :content_type

  def initialize(content, filename: nil, content_type: nil)
    @io = StringIO.new(content)
    @original_filename = filename
    @content_type = content_type
  end

  def self.another_version(object, version_name)
    FakeIO.new(
      "#{version_name}-#{object.read}",
      filename: "#{version_name}-#{object.original_filename}",
      content_type: object.content_type,
    )
  end

  extend Forwardable
  delegate %i[read rewind eof? close size] => :@io
end
