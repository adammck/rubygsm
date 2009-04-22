#!/usr/bin/env ruby
# vim: noet

module Gsm
	module Mock
		
		# This modem is deliberately a giant pain in the ass, by failing every
		# single command with a random error once, then allowing it through, the
		# next time a round. This will (hopefully) ensure that all parts of RubyGSM
		# are tolerant of weird modem errors.
		class FailingModem < Modem
			def process(cmd)
				if @last_command != cmd
					code = (rand * 200).to_i
					type = ((rand * 5) > 0.5) ? "CME" : "CMS"
					output("#{type} ERROR: #{code}")
					@last_command = cmd
				else
					super
				end
			end
		end
	end
end
