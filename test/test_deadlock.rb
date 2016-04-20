require 'test_helper'
require 'faye/websocket'

class ClientTest < ActiveSupport::TestCase
  WAIT_WHEN_EXPECTING_EVENT = 8
  WAIT_WHEN_NOT_EXPECTING_EVENT = 0.5

  def test_app
    with_puma_server do |port|
      c = faye_client(port)
      assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
      c.send_message command: 'subscribe', identifier: JSON.generate(channel: 'EchoChannel')
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: 'message', identifier: JSON.generate(channel: 'EchoChannel'), data: JSON.generate(action: 'ding', message: 'hello')
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "message"=>{"dong"=>"hello"}}, c.read_message)
      c.close
    end
  end

  def test_app_spawn

    puts 'sleep over'
    c = faye_client(3000)
    assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
    c.send_message command: 'subscribe', identifier: JSON.generate(channel: 'CommentsChannel')
    assert_equal({"identifier"=>"{\"channel\":\"CommentsChannel\"}", "type"=>"confirm_subscription"}, c.read_message)

  end

  def setup
    @pid = Process.spawn('rails server -b 0.0.0.0 -p 3000 -e development')
    Thread.new { EventMachine.run } unless EventMachine.reactor_running?
    Thread.pass until EventMachine.reactor_running?
    sleep(5)
  end

  def teardown
    Process.kill('INT', @pid)
    Process.wait()
  end

  def with_puma_server(rack_app = ActioncableExamples, port = 3099)
    server = ::Puma::Server.new(rack_app, ::Puma::Events.strings)
    server.add_tcp_listener '127.0.0.1', port
    server.min_threads = 1
    server.max_threads = 4

    t = Thread.new { server.run.join }
    yield port

  ensure
    server.stop(true) if server
    t.join if t
  end

  class SyncClient
    attr_reader :pings

    def initialize(port)
      @ws = Faye::WebSocket::Client.new("ws://localhost:#{port}/ws")
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
end