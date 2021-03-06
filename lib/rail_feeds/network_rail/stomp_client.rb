# frozen_string_literal: true

module RailFeeds
  module NetworkRail
    # A wrapper class for ::Stomp::Client which provides durable subscriptions
    class StompClient
      include Logging
      extend Forwardable

      HOST = 'datafeeds.networkrail.co.uk'
      PORT = '61618'

      # Initialize a new stomp client.
      # @param [RailFeeds::NetworkRail::Credentials] credentials
      #   The credentials for connecting to the feed.
      # @param [Logger, nil] logger
      #   The logger for outputting evetns, if nil the global logger will be used.
      def initialize(credentials: Credentials, logger: nil)
        @credentials = credentials
        self.logger = logger unless logger.nil?
      end

      # rubocop:disable Metrics/MethodLength
      # Connect to the network rail server.
      def connect
        return if @client && client.open?

        client_options = {
          hosts: [{
            host: HOST,
            port: PORT,
            login: @credentials.username,
            password: @credentials.password
          }],
          connect_headers: {
            'host' => HOST,
            'client-id' => @credentials.username,
            'accept-version' => '1.1',
            'heart-beat' => '5000,10000'
          },
          logger: logger
        }
        @client = Stomp::Client.new client_options
      end
      # rubocop:enable Metrics/MethodLength

      # Disconnect from the network rail server.
      def disconnect
        return if @client.nil?

        @client.close
      end

      # Subscribe to a topic.
      # Will connect to the server if required.
      # Must be passed a block which will be called with each message received.
      # @param [String, #to_s] topic
      #   The topic to subscribe to (e.g. "TSR_WESS_ROUTE" or "TD_ALL_SIG_AREA").
      # @param [Hash] headers
      #   Extra headers to pass to the server.
      def subscribe(topic, headers = {}, &block)
        connect if @client.nil? || @client.closed?
        headers['activemq.subscriptionName'] ||= "#{::Socket.gethostname}+#{topic}"
        headers['id'] ||= @client.uuid
        headers['ack'] ||= 'client'
        @client.subscribe "/topic/#{topic}", headers, &block
      end

      def_delegators :@client, :ack, :acknowledge, :nack, :unreceive,
                     :create_error_handler, :open?, :closed?, :join, :running?,
                     :begin, :abort, :commit, :unsubscribe, :uuid, :poll,
                     :hbsend_interval, :hbrecv_interval,
                     :hbsend_count, :hbrecv_count
    end
  end
end
