# frozen_string_literal: true

module RailFeeds
  module NetworkRail
    # A Class to store username & password required to access network rail feeds
    # Can be used to set a global default but create new instances with
    # specific ones for a specific use.
    class Credentials < RailFeeds::Credentials
    end
  end
end
