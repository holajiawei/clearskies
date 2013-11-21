# Talk with a central tracker.

require 'net/http'
require_relative 'simple_thread'
require_relative 'pending_codes'
require_relative 'id_mapper'

module TrackerClient
  # Start background thread
  def self.start
    @last_run = {}
    SimpleThread.new 'tracker' do
      work
    end
  end

  # Callback for when peer is discovered
  def self.on_peer_discovered &block
    @peer_discovered = block
  end

  # Force connection to tracker
  def self.force_run
    SimpleThread.new 'force_tracker' do
      poll_all_trackers
    end
  end

  private
  # Main thread entry point
  def self.work
    loop do
      # FIXME we really need to wait the exact amount of time requested by
      # each tracker
      wait_time = 30
      poll_all_trackers

      gsleep wait_time
    end
  end

  # Ask all trackers for information about all of our shares.
  def self.poll_all_trackers
    IDMapper.each do |share_id,peer_id|
      trackers.each do |url|
        poll_tracker share_id, peer_id, url
      end
    end
  end

  # Ask tracker for a list of peers interested in a share.
  def self.poll_tracker share_id, peer_id, url
    uri = URI(url)
    uri.query = URI.encode_www_form({
      :id => share_id,
      :peer => peer_id,
      :myport => Network.listen_port,
    })
    Log.debug "Tracking with #{uri}"
    res = gunlock { Net::HTTP.get_response uri }
    return unless res.is_a? Net::HTTPSuccess
    info = JSON.parse res.body, symbolize_names: true

    info[:others].each do |peerspec|
      id, addr = peerspec.split "@"
      # FIXME IPv6 needs better parsing
      ip, port = addr.split ":"
      @peer_discovered.call share_id, id, ip, port.to_i
    end
  end

  # Get a list of trackers.
  def self.trackers
    ["http://clearskies.tuxng.com/clearskies/track"]
  end
end
