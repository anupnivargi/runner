require "eventmachine"
require "evma_httpserver"
require "cgi"


class Object

  def present?
    !blank?
  end

  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

end

class Hash

  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

end


class Request
  attr_accessor :url, :method, :params, :raw_body

  def initialize(data)
    data = data.split(/\r\n/)
    @raw_body = data.last
    @method, url, version = data.shift.split(' ', 3)
    @url, params = url.split("?")
    @params = CGI.parse(params.to_s)
    @params.each{|k,v| @params[k] = v[0]}.symbolize_keys!
    self
  end
end

class Response
  attr_accessor :content_type, :status, :body

  def initialize(body, status=200, content_type='application/json; charset=UTF-8')

    @body = body
    @content_type = content_type
    @status = status

  end

  def construct
    [
      "HTTP/1.1 %d OK",
      "Content-length: %d",
      "Content-type: %s",
      "Connection: Keep-Alive",
      "Access-Control-Allow-Origin: *",
      "",
      "%s"].join("\r\n") % [@status, @body.length, @content_type, @body]
  end
end

class UrlHandler
  def initialize(url, params)
    @url = url
    @params = params
  end
end

class LongPoller
  attr_accessor :sid, :params
  def initialize(connection, data)
    @connection = connection
    @request = Request.new(data)
    @sid = nil
  end

  def handle_request
    p @request
    case @request.url
    when "/"
      add_timer
      subscribe
    when "/say"
      add_timer
      subscribe
      push
    else
      close_connection
    end
  end

  def close_connection
    @connection.close_connection
  end

  def close_connection_after_writing
    @connection.close_connection_after_writing
  end

  def respond(body, status=200, content_type="application/json")
    @connection.send_data Response.new("{}", status, content_type).construct
  end

  def add_timer
    p "Add timer"
    @timer = EM::Timer.new(30) do
      respond("{}")
    end
  end

  def push
    p @request.params[:message]
    if @request.params[:message].present?
      GlobalChannel.push @request.params[:message]
    end
    close_connection_after_writing
  end

  def subscribe
    self.sid = GlobalChannel.subscribe do |message|
      @timer.cancel
      respond("{\"message\":\"#{message}\"}")
      close_connection_after_writing
    end
  end
end

class RequestHandler < EM::Connection

  def post_init;end

  def receive_data data
    @poller = LongPoller.new(self, data)
    @poller.handle_request
  end

  def unbind
    if @poller.sid
      GlobalChannel.unsubscribe(@poller.sid)
    end
  end

end

EM.run do
  Signal.trap("INT"){ EM.stop }
  Signal.trap("TERM"){ EM.stop }
  EM.epoll if EM.epoll?
  GlobalChannel = EM::Channel.new
  host, port = ENV['OPENSHIFT_INTERNAL_IP'] || "0.0.0.0", ENV['PORT'] || ENV['OPENSHIFT_INTERNAL_PORT'] || 8080
  puts "Starting on #{host}:#{port}"
  EM.start_server host, port, RequestHandler
end
