#!/usr/bin/env ruby
# vim: noet

module Gsm
	module Mock
		class Modem
			attr_reader :echo
			
			def initialize
				@echo = true
				
				@in = ""
				@out = ""
			end
			
			
			# => obj
			def putc(obj)
				#puts "PUTC: #{obj.inspect}"
				
				# accept numeric/string args like IO.putc
				# http://www.ruby-doc.org/core/classes/IO.html#M002276
				chr = (obj.is_a?(Numeric) ? obj.chr : obj.to_s[0])
				@in << chr
				
				# character echo, if required
				@out << chr if(@echo)
				
				# if this character is a terminator (13.chr (\r)), 
				# interpret and clear the @incoming buffer
				if @in[-1] == 13
					got_command @in.strip
					@in = ""
				end
			end

			# Returns the first byte (er, actually, the first CHARACTER,
			# which will no-doubt be a future source of bugs) of the
			# output buffer, or nil, if it's empty.
			def getc
				#puts "GETC: #{@out.inspect}"
				(@out.empty?) ? nil : @out.slice!(0)
			end
			
			
			private
			
			def output(str)
				@out << str + "\r\n"
			end
			
			def got_command(cmd)
				
				# enable (ATE1) or disable
				# (ATE0) character echo [104]
				if m = cmd.match(/^ATE[01]$/)
					@echo = (m.captures[0] == "1") ? true : false
					output "OK"
					
				else
					#raise NotImplementedError
					output "ERROR"
				end
			end
		end
	end
end
