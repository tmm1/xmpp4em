# $Id: app.rb 3893 2007-03-06 20:12:09Z francis $
#
#


$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'eventmachine'
require 'evma_xmlpushparser'


class TestApp < Test::Unit::TestCase

	Host = "127.0.0.1"
	Port = 9250

	class Xml < EventMachine::Connection
		include EventMachine::XmlPushParser
		attr_reader :elements, :element_ends
		def initialize *args
			super
			@elements = {}
			@element_ends = []
		end
		def start_document
		end
		def start_element nm, attrs
			if ["aaa","bbb"].include?(nm)
				@elements[nm] = attrs
			else
				raise "error"
			end
		end
		def end_element nm
			@element_ends << nm
		end
		def end_document
			EventMachine.stop
		end
	end

	module XmlClient
		def post_init
			send_data '<?xml version="1.0"?><aaa'
			send_data ' attr1="1" attr2="2">chars<bbb/'
			send_data '></a'
			send_data 'aa>'
			close_connection_after_writing
		end
	end

	def test_a
		obj = nil
		EventMachine.run {
			EventMachine.start_server(Host, Port, Xml) {|xml| obj = xml}
			EventMachine.connect Host, Port, XmlClient
			EventMachine.add_timer(2) {EventMachine.stop} # avoid hang in case of error
		}

		assert_equal( ["aaa","bbb"], obj.elements.keys.sort )
		assert_equal( {"attr1"=>"1","attr2"=>"2"}, obj.elements["aaa"] )
		assert_equal( {}, obj.elements["bbb"] )
		assert_equal( ["bbb","aaa"], obj.element_ends)
	end
end


