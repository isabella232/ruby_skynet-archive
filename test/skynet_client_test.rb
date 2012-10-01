# Allow test to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'skynet'
require 'simple_server'

SemanticLogger::Logger.default_level = :trace
SemanticLogger::Logger.appenders << SemanticLogger::Appender::File.new('test.log')

# Unit Test for ResilientSocket::TCPClient
class SkynetClientTest < Test::Unit::TestCase
  context Skynet::Client do

    context "without server" do
      should "raise exception when cannot reach server after 5 retries" do
        exception = assert_raise ResilientSocket::ConnectionFailure do
          ResilientSocket::TCPClient.new(
            :server                 => 'localhost:3300',
            :connect_retry_interval => 0.1,
            :connect_retry_count    => 5)
        end
        assert_match /After 5 attempts: Errno::ECONNREFUSED/, exception.message
      end

    end

    context "with server" do
      setup do
        @server = SimpleServer.new(2000)
        @server_name = 'localhost:2000'
      end

      teardown do
        @server.stop if @server
      end

      context "using blocks" do
        should "call server" do
          Skynet::Client.connect('TutorialService') do |tutorial_service|
            assert_equal 'test1', tutorial_service.call('action' => 'test1')['result']
          end
        end
      end

      context "with client connection" do
        setup do
          @read_timeout = 3.0
          @client = Skynet::Client.new('TutorialService')
        end

        def teardown
          @client.close if @client
        end

        should "successfully send and receive data" do
          request = { 'action' => 'test1' }
          reply = @client.call(request)
          assert_equal 'test1', reply['result']
        end

        should "timeout on receive" do
          request = { 'action' => 'sleep', 'duration' => @read_timeout + 0.5}

          exception = assert_raise ResilientSocket::ReadTimeout do
            # Read 4 bytes from server
            @client.call(request)
          end
          assert_match /Timedout after #{@read_timeout} seconds trying to read/, exception.message
        end

#        should "retry on connection failure" do
#          attempt = 0
#          reply = @client.retry_on_connection_failure do
#            request = { 'action' => 'fail', 'attempt' => (attempt+=1) }
#            @client.send(BSON.serialize(request))
#            # Note: Do not put the read in this block if it should never send the
#            #       same request twice to the server
#            read_bson_document(@client)
#          end
#          assert_equal 'fail', reply['result']
#        end

      end
    end

  end
end