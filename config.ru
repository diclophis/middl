#!/usr/bin/env ruby

require "aws-sdk"
require "multipart-parser/lib/multipart_parser"
require "multipart-parser/lib/multipart_reader"

AWS_ID = ''
SECRET_KEY = ''

class MyLogger
  def method_missing(*args)
    #puts args.inspect
  end
end

AWS.config({
  :access_key_id => AWS_ID,
  :secret_access_key => SECRET_KEY,
  :logger => MyLogger.new
})

class StreamInputWrapper
  attr_accessor :stream, :content_type, :content_length, :boundary, :reader, :read_entire_content_body, :file_data_buffers, :params, :file_size, :bytes_popped
  def initialize(stream, content_type, content_length)
    self.stream = stream
    self.content_type = content_type
    self.content_length = content_length
    self.boundary = MultipartReader.extract_boundary_value(self.content_type)
    self.reader = MultipartReader.new(self.boundary)
    self.read_entire_content_body = false
    self.file_data_buffers = []
    self.params = {}
    self.file_size = 0
    self.bytes_popped = 0

    self.reader.on_error do |err|
      puts err.inspect
    end

    self.reader.on_part do |part|
      part.on_data do |data|
        if part.filename then
          self.file_data_buffers << data
          self.file_size += data.length
        else
          self.params[part.name] = data
        end
      end
      part.on_end do
        puts "end? #{part.headers.inspect}"
        self.read_entire_content_body = (self.stream.instance_variable_get("@bytes_read") == self.content_length)
      end
    end
  end
  def read(*args)
    bytes_read_this_sweep = 0
    until bytes_read_this_sweep > 0
      bytes_from_stream = self.stream.read(*args)
      break if bytes_from_stream.nil?
      self.reader.write(bytes_from_stream)
      bytes_read_this_sweep += bytes_from_stream.length
    end
    
    bytes_from_buffer = self.file_data_buffers.join("")
    self.bytes_popped += bytes_from_buffer.length

    r = bytes_from_buffer
    r = nil if eof?
    self.file_data_buffers.clear
    puts "ret: #{self.file_size} #{self.bytes_popped} #{r.class.inspect} #{r.is_a?(String) ? r.length : 0}"
    return r
  end
  def eof?
    puts "is_eof? #{self.read_entire_content_body} #{self.file_data_buffers.length == 0}"
    return self.read_entire_content_body # && (self.file_data_buffers.length == 0)
  end
  def size
    puts "size?"
    512000
  end
  def flush
    until eof?
      bytes_from_stream = self.stream.read(1024 * 1024 * 2)
      break if bytes_from_stream.nil?
      self.reader.write(bytes_from_stream)
    end
  end
end

class SimpleInputWrapper
  attr_accessor :stream, :content_length
  def initialize(stream, content_length)
    self.stream = stream
    self.content_length = content_length
  end
  def size
    return self.content_length
  end
  def read(*args)
    return self.stream.read(500 * 1024)
  end
  def eof?
    puts "eof?"
  end
end

map "http://middl.risingcode.com/" do
  #use Rack::ContentLength
  #use Rack::ContentType
  #use Rack::Chunked
  run lambda { |env|
    return [100, {}, []] if env["HTTP_EXPECT"] && env["HTTP_EXPECT"].include?("100-continue") 
    puts env["rack.input"].inspect
    puts env.inspect
    if env["CONTENT_LENGTH"] then
      if true
        s3 = AWS::S3.new
        b = s3.buckets.create("middl_test")
        o = b.objects["wtf_temp2"]
        wrapped_input = SimpleInputWrapper.new(env["rack.input"], env["CONTENT_LENGTH"].to_i)
        written_to_s3 = o.write(:data => wrapped_input)
        puts written_to_s3.inspect
      end

      if false
      #s3 = AWS::S3.new
      #b = s3.buckets.create("middl_test")
      #o = b.objects["wtf_temp2"]
      #wrapped_input = StreamInputWrapper.new(env["rack.input"], env["CONTENT_TYPE"], env["CONTENT_LENGTH"].to_i)
      #wrapped_input.flush

      #written_to_s3 = o.write(:data => wrapped_input) #wrapped_input.content_length) #, :multipart_threshold => 0)
      #puts "DONE???? #{written_to_s3.inspect} #{wrapped_input.stream.instance_variable_get("@bytes_read")}"
      #puts wrapped_input.params.inspect
      #if written_to_s3.is_a?(AWS::S3::S3Object)
      end

      if false
        req = Rack::Request.new(env)
        puts req["media"].inspect
      end
      if true then
        return [
          201, {"Content-Type" => "text/plain"}, StringIO.new("OK")
        ]
      else
        return [
          500, {"Content-Type" => "text/plain"}, StringIO.new("BAD")
        ]
      end
    else
      return [200, {"Content-Type" => "text/html"}, File.open("upload.html")]
    end
  }
end
