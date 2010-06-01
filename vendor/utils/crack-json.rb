class Object #:nodoc: Returns true if the object is nil or empty (if applicable)
  def blank?;nil? || (respond_to?(:empty?) && empty?);end unless method_defined?(:blank?)
end # class Object

class Numeric #:nodoc: Numerics can't be blank
  def blank?;false;end unless method_defined?(:blank?)
end # class Numeric

class NilClass #:nodoc: Nils are always blank
  def blank?;true;end unless method_defined?(:blank?)
end # class NilClass

class TrueClass #:nodoc: True is not blank.  
  def blank?;false;end unless method_defined?(:blank?)
end # class TrueClass

class FalseClass #:nodoc: False is always blank.
  def blank?;true;end unless method_defined?(:blank?)
end # class FalseClass

class String #:nodoc:
  # @example "".blank?         #=>  true
  # @example "     ".blank?    #=>  true
  # @example " hey ho ".blank? #=>  false
  # Strips out whitespace then tests if the string is empty.
  def blank?;strip.empty?;end unless method_defined?(:blank?)
  def snake_case
    return self.downcase if self =~ /^[A-Z]+$/
    self.gsub(/([A-Z]+)(?=[A-Z][a-z]?)|\B[A-Z]/, '_\&') =~ /_*(.*)/
    return $+.downcase
  end unless method_defined?(:snake_case)
end # class String

class Hash #:nodoc:
  # @return <String> This hash as a query string
  # @example
  #   { :name => "Bob",
  #     :address => {
  #       :street => '111 Ruby Ave.',
  #       :city => 'Ruby Central',
  #       :phones => ['111-111-1111', '222-222-2222']
  #     }
  #   }.to_params
  #     #=> "name=Bob&address[city]=Ruby Central&address[phones][]=111-111-1111&address[phones][]=222-222-2222&address[street]=111 Ruby Ave."
  def to_params
    params = self.map { |k,v| normalize_param(k,v) }.join
    params.chop! # trailing &
    params
  end

  # @param key<Object> The key for the param.
  # @param value<Object> The value for the param.
  #
  # @return <String> This key value pair as a param
  #
  # @example normalize_param(:name, "Bob Jones") #=> "name=Bob%20Jones&"
  def normalize_param(key, value)
    param = ''
    stack = []

    if value.is_a?(Array)
      param << value.map { |element| normalize_param("#{key}[]", element) }.join
    elsif value.is_a?(Hash)
      stack << [key,value]
    else
      param << "#{key}=#{URI.encode(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&"
    end

    stack.each do |parent, hash|
      hash.each do |key, value|
        if value.is_a?(Hash)
          stack << ["#{parent}[#{key}]", value]
        else
          param << normalize_param("#{parent}[#{key}]", value)
        end
      end
    end

    param
  end
end


# require 'crack/json'
# Copyright (c) 2004-2008 David Heinemeier Hansson
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
require 'yaml'
require 'strscan'

module Crack
  class ParseError < StandardError; end
  class JSON
    def self.parse(json)
      YAML.load(unescape(convert_json_to_yaml(json)))
    rescue ArgumentError => e
      raise ParseError, "Invalid JSON string"
    end

    protected
      def self.unescape(str)
        str.gsub(/\\u([0-9a-f]{4})/) { [$1.hex].pack("U") }
      end
      
      # matches YAML-formatted dates
      unless defined?(DATE_REGEX)
        DATE_REGEX = /^\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?)?$/
      end

      # Ensure that ":" and "," are always followed by a space
      def self.convert_json_to_yaml(json) #:nodoc:
        scanner, quoting, marks, pos, times = StringScanner.new(json), false, [], nil, []
        while scanner.scan_until(/(\\['"]|['":,\\]|\\.)/)
          case char = scanner[1]
          when '"', "'"
            if !quoting
              quoting = char
              pos = scanner.pos
            elsif quoting == char
              if json[pos..scanner.pos-2] =~ DATE_REGEX
                # found a date, track the exact positions of the quotes so we can remove them later.
                # oh, and increment them for each current mark, each one is an extra padded space that bumps
                # the position in the final YAML output
                total_marks = marks.size
                times << pos+total_marks << scanner.pos+total_marks
              end
              quoting = false
            end
          when ":",","
            marks << scanner.pos - 1 unless quoting
          end
        end

        if marks.empty?
          json.gsub(/\\\//, '/')
        else
          left_pos  = [-1].push(*marks)
          right_pos = marks << json.length
          output    = []
          left_pos.each_with_index do |left, i|
            output << json[left.succ..right_pos[i]]
          end
          output = output * " "

          times.each { |i| output[i-1] = ' ' }
          output.gsub!(/\\\//, '/')
          output
        end
      end
  end
end # require 'crack/xml'
