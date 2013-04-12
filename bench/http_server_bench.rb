require "eventmachine"
require "em-http-request"
EM.run do
  t1 = Time.now + 30
  url = "http://localhost:8080"
  i = 0
  loop do
    http = EM::HttpRequest.new(url).get
    http.callback {
      puts "#{url}\n#{http.response_header.status} - #{http.response.length} bytes\n"
      puts http.response
    }
    http.errback {
      EM.stop
    }
    i += 1
    p i
    break if Time.now > t1
  end
  p t1
end
