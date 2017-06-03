ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "pry"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end

  def test_filename
    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "You, using a pen and paper"
  end

  def test_document_not_found
    get "/notafile.exe"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_equal last_response.body, "notafile.exe does not exist."
  end
end
