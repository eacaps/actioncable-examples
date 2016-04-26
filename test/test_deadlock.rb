require_relative 'test_helper'
require 'concurrent'

require 'active_support/core_ext/hash/indifferent_access'
require 'pathname'

require 'faye/websocket'
require 'json'

class QuickTest < SampleTestCase
  WAIT_WHEN_EXPECTING_EVENT = 8
  WAIT_WHEN_NOT_EXPECTING_EVENT = 0.5

  def setup
    @pid = Process.spawn('rails server -b 0.0.0.0 -p 3000 -e development')
    Thread.new { EventMachine.run } unless EventMachine.reactor_running?
    Thread.pass until EventMachine.reactor_running?

    # faye-websocket is warning-rich
    @previous_verbose, $VERBOSE = $VERBOSE, nil
    sleep(5)
  end

  def teardown
    $VERBOSE = @previous_verbose
    # faye-websocket is warning-rich
    @previous_verbose, $VERBOSE = $VERBOSE, nil
    Process.kill('INT', @pid)
    Process.wait()
  end

  class SyncClient
    attr_reader :pings

    def initialize(port)
      @ws = Faye::WebSocket::Client.new("ws://127.0.0.1:#{port}/ws")
      @messages = Queue.new
      @closed = Concurrent::Event.new
      @has_messages = Concurrent::Semaphore.new(0)
      @pings = 0

      open = Concurrent::Event.new
      error = nil

      @ws.on(:error) do |event|
        if open.set?
          @messages << RuntimeError.new(event.message)
        else
          error = event.message
          open.set
        end
      end

      @ws.on(:open) do |event|
        open.set
      end

      @ws.on(:message) do |event|
        message = JSON.parse(event.data)
        if message['type'] == 'ping'
          @pings += 1
        else
          @messages << message
          @has_messages.release
        end
      end

      @ws.on(:close) do |event|
        @closed.set
      end

      open.wait(WAIT_WHEN_EXPECTING_EVENT)
      raise error if error
    end

    def read_message
      @has_messages.try_acquire(1, WAIT_WHEN_EXPECTING_EVENT)

      msg = @messages.pop(true)
      raise msg if msg.is_a?(Exception)

      msg
    end

    def read_messages(expected_size = 0)
      list = []
      loop do
        if @has_messages.try_acquire(1, list.size < expected_size ? WAIT_WHEN_EXPECTING_EVENT : WAIT_WHEN_NOT_EXPECTING_EVENT)
          msg = @messages.pop(true)
          raise msg if msg.is_a?(Exception)

          list << msg
        else
          break
        end
      end
      list
    end

    def send_message(message)
      @ws.send(JSON.generate(message))
    end

    def close
      sleep WAIT_WHEN_NOT_EXPECTING_EVENT

      unless @messages.empty?
        raise "#{@messages.size} messages unprocessed"
      end

      @ws.close
      wait_for_close
    end

    def wait_for_close
      @closed.wait(WAIT_WHEN_EXPECTING_EVENT)
    end

    def closed?
      @closed.set?
    end
  end

  def faye_client(port)
    SyncClient.new(port)
  end

  def test_single_client
    c = faye_client(3000)
    assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
    c.send_message command: 'subscribe', identifier: JSON.generate(channel: 'CommentsChannel')
    c.send_message command: 'subscribe', identifier: JSON.generate(channel: 'OtherChannel')
    messages = []
    messages.push(c.read_message)
    messages.push(c.read_message)
    messages.push(c.read_message)
    assert_equal(messages.length, 3)
    assert_includes(messages, {"identifier"=>"{\"channel\":\"CommentsChannel\"}", "type"=>"confirm_subscription"})
    assert_includes(messages, {"identifier"=>"{\"channel\":\"OtherChannel\"}", "type"=>"confirm_subscription"})
    c.close
  end
end
