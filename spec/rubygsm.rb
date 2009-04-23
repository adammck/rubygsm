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
end
