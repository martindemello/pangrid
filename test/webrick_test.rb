require_relative 'test_helper'

class ServletTest < PangridTest
  Request = Struct.new(:query, :path)

  class Response
    attr_accessor :status, :content_type, :body, :header
    def initialize; @header = {}; end
  end

  def servlet
    Servlet.new({})
  end

  def post(path, from:, to:, data:)
    res = Response.new
    servlet.do_POST(Request.new({"filedata" => data, "from" => from, "to" => to}, path), res)
    res
  end

  def test_get
    res = Response.new
    servlet.do_GET(Request.new({}, "/"), res)
    assert_equal 200, res.status
    assert_equal "text/html", res.content_type
    assert_includes res.body, "<textarea"
  end

  def test_post_form
    res = post("/", from: "json", to: "text", data: Json.new.write(make_xw))
    assert_equal "text/html", res.content_type
    assert_includes res.body, "1. Feline"
    assert_equal "*", res.header['Access-Control-Allow-Origin']
  end

  def test_post_blob
    res = post("/blob", from: "json", to: "across-lite-binary", data: Json.new.write(make_xw))
    assert_equal "application/octet-stream", res.content_type
    assert_includes res.body, "ACROSS&DOWN"
  end

  def test_post_json
    res = post("/json", from: "across-lite-text", to: "json",
               data: AcrossLiteText.new.write(make_xw))
    assert_equal "text/json", res.content_type
    assert_equal 3, JSON.parse(res.body)["rows"]

    res = post("/json", from: "json", to: "text", data: Json.new.write(make_xw))
    assert_match(/non-json format requested/, res.body)
  end

  def test_post_reports_conversion_errors
    res = post("/", from: "csv", to: "text", data: "garbage")
    assert_includes res.body, "PuzzleFormatError"
  end
end
