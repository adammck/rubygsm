#!/usr/bin/env ruby
# vim: noet

require "serialport.so"


class Modem
	class Error < StandardError
		ERRORS = {
			"CME" => {
				# ME errors
				3   => "Operation not allowed",
				4   => "Operation not supported",
				5   => "PH-SIM PIN required (SIM lock)",
				10  => "SIM not inserted",
				11  => "SIM PIN required",
				12  => "SIM PUK required",
				13  => "SIM failure",
				16  => "Incorrect password",
				17  => "SIM PIN2 required",
				18  => "SIM PUK2 required",
				20  => "Memory full",
				21  => "Invalid index",
				22  => "Not found",
				24  => "Text string too long",
				26  => "Dial string too long",
				27  => "Invalid characters in dial string",
				30  => "No network service",
				32  => "Network not allowed – emergency calls only",
				40  => "Network personal PIN required (Network lock)",
				103 => "Illegal MS (#3)",
				106 => "Illegal ME (#6)",
				107 => "GPRS services not allowed",
				111 => "PLMN not allowed",
				112 => "Location area not allowed",
				113 => "Roaming not allowed in this area",
				132 => "Service option not supported",
				133 => "Requested service option not subscribed",
				134 => "Service option temporarily out of order",
				148 => "unspecified GPRS error",
				149 => "PDP authentication failure",
				150 => "Invalid mobile class"
			},
			
			# message service errors
			"CMS" => {
				301 => "SMS service of ME reserved",
				302 => "Operation not allowed",
				303 => "Operation not supported",
				304 => "Invalid PDU mode parameter",
				305 => "Invalid text mode parameter",
				310 => "SIM not inserted",
				311 => "SIM PIN required",
				312 => "PH-SIM PIN required",
				313 => "SIM failure",
				316 => "SIM PUK required",
				317 => "SIM PIN2 required",
				318 => "SIM PUK2 required",
				321 => "Invalid memory index",
				322 => "SIM memory full",
				330 => "SC address unknown",
				340 => "No +CNMA acknowledgement expected",
				
				# specific error result codes (also from +CMS ERROR)
				500 => "Unknown error",
				512 => "MM establishment failure (for SMS)",
				513 => "Lower layer failure (for SMS)",
				514 => "CP error (for SMS)",
				515 => "Please wait, init or command processing in progress",
				517 => "SIM Toolkit facility not supported",
				518 => "SIM Toolkit indication not received",
				519 => "Reset product to activate or change new echo cancellation algo",
				520 => "Automatic abort about get PLMN list for an incomming call",
				526 => "PIN deactivation forbidden with this SIM card",
				527 => "Please wait, RR or MM is busy. Retry your selection later",
				528 => "Location update failure. Emergency calls only",
				529 => "PLMN selection failure. Emergency calls only",
				531 => "SMS not send: the <da> is not in FDN phonebook, and FDN lock is enabled (for SMS)"
			}
		}
		
		attr_reader :type, :code
		def initialize(type=nil, code=nil)
			@code = code.to_i
			@type = type
		end
		
		def desc
			# attempt to return something useful
			return(ERRORS[@type][@code])\
				if(@type and ERRORS[@type] and @code)
			
			# fall back to something not-so useful
			return "Unknown error [type=#{@type}] [code=#{code}]"
		end
	end
	
	
	
	
	attr_reader :device, :traffic
	def initialize(port, baud=9600, cmd_delay=1)
	
		# port, baud, data bits, stop bits, parity
		@device = SerialPort.new(port, baud, 8, 1, SerialPort::NONE)
		@cmd_delay = cmd_delay
		
		# enable useful errors
		command("AT+CMEE=1")
	end
	
	
	
	
	# send a string to the modem
	def send(str)
		str.each_byte do |b|
			@device.putc(b.chr)
		end
	end
	
	# read from the modem (blocking) until
	# the term character is hit, and return
	def read(term=nil)
		term = "\r\n" if term==nil
		term = [term] unless term.is_a? Array
		buf = ""
		
		while true do
			buf << sprintf("%c", @device.getc)
			
			# if a terminator was just received,
			# then return the current buffer
			term.each do |t|
				l = t.length
				if buf[-l, l] == t
					return buf.strip
				end
			end
		end
	end
	
	# read from the modem (it actually IS blocking,
	# but will return immediately if there is nothing
	# to read), and return all pending data
	def read_nonblock
		buf = ""
		
		begin
			# keep on reading until
			# there's nothing left
			while true
				buf << @device.read_nonblock(1)
			end
			
		# when no more data is available,
		# return what we buffered so far
		rescue Errno::EAGAIN
			return buf
		end
	end



	
	# issue a single command, and wait for the response
	def command(cmd, resp_term=nil, send_term="\r")
		begin
			send(cmd + send_term)
			out = wait(resp_term)
		
			# most of the time, the command will be echoed back
			# before the response. not useful to us, so drop it
			out.shift if out.first == cmd
		
			# rest up for a bit (modems are
			# slow, and get confused easily)
			sleep(@cmd_delay)
			return out
		
		
		# if the 515 (please wait) error was thrown,
		# then automatically re-try the command after
		# a short delay. for others, propagate
		rescue Modem::Error => err
			if (err.type == "CMS") and (err.code == 515)
				sleep 2
				retry
			end
			
			raise
		end
	end
	
	def query(cmd)
		out = command cmd
		
		# only very simple responses are supported
		# (on purpose!) here - [response, crlf, ok]
		if (out.length==3) and (out[2]=="OK")
			return out[0]
			
		else
			err = "Invalid response: #{out.inspect}"
			raise RuntimeError.new(err)
		end
	end
	
	
	# just wait for a response, by reading
	# until an OK or ERROR terminator is hit
	def wait(term=nil)
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
end

class ModemCommander
	def initialize(modem)
		@busy = false
		@m = modem
	end
	
	
	
	
	# ====
	# SIM PINS
	# ====
	
	def pin_ready?
		@m.command("AT+CPIN?").include? "+CPIN: READY"
	end
	
	def use_pin(pin)
		# if the sim is already ready,
		# this method isn't necessary
		unless pin_ready?
			begin
				@m.command "AT+CPIN=#{pin}"
		
			# if the command failed, then
			# the pin was not accepted
			rescue Mobile::Error
				return false
			end
		end
		
		true
	end
	
	# ====
	# UTILITY
	# ====
	
	def signal
		data = @m.query("AT+CSQ")
		if m = data.match(/^\+CSQ: (\d+),/)
			return m.captures[0].to_i
		else
			err = "Not CSQ data: #{data.inspect}"
			raise RuntimeError.new(err)
		end
	end
	
	
	
	
	# ====
	# SMS
	# ====
	
	def send(to, msg)
		@busy = true
		
		# the number must be in the international
		# format for some SMSCs (notably, the one
		# i'm on right now) so maybe add a PLUS
		to = "+#{to}" unless(to[0,1]=="+")
		
		# initiate the sms, and wait for either
		# the text prompt or an error message
		@m.command "AT+CMGS=\"#{to}\"", ["\r\n", "> "]
		
		# send the sms, and wait until
		# it is accepted or rejected
		@m.send "#{msg}#{26.chr}"
		@m.wait
		
		# if no error was raised,
		# then the message was sent
		@busy = false
		return true
	end
	
	def receive(callback)
		# enable new message indication
		@m.command "AT+CNMI=2,2,0,0,0"
		
		# poll for incomming messages
		# in a separate thread. the @busy
		# flag is used to suspend polling
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
							err = "Not CMT data: #{data.inspect}"
							raise RuntimeError.new(err)
						end
					end
				end
			
				# re-poll every
				# two seconds
				sleep(2)
			end
		end
	end
end


if __FILE__ == $0
	begin
		# initialize the modem
		puts "Initializing Modem..."
		m = Modem.new "/dev/ttyUSB0"
		mc = ModemCommander.new(m)
		mc.use_pin(1234)
		
		
		# demonstrate that the modem is working
		puts "Signal strength: #{mc.signal}"
		
		
		# a very simple "application", which
		# reverses and replies to messages
		class ReverseApp
			def initialize(mc)
				@mc = mc
			end
			
			def send(to, msg)
				puts "[OUT] #{to}: #{msg}"
				@mc.send to, msg
			end
			
			def incomming(from, msg)
				puts "[IN]  #{from}: #{msg}"
				send from, msg.reverse
			end
		end
		
		
		# wait for incomming sms
		puts "Starting App..."
		rcv  = ReverseApp.new mc
		meth = rcv.method :incomming
		mc.receive meth
		
		# block until ctrl+c
		while true do
			sleep(1)
		end
		
		
	rescue Modem::Error => err
		puts "[ERR] #{err.desc}"
	end
end

