#!/usr/bin/env ruby
# vim: noet


# import rspec
require "rubygems"
require "spec"

# import the main library
here = File.dirname(__FILE__)
require "#{here}/../lib/rubygsm.rb"

# import the mock modem to test against
here = File.dirname(__FILE__)
require "#{here}/../lib/mock/modem.rb"


describe Gsm do
	before(:each) do
		@modem = Gsm::Mock::Modem.new
	end
	
	it "initializes the modem" do
		lambda do
			@gsm = Gsm::Modem.new(@modem)
		end.should_not raise_error
	end
end
