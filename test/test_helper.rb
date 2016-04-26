require 'active_support'
require 'active_support/testing/autorun'

require 'puma'
# require 'mocha/setup'
# require 'rack/mock'

# Require all the stubs and models
# Dir[File.dirname(__FILE__) + '/stubs/*.rb'].each {|file| require file }

# if ENV['FAYE'].present?
#   require 'faye/websocket'
#   class << Faye::WebSocket
#     remove_method :ensure_reactor_running
#
#     # We don't want Faye to start the EM reactor in tests because it makes testing much harder.
#     # We want to be able to start and stop EM loop in tests to make things simpler.
#     def ensure_reactor_running
#       # no-op
#     end
#   end
# end

class SampleTestCase < ActiveSupport::TestCase
  # if ENV['FAYE'].present?
  #   include EventMachineConcurrencyHelpers
  # else
  #   include ConcurrentRubyConcurrencyHelpers
  # end
end
