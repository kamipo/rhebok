require 'yaml'
require 'net/http'
require 'rack/lint'

class TestRequest
  NOSERIALIZE = [Method, Proc, Rack::Lint::InputWrapper]

  def call(env)

    test_header = {};
    status = env["QUERY_STRING"] =~ /secret/ ? 403 : 200
    if env["PATH_INFO"] =~ /date/ then
      test_header["Date"] = "Foooo"
    end
    if env["PATH_INFO"] =~ /connection/ then
      test_header["Connection"] = "keepalive"
    end
    env["test.postdata"] = env["rack.input"].read
    minienv = env.dup
    # This may in the future want to replace with a dummy value instead.
    minienv.delete_if { |k,v| NOSERIALIZE.any? { |c| v.kind_of?(c) } }
    body = minienv.to_yaml
    size = body.respond_to?(:bytesize) ? body.bytesize : body.size
    res_header = {"Content-Type" => "text/yaml", "Content-Length" => size.to_s, "X-Foo" => "Foo\nBar", "X-Bar"=>"Foo\n\nBar", "X-Baz"=>"\nBaz", "X-Fuga"=>"Fuga\n"}
    [status, res_header.merge(test_header), [body]]
  end

  module Helpers
    attr_reader :status, :response, :header

    ROOT = File.expand_path(File.dirname(__FILE__) + "/..")
    ENV["RUBYOPT"] = "-I#{ROOT}/lib -rubygems"

    def root
      ROOT
    end

    def rackup
      "#{ROOT}/bin/rackup"
    end

    def GET(path, header={})
      Net::HTTP.start(@host, @port) { |http|
        user = header.delete(:user)
        passwd = header.delete(:passwd)

        get = Net::HTTP::Get.new(path, header)
        get.basic_auth user, passwd  if user && passwd
        http.request(get) { |response|
          @status = response.code.to_i
          @header = response
          begin
            @response = YAML.load(response.body)
          rescue TypeError, ArgumentError
            @response = nil
          end
        }
      }
    end

    def POST(path, formdata={}, header={})
      Net::HTTP.start(@host, @port) { |http|
        user = header.delete(:user)
        passwd = header.delete(:passwd)

        post = Net::HTTP::Post.new(path, header)
        post.form_data = formdata
        post.basic_auth user, passwd  if user && passwd
        http.request(post) { |response|
          @status = response.code.to_i
          @response = YAML.load(response.body)
        }
      }
    end
  end
end

class StreamingRequest
  def self.call(env)
    [200, {"Content-Type" => "text/plain"}, new]
  end

  def each
    yield "hello there!\n"
    sleep 5
    yield "that is all.\n"
  end
end

