#!/usr/bin/env ruby
# vim: noet

# if this spec is being called via another spec (to
# test the various faulty mock modems), don't load
# the supporting libs
unless $modem
	here = File.dirname(__FILE__)
	require "#{here}/_setup.rb"
	$modem = Gsm::Mock::Modem
end

describe "Running on a #{$modem.inspect}" do
	before(:each) do
		@modem = $modem.new
	end

	it "initializes the modem" do
		lambda do
			@gsm = Gsm::Modem.new(@modem)
		end.should_not raise_error
	end
end
