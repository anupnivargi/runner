require "eventmachine"

class User
  attr_accessor :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end

  def subscribe(channel)
    channel.subscribe do |message|
       unless message[:except] == id
        puts "#{name} : #{message}"
       end
    end
  end
end

EM.run do
  Signal.trap("INT"){ EM.stop }
  Signal.trap("TERM"){ EM.stop }
  EM.epoll if EM.epoll?
  channel1 = EM::Channel.new
  channel2 = EM::Channel.new
  
  user1 = User.new(1, "Anup")
  user1.subscribe(channel1)

  channel1 << {:message => "Hello", :except => nil}

  user2 = User.new(2, "Sush")
  user2.subscribe(channel1)

  channel1 << {:message => "Hello", :except => 1}

  EM.stop

end
