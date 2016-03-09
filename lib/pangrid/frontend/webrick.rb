require "webrick"

module Pangrid

FORM = <<HERE
<html>
  <body>
    <form method="POST" enctype="multipart/form-data">
      <input type="file" name="filedata" />
      <select name="from">
        <option value="across-lite-binary">AcrossLite binary (.puz)</option>
        <option value="across-lite-text">AcrossLite text</option>
      </select>
      &rarr;
      <select name="to">
        <option value="reddit-blank">Reddit (blank)</option>
        <option value="reddit-filled">Reddit (filled)</option>
        <option value="text">Text</option>
      </select>
      <input type="submit" />
    </form>
    <hr>
    <div>
      <pre>%s</pre>
    </div>
  </body>
</html>
HERE

class Servlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET (request, response)
    response.status = 200
    response.content_type = "text/html"
    response.body = FORM % ""
  end

  def do_POST(request, response)
    input = request.query["filedata"]
    from = Plugin.get(request.query["from"])
    to = Plugin.get(request.query["to"])
    reader = from.new
    writer = to.new
    out = nil

    begin
      out = writer.write(reader.read(input))
    rescue Exception => e
      out = e.inspect
    end
    
    response.status = 200
    response.content_type = "text/html"
    response.body = FORM % WEBrick::HTMLUtils.escape(out)
  end
end

def self.run_webserver(port)
  puts "-------------------------------------------"
  puts "Open your web browser and load"
  puts "  http://localhost:#{port}"
  puts "-------------------------------------------"

  Plugin.load_all

  logfile = File.open('pangrid-webrick-access.log', 'a')
  logfile.sync = true
  log = [ [logfile, WEBrick::AccessLog::COMMON_LOG_FORMAT] ]

  server = WEBrick::HTTPServer.new(:Port => port, :AccessLog => log)
  server.mount "/", Servlet
  trap("INT") { server.shutdown }
  server.start
end

end # module Pangrid
