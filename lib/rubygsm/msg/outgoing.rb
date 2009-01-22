#!/usr/bin/env ruby
# vim: noet

module Gsm
	class Outgoing
		attr_accessor :recipient, :text
		attr_reader :device, :sent
		
		def initialize(device, recipient=nil, text=nil)
			
			# check that the device is 
			#raise ArgumentError, "Invalid device"\
			#	unless device.respond_to?(:send_sms)
			
			# init the instance vars
			@recipient = recipient
			@device = device
			@text = text
		end
		
		def send!
			@device.send_sms(self)
			@sent = Time.now
			
			# once sent, allow no
			# more modifications
			freeze
		end
		
		# Returns the recipient of this message,
		# so incoming and outgoing messages
		# can be logged in the same way.
		def number
			recipient
		end
	end
end
