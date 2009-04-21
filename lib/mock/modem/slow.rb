#!/usr/bin/env ruby
# vim: noet

module Gsm
	module Mock
		
		# This modem works perfectly -- it just takes a long time to do
		# it, by introducing a short random delay into each character read
		class SlowModem < Modem
			def getc
				sleep(rand)
				super
			end
		end
	end
end
