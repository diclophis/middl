require 'test/unit'
require File.dirname(__FILE__) + "/../lib/multipart_parser"
require File.dirname(__FILE__) + "/fixtures/multipart"

class MultipartParserTest < Test::Unit::TestCase
  def test_init_with_boundary 
    parser = MultipartParser.new
    def parser.boundary; @boundary end 
    def parser.boundary_chars; @boundary_chars end

    parser.init_with_boundary("abc")
    assert_equal "\r\n--abc", parser.boundary
    expected_bc = {13 => true, 10 => true, 45 => true, 97 => true,  
                  98 => true, 99 => true}
    assert_equal expected_bc, parser.boundary_chars
  end

  def test_parser_error
    parser = MultipartParser.new
    parser.init_with_boundary("abc")
    assert_equal 3, parser.write("--ad")
  end

  def test_fixtures
    parser = MultipartParser.new
    chunk_length = 10
    MultipartFixtures.fixtures.each do |fixture|
      buffer = fixture.raw
      parts = []
      part, header_field, header_value = nil, nil, nil
      end_called = false
      got_error = false

      parser.init_with_boundary(fixture.boundary)
      
      parser.on(:part_begin) do
        part = {:headers => {}, :data => ''}
        parts.push(part)
        header_field = ''
        header_value = '' 
      end
      
      parser.on(:header_field) do |b, start, the_end|
        header_field += b[start...the_end]
      end

      parser.on(:header_value) do |b, start, the_end|
        header_value += b[start...the_end]
      end

      parser.on(:header_end) do
        part[:headers][header_field] = header_value
        header_field = ''
        header_value = ''
      end

      parser.on(:part_data) do |b, start, the_end|
        part[:data] += b[start...the_end]
      end 
      
      parser.on(:end) do 
        end_called = true
      end

      offset = 0
      while offset < buffer.length
        if(offset + chunk_length < buffer.length)
          chunk = buffer[offset, chunk_length]
        else
          chunk = buffer[offset...buffer.length]
        end
        offset += chunk_length
        
        nparsed = parser.write(chunk)
        if nparsed != chunk.length
          unless fixture.expect_error
            puts "--ERROR--"
            puts chunk
            flunk "#{fixture.class.name}: #{chunk.length} bytes written, " +
                  "but only #{nparsed} bytes parsed!"
          else
            got_error = true
          end
        end
      end
      unless got_error
        assert true, end_called
        assert_equal fixture.parts, parts
      else
        assert fixture.expect_error, 
            "#{fixture.class.name}: Expected parse error did not happen"
      end
    end 
  end
end
