#!/usr/bin/env ruby
# vim: noet

require "serialport.so"


class Modem
	class Error < StandardError
		ERRORS = {
			"CME" => {
				5  => "PH-SIM PIN required (SIM lock)",
				10 => "SIM not inserted",
				11 => "SIM PIN required",
				12 => "SIM PUK required",
				13 => "SIM failure"
			},
			"CMS" => {
				311 => "SIM PIN required"
			}
		}
		
		attr_reader :type, :code
		def initialize(type=nil, code=nil)
			@type = type
			@code = code
		end
		
		def desc
			return(ERRORS[@type][@code.to_i])\
				if(@type and ERRORS[@type] and @code)
		end
	end
	
	# raised when we try to do something that
	# isn't allowed because the SIM isn't ready
	# (like sending an sms before setting the pin)
	class NotReadyError < StandardError
	end
	
	
	attr_reader :device, :traffic
	def initialize(port, baud=9600)
		# port, baud, data bits, stop bits, parity
		@device = SerialPort.new(port, baud, 8, 1, SerialPort::NONE)
		@buffer = []
		
		#command("ATE1")
		#command("AT+CFUN=1")
		command("AT+CMEE=1") # enable useful errors
		command("AT+CNMI=2,2,0,0,0")
	end
	
	def debug(*args)
		puts(*args)
	end
	
	# send a STRING to the modem
	def send(str)
		debug "SENDING: #{str.inspect}"
		
		str.each_byte do |b|
			debug "send: #{b.chr}"
			@device.putc(b.chr)
		end
		
		debug "SENT"
	end
	
	# read from the modem (blocking) until
	# the term character is hit, and return
	def read(term=nil)
		term = "\r\n" if term==nil
		term = [term] unless term.is_a? Array
		buf = ""
		
		debug "terminators: #{term.inspect}"
		
		while true do
			buf << sprintf("%c", @device.getc)
			debug "buf: #{buf.inspect}"
			
			# if a terminator was just received,
			# then return the current buffer
			term.each do |t|
				if buf.end_with?(t)
					outp = buf.strip
					debug "terminated by: #{t.inspect}"
					debug "returning: #{outp.inspect}"
					return outp
				end
			end
		end
	end
	
	def read_nonblock
		buf = ""
		
		begin
			# keep on reading until
			# there's nothing left
			while true
				buf << @device.read_nonblock(1)
				puts "nbbuf: #{buf.inspect}"
			end
			
		# when no more data is available,
		# return what we buffered so far
		rescue Errno::EAGAIN
			puts "nb returning: #{buf.inspect}"
			return buf
		end
	end

	
	# send the command and teminator
	def command(cmd, resp_term=nil, send_term="\r")
		debug "\n----> #{cmd}"
		
		send(cmd + send_term)
		out = wait_for_response(resp_term)
		
		# most of the time, the command will be echoed back
		# before the response. not useful to us, so drop it
		out.shift if out.first == cmd
		debug "--> #{out.inspect} <--"
		
		sleep(1)
		return out
	end
	
	
	# just wait for a response, by reading
	# until an OK or ERROR terminator is hit
	def wait_for_response(term=nil)
		buffer = []

		while true do
			buf = read(term)
			buffer.push(buf)
			
			# some errors contain useful error codes,
			# so raise a proper error with a description
			if m = buf.match(/^\+(CM[ES]) ERROR: (\d+)$/)
				raise Error.new(*m.captures)
			end
			
			# some errors are not so useful :|
			raise Error if(buf == "ERROR")
			
			# most commands return OK upon success, except
			# for those which prompt for more data (CMGS)
			if (buf=="OK") or (buf==">")
				return buffer
			end
			
			# some commands DO NOT respond with OK,
			# even when they're successful, so check
			# for those exceptions manually
			if m = buf.match(/^\+CPIN: (.+)$/)
				return buffer
			end
		end
	end
	
	def receive
		puts @m.read_noblock
	end
	
	def close
		@device.close
	end
end

class ModemCommander
	def initialize(modem)
		@busy = false
		@m = modem
	end
	
	def identify
		# returns: manufacturer, model, revision, serial
		[ @m.query("CGMI"), @m.query("CGMM"), @m.query("CGMR"), @m.query("CGSN") ]
	end
	
	def use_pin(pin)
		# if the sim is already ready,
		# we have already entered a pin,
		# or else it isn't necessary
		return(true) if ready?
		
		begin
			@m.command("AT+CPIN=#{pin}")
			return ready?
		
		# if the command failed, then
		# the pin was not accepted
		rescue Mobile::Error
			return false
		end
	end
	
	def ready?
		return(@m.command("AT+CPIN?") == ["+CPIN: READY"])
	end
	
	def send(to, msg)
		@busy = true
		
		# initiate the sms, and wait for either
		# the text prompt or an error message
		@m.command("AT+CMGS=\"#{to}\"", ["\r\n", "> "])
		
		# send the sms, and wait until
		# it is accepted or rejected
		@m.send("#{msg}#{26.chr}")
		@m.wait_for_response
		
		# if no error was raised,
		# then the message was sent
		@busy = false
		return true
	end
	
	def receive(callback)
		Thread.new do
			while true
				if !@busy and (data = @m.read_nonblock)
					unless data.empty?
						
						# (attempt to) parse the incomming sms, and
						# pass the data back to the callback method
						if m = data.match(/^\+CMT: "(.+?)"(.*?)\r\n(.+)$/)
							caller, meta, msg = *m.captures
							callback.call caller, msg.strip
							
						else
							# for now, croak when receiving data
							# other than incomming sms. we should
							# probably re-insert into the queue...
							raise RuntimeError.new\
								"Got unexpected data: #{data.inspect}"
						end
					end
				end
			
				# re-check every
				# two seconds
				puts "sleeping (#{@busy})"
				sleep(2)
			end
		end
	end
end


if __FILE__ == $0
	begin
		# initialize the modem
		m = Modem.new "/dev/ttyUSB0"
		$mc = ModemCommander.new(m)
		
		
		
		
		require "net/http"
		require "rubygems"
		require "rack"
		
		module NotKannel
		
			# incomming sms are http GETted to
			# localhost, where an app should be
			# waiting to do something interesting
			class Receiver
				def incomming caller, msg
					puts "<< #{caller}: #{msg}"
					msg = Rack::Utils.escape(msg)
					url = "/?sender=#{caller}&message=#{msg}"
					Net::HTTP.get "localhost", url, 4500
				end
			end
			
			# outgoing sms are send from the app
			# to us (as if we were kannel), and
			# pushed to the modem
			class Sender
				def call(env)
					req = Rack::Request.new(env)
					res = Rack::Response.new
					
					# required parameters (the
					# others are just ignored)
					to = req.GET["to"]
					txt = req.GET["text"]
					
					if to and txt
						puts ">> #{to}: #{txt}"
						$mc.send to, txt
						res.write "OK"
						
					else
						puts env.inspect
						res.write "MISSING PARAMS"
					end
					
					res.finish
				end
			end
		end
		
		# start receiving sms
		k = NotKannel::Receiver.new
		rcv = k.method :incomming
		$mc.receive rcv
		
		# and sending!
		Rack::Handler::Mongrel.run(
			NotKannel::Sender.new,
			:Port=>13013)

	rescue Modem::Error => err
		puts "!! Error: #{err.desc}"

	ensure
		#m.close
	end
end

