#!/usr/bin/env ruby
# vim: noet


# import rspec
require "rubygems"
require "spec"

# import the main library, and
# a mock modem to test against
here = File.dirname(__FILE__)
require "#{here}/../lib/rubygsm.rb"
require "#{here}/mock/modem.rb"


describe Gsm::Modem do
	it "initializes the modem" do
		lambda do
			modem = Gsm::Mock::Modem.new
			Gsm::Modem.new(modem)
		end.should_not raise_error
	end
	
	it "resets the modem after 5 consecutive errors" do
		
		# this modem will return errors when AT+CSQ is
		# called, UNTIL the modem is reset. a flag is
		# also set, so we can check for the reset
		class TestModem < Gsm::Mock::Modem
			attr_reader :has_reset
			
			def at_csq(*args)
				@has_reset ? super : false
			end
			
			def at_cfun(*args)
				(@has_reset = true)
			end
		end

		# start rubygsm, and call
		# the troublesome method
		modem = TestModem.new		
		gsm = Gsm::Modem.new(modem)
		gsm.signal_strength
		
		# it should have called AT+CFUN!
		modem.has_reset.should == true
	end
end
