require "eventmachine"
require "evma_httpserver"

class RequestHandler < EM::Connection
  include EM::HttpServer

  def post_init
    super
    no_environment_strings
  end

  def process_http_request
    response = EM::DelegatedHttpResponse.new(self)
    response.status = 200
    response.content_type 'text/html'
    response.content = '<center><h1>Hello!!!</h1></center>'
    response.send_response
  end

end

EM.run do
  host, port = ENV['OPENSHIFT_INTERNAL_IP'] || "0.0.0.0", ENV['PORT'] || ENV['OPENSHIFT_INTERNAL_PORT'] || 8080
  puts "Starting on #{host}:#{port}"
  EM.start_server host, port, RequestHandler
end
