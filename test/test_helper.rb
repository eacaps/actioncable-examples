require 'active_support'
require 'active_support/testing/autorun'

require 'puma'

class SampleTestCase < ActiveSupport::TestCase
  # if ENV['FAYE'].present?
  #   include EventMachineConcurrencyHelpers
  # else
  #   include ConcurrentRubyConcurrencyHelpers
  # end
end