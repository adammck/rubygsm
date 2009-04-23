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
					process(@in.strip)
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
			
			
			def output(str)
				@out << "\r\n#{str}\r\n"
			end
			
			def error
				output("ERROR")
			end
			
			def ok
				output("OK")
			end
			
			def process(cmd)
				
				# catch and parse AT commands, and process
				# them via an instance method of this class
				if m = cmd.match(/^AT\+([A-Z\?]+)(?:=(.+))?$/)
					cmd, flat_args = *m.captures
					meth = "at_#{cmd.downcase}"
					args = parse_args(flat_args)
					
					# process the command, and return OK
					# if it succeeded. if it failed, we'll
					# fall through and return ERROR
					if respond_to?(meth, true) && send(meth, *args)
						return ok
					end
				
				# enable (ATE1) or disable
				# (ATE0) character echo [104]
				elsif m = cmd.match(/^ATE[01]$/)
					@echo = (m.captures[0] == "1") ? true : false
					return ok
				end
				
				error
			end
			
			# Returns the argument portion of an AT command
			# split into an array. This isn't as robust as a
			# real modem, but works for RubyGSM.
			def parse_args(str)
				str.to_s.split(",").collect do |arg|
					arg.strip.sub('"', "")
				end
			end
			
			# ===========
			# AT COMMANDS
			# ===========
			
			def at_cmee(bool)
				true
			end
			
			def at_wind(bool)
				true
			end
			
			def at_cmgf(bool)
				true
			end
		
			def at_csq(*args)
			    	# return a signal strength of
				# somewhere between 20 and 80
				output("+CSQ: #{rand(60)+20},0")
			end

			# reset the modem software
			def at_cfun(bool)
				true
			end
		end
	end
end
