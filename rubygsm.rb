#!/usr/bin/env ruby
# vim: noet

require "serialport.so"
require "timeout.rb"
require "date.rb"

class Modem
	include Timeout
	
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
			return "Unknown error (unrecognized command?) " +\
			       "[type=#{@type}] [code=#{code}]"
		end
	end
	
	class TimeoutError < Error
		def desc
			return "The command timed out"
		end
	end
	
	
	
	
	attr_reader :device
	attr_accessor :verbosity, :read_timeout, :incoming
	
	def initialize(port, verbosity=:warn, baud=9600, cmd_delay=0.1)
	
		# port, baud, data bits, stop bits, parity
		@device = SerialPort.new(port, baud, 8, 1, SerialPort::NONE)
		
		@cmd_delay = cmd_delay
		@verbosity = verbosity
		@read_timeout = 30
		@locked_to = false
		
		# keep track of the depth which each
		# thread is indented in the log
		@log_indents = {}
		@log_indents.default = 0
		
		# (re-) open the full log file
		@log = File.new "rubygsm.log", "w"
		
		# initialization message (yes, it's underlined)
		msg = "RubyGSM Initialized at: #{Time.now}"
		log msg + "\n" + ("=" * msg.length), :file
		
		# to store incoming messages
		# until they're dealt with by
		# someone else, like a commander
		@incoming = []
		
		# initialize the modem
		command "ATE0"      # echo off
		command "AT+CMEE=1" # useful errors
		command "AT+WIND=0" # no notifications
		command "AT+CMGF=1" # switch to text mode
	end
	
	
	
	
	LOG_LEVELS = {
		:file    => 5,
		:traffic => 4,
		:debug   => 3,
		:warn    => 2,
		:error   => 1 }
	
	def log(msg, level=:debug)
		ind = "  " * (@log_indents[Thread.current] or 0)
		
		# create a 
		thr = Thread.current["name"]
		thr = (thr.nil?) ? "" : "[#{thr}] "
		
		# dump (almost) everything to file
		if LOG_LEVELS[level] >= LOG_LEVELS[:debug]\
		or level == :file
		
			@log.puts thr + ind + msg
			@log.flush
		end
		
		# also print to the rolling
		# screen log, if necessary
		if LOG_LEVELS[@verbosity] >= LOG_LEVELS[level]
			$stderr.puts thr + ind + msg
		end
	end
	
	
	# log a message, and increment future messages
	# in this thread. useful for nesting logic
	def log_incr(*args)
		log(*args) unless args.empty?
		@log_indents[Thread.current] += 1
	end
	
	# close the logical block, and (optionally) log
	def log_decr(*args)
		@log_indents[Thread.current] -= 1\
			if @log_indents[Thread.current] > 0
		log(*args) unless args.empty?
	end
	
	# the last message in a logical block
	def log_then_decr(*args)
		log(*args)
		log_decr
	end
	
	
	
	
	private # ------------------------------------------------------ PRIVATE --
	
	INCOMING_FMT = "%y/%m/%d,%H:%M:%S%Z"
	
	def parse_incoming_timestamp(ts)
		# extract the weirdo quarter-hour timezone,
		# convert it into a regular hourly offset
		ts.sub! /(\d+)$/ do |m|
			sprintf("%02d", (m.to_i/4))
		end
		
		# parse the timestamp, and attempt to re-align
		# it according to the timezone we extracted
		DateTime.strptime(ts, INCOMING_FMT)
	end
	
	def parse_incoming_sms!(lines)
		n = 0
		
		# iterate the lines like it's 1984
		# (because we're patching the array,
		# which is hard work for iterators)
		while n < lines.length
			
			# not a CMT string? ignore it
			unless lines && lines[n] && lines[n][0,5] == "+CMT:"
				n += 1
				next
			end
			
			# since this line IS a CMT string (an incomming
			# SMS), parse it and store it to deal with later
			unless m = lines[n].match(/^\+CMT: "(.+?)",.*?,"(.+?)".*?$/)
				err = "Couldn't parse CMT data: #{buf}"
				raise RuntimeError.new(err)
			end
			
			# extract the meta-info from the CMT line,
			# and the message from the FOLLOWING line
			from, timestamp = *m.captures
			msg = lines[n+1].strip
			
			# just in case it wasn't already obvious...
			log "Received message from #{from}: #{msg}"
			
			# notify the network that we accepted
			# the incoming message (for read receipt)
			# BEFORE pushing it to the incoming queue
			# (to avoid really ugly race condition)
			command "AT+CNMA"
			
			# store the incoming data to be picked up
			# from the attr_accessor as a tuple (this
			# is kind of ghetto, and WILL change later)
			dt = parse_incoming_timestamp(timestamp)
			@incoming.push [from, dt, msg]
			
			# drop the two CMT lines (meta-info and message),
			# and patch the index to hit the next unchecked
			# line during the next iteration
			lines.slice!(n,2)
			n -= 1
		end
	end
	
	
	
	
	public # -------------------------------------------------------- PUBLIC --
	
	
	# send a string to the modem immediately,
	# without waiting for the lock
	def send(str)
		log "Send: #{str}", :traffic
		
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
		
		# include the terminator in the traffic dump,
		# if it's anything other than the default
		#suffix = (term != ["\r\n"]) ? " (term=#{term.inspect})" : ""
		#log_incr "Read" + suffix, :traffic
		
		begin
			timeout(@read_timeout) do
				while true do
					buf << sprintf("%c", @device.getc)
				
					# if a terminator was just received,
					# then return the current buffer
					term.each do |t|
						len = t.length
						if buf[-len, len] == t
							log "Read: #{buf.inspect}", :traffic
							return buf.strip
						end
					end
				end
			end
		
		# reading took too long, so intercept
		# and raise a more specific exception
		rescue Timeout::Error
			log = "Read: Timed out", :traffic
			raise TimeoutError
		end
	end
	
	
	# issue a single command, and wait for the response
	def command(cmd, resp_term=nil, send_term="\r")
		begin
			out = ""
			log_incr "Command: #{cmd}"
			
			exclusive do
				send(cmd + send_term)
				out = wait(resp_term)
			end
		
			# some hardware (my motorola phone) adds extra CRLFs
			# to some responses. i see no reason that we need them
			out.delete ""
		
			# for the time being, ignore any unsolicited
			# status messages. i can't seem to figure out
			# how to disable them (AT+WIND=0 doesn't work)
			out.delete_if do |line|
				(line[0,6] == "+WIND:") or
				(line[0,6] == "+CREG:") or
				(line[0,7] == "+CGREG:")
			end
		
			# parse out any incoming sms that were bundled
			# with this data (to be fetched later by an app)
			parse_incoming_sms!(out)
		
			# log the modified output
			log_decr "=#{out.inspect}"
		
			# rest up for a bit (modems are
			# slow, and get confused easily)
			sleep(@cmd_delay)
			return out
		
		# if the 515 (please wait) error was thrown,
		# then automatically re-try the command after
		# a short delay. for others, propagate
		rescue Modem::Error => err
			log "Rescued: #{err.desc}"
			
			if (err.type == "CMS") and (err.code == 515)
				sleep 2
				retry
			end
			
			log_decr
			raise
		end
	end
	
	
	def query(cmd)
		log_incr "Query: #{cmd}"
		out = command cmd
	
		# only very simple responses are supported
		# (on purpose!) here - [response, crlf, ok]
		if (out.length==2) and (out[1]=="OK")
			log_decr "=#{out[0].inspect}"
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
		log_incr "Waiting for response"
		
		while true do
			buf = read(term)
			buffer.push(buf)
		
			# some errors contain useful error codes,
			# so raise a proper error with a description
			if m = buf.match(/^\+(CM[ES]) ERROR: (\d+)$/)
				log_then_decr "!! Raising Modem::Error #{$1} #{$2}"
				raise Error.new(*m.captures)
			end
		
			# some errors are not so useful :|
			if buf == "ERROR"
				log_then_decr "!! Raising Modem::Error"
				raise Error
			end
		
			# most commands return OK upon success, except
			# for those which prompt for more data (CMGS)
			if (buf=="OK") or (buf==">")
				log_decr "=#{buffer.inspect}"
				return buffer
			end
		
			# some commands DO NOT respond with OK,
			# even when they're successful, so check
			# for those exceptions manually
			if m = buf.match(/^\+CPIN: (.+)$/)
				log_decr "=#{buffer.inspect}"
				return buffer
			end
		end
	end
	
	
	def exclusive &blk
		old_lock = nil
		
		begin
			
			# prevent other threads from issuing
			# commands while this block is working
			if @locked_to and (@locked_to != Thread.current)
				log "Locked by #{@locked_to["name"]}, waiting..."
			
				# wait for the modem to become available,
				# so we can issue commands from threads
				while @locked_to
					sleep 0.05
				end
			end
			
			# we got the lock!
			old_lock = @locked_to
			@locked_to = Thread.current
			log_incr "Got lock"
		
			# perform the command while
			# we have exclusive access
			# to the modem device
			yield
			
		
		# something went bang, which happens, but
		# just pass it on (after unlocking...)
		rescue Modem::Error
			raise
		
		
		# no message, but always un-
		# indent subsequent log messages
		# and RELEASE THE LOCK
		ensure
			@locked_to = old_lock
			Thread.pass
			log_decr
		end
	end
end

class ModemCommander
	def initialize(modem)
		@m = modem
	end
	
	def hardware
		return {
			:manufacturer => @m.query("AT+CGMI"),
			:model        => @m.query("AT+CGMM"),
			:revision     => @m.query("AT+CGMR"),
			:serial       => @m.query("AT+CGSN") }
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
			rescue Modem::Error
				return false
			end
		end
		
		true
	end
	
	
	
	
	# ====
	# NETWORK
	# ====
	
	def signal
		data = @m.query("AT+CSQ")
		if m = data.match(/^\+CSQ: (\d+),/)
			csq = m.captures[0].to_i
			
			# 99 represents "not known or not
			# detectable", which usually means
			# the modem isn't on the network
			if csq==99
				err = "Signal strength unknown"
				raise RuntimeError.new(err)
			end
			
			return csq
			
		else
			err = "Not CSQ data: #{data.inspect}"
			raise RuntimeError.new(err)
		end
	end
	
	# wait until the signal strength
	# is below 99 (not on the network)
	def wait_for_network
		begin
			csq = signal
			
		# keep retrying until the
		# network comes up (if ever)
		rescue RuntimeError
			sleep 1
			retry
		end
		
		# return the last
		# signal strength
		return csq
	end
	
	
	
	
	# ====
	# MESSAGE STORAGE
	# ====
	
	CMGL_STATUS = {
		:all => "ALL",
		:read => "REC READ",
		:unread => "REC UNREAD"
	}
	
	def messages(status=:unread)
		puts @m.query "AT+CMGL=?"
		
		arg = CMGL_STATUS[status]
		msgs = @m.command 'AT+CMGL="STO SENT"'#\"#{arg}\"\r\n", nil, ""
		out = []
		
		unless msgs.pop == "OK"
			err = "Not CMGL data: #{msgs.inspect}"
			raise RuntimeError.new(err)
		end
		
		0.upto((msgs.length/2)-1) do |n|
			meta, msg = msgs[(n*2), 2]
			
			if m = meta.match(/^\+CMGL:\s*(\d+),"(.+?)","(.+?)"$/)
				index, status, caller = *m.captures
				
				out.push [caller, msg]
			end
		end
		
		return out
	end
	
	
	
	# ====
	# SMS RELAYING
	# ====
	
	def send(to, msg)
		
		# the number must be in the international
		# format for some SMSCs (notably, the one
		# i'm on right now) so maybe add a PLUS
		to = "+#{to}" unless(to[0,1]=="+")
		
		# block the receiving thread while
		# we're sending. it can take some time
		@m.exclusive do
			@m.log_incr "Sending SMS to #{to}: #{msg}"
			
			begin
			
				# initiate the sms, and wait for either
				# the text prompt or an error message
				@m.command "AT+CMGS=\"#{to}\"", ["\r\n", "> "]
		
				# send the sms, and wait until
				# it is accepted or rejected
				@m.send "#{msg}#{26.chr}"
				@m.wait
				
			# if something went wrong, we might
			# be stuck in entry mode (which will
			# result in someone getting a bunch
			# of AT commands via sms!) so send
			# an escpae, to... escape
			rescue Exception => err
				@m.log "Rescued #{err}"
				@m.send 27.chr
				@m.wait
			end
			
			@m.log_decr
		end
				
		# if no error was raised,
		# then the message was sent
		return true
	end
	
	def receive(callback, join_thread=false)
		@polled = 0

		@thr = Thread.new do
			Thread.current["name"] = "receiver"
			
			# keep on receiving forever
			while true
				@m.command "AT"
			
				# enable new message notification mode
				# every thirty seconds, in case the
				# modem "forgets" (power cycle, etc)
				if (@polled % 6) == 0
					@m.command "AT+CNMI=2,2,0,0,0"
				end
				
				unless @m.incoming.empty?
					@m.incoming.each do |inc|
						begin
							callback.call *inc
						
						rescue StandardError => err
							puts "Error in callback: #{err}"
						end
					end
				
					@m.incoming.clear
				end
			
				# re-poll every
				# five seconds
				@polled += 1
				sleep(5)
			end
		end
		
		# it's sometimes handy to run single-
		# threaded (like debugging handsets)
		@thr.join if join_thread
	end
end


if __FILE__ == $0
	port = (ARGV.length > 0) ? ARGV[0] : "/dev/ttyUSB0"
	Thread.abort_on_exception = true
	Thread.current["name"] = "main"
	
	begin
		# initialize the modem
		puts "Initializing modem on #{port}..."
		m = Modem.new port
		mc = ModemCommander.new(m)
		mc.use_pin(1234)
		
		# demonstrate that the modem is working
		puts "Identifying hardware..."
		mc.hardware.each do |k,v|
			puts "  #{k}: #{v}"
		end
		
		# wait until the device has a signal
		puts "Waiting for network..."
		str = mc.wait_for_network
		puts "Signal strength: #{str}"
		
		
		# a very simple "application", which
		# reverses and replies to messages
		class ReverseApp
			def initialize(mc)
				@mc = mc
			end
			
			def time(dt=nil)
				dt = DateTime.now unless dt
				#dt.strftime("%I:%M%p, %d/%m")
				dt.strftime("%I:%M%p")
			end
			
			def send(to, msg)
				puts "[OUT] #{time} -> #{to}: #{msg}"
				@mc.send to, msg
			end
			
			def incomming(from, dt, msg)
				puts "[IN]  #{time(dt)} <- #{from}: #{msg}"
				send from, msg.reverse
			end
		end
		
		# wait for incomming sms
		puts "Starting app..."
		rcv  = ReverseApp.new mc
		meth = rcv.method :incomming
		mc.receive meth
		
		# block until ctrl+c
		while true do
			sleep(1)
		end
		
		
	rescue Modem::Error => err
		puts "\n[ERR] #{err.desc}\n"
		puts err.backtrace
	
	
	rescue Interrupt => err
		if m
			puts "Resetting modem..."
			#m.command "AT+CFUN=1"
			m.command "ATZ"
		end
	end
end

