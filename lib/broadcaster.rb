# Send and listen for LAN broadcasts, as defined in the core protocol

require 'json'
require 'thread'
require 'socket'

module Broadcaster
  BROADCAST_PORT = 60106

  def self.on_receive &block
    @received = block
  end

  def self.start
    @socket = UDPSocket.new
    begin
      @socket.bind '', BROADCAST_PORT
    rescue Errno::EADDRINUSE
      warn "Cannot broadcast, address already in use"
      return
    end
    @socket.setsockopt Socket::SOL_SOCKET, Socket::SO_BROADCAST, true
    @socket.setsockopt Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true

    warn "Broadcaster listening on #{@socket.inspect}"

    Thread.new do
      listen
    end

    Thread.new do
      run
    end
  end

  private

  def self.listen
    loop do
      json, sender = @socket.recvfrom 512
      msg = JSON.parse json, symbolize_names: true
      warn "Got message: #{json}"
      next if msg[:name] != "ClearSkiesBroadcast"
      next if msg[:version] != 1
      @received.call msg[:peer], sender[2], msg[:myport]
    end
  end

  def self.run
    loop do
      puts "Broadcasting"
      Shares.each do |share|
        send_broadcast share.id, share.peer_id
      end
      sleep 60
    end
  end

  def self.send_broadcast id, peer_id
    message = {
      :name => "ClearSkiesBroadcast",
      :version => 1,
      :id => share.id,
      :peer => share.peer_id,
      :myport => Network.lan_listen_port,
    }.to_json
    warn "Broadcasting #{message}"
    @socket.send message, 0, '<broadcast>', BROADCAST_PORT
  end
end
