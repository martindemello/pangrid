require "webrick"

module Pangrid

TEMPLATE_DIR = File.dirname(File.expand_path(__FILE__)) + '/../data'
TEMPLATE = TEMPLATE_DIR + '/webform.html'

class Servlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET (request, response)
    template = IO.read(TEMPLATE)
    response.status = 200
    response.content_type = "text/html"
    response.body = template % ""
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
    
    template = IO.read(TEMPLATE)
    response.status = 200
    response.content_type = "text/html"
    response.body = template % out
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
