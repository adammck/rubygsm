#!/usr/bin/env ruby
# vim: noet

module Gsm
	class Incoming
		attr_reader :device, :sender, :sent, :received, :text
		
		def initialize(device, sender, sent, text)
			
			# move all arguments into read-only
			# attributes. ugly, but Struct only
			# supports read/write attrs
			@device = device
			@sender = sender
			@sent = sent
			@text = text
			
			# assume that the message was
			# received right now, since we
			# don't have an incoming buffer
			@received = Time.now
		end
		
		def to_a
			[@device, @sender, @sent, @text]
		end
	end
end
