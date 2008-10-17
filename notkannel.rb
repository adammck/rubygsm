#!/usr/bin/env ruby
# vim: noet

require "rubygsm"
require "rubygems"
require "net/http"
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
			
			begin
				Net::HTTP.get "localhost", url, 4500
			
			# it's okay if the request failed,
			# but log it anyway
			rescue Errno::ECONNREFUSED
				puts "!! Couldn't GET: #{url}"
			end
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
				begin
					sleep 5
					$mc.send to, txt
					res.write "OK"
				
				# couldn't send the message
				rescue Modem::Error => err
					puts "[!!] #{err.desc}"
					res.write "ERROR"
				end
			
			else
				# the http request didn't
				# include the required params
				res.write "MISSING PARAMS"
			end
		
			res.finish
		end
	end
end


begin
	# initialize the modem
	puts "Initializing Modem..."
	m = Modem.new "/dev/ttyUSB0"
	$mc = ModemCommander.new(m)
	$mc.use_pin(1234)


	# start receiving sms
	k = NotKannel::Receiver.new
	rcv = k.method :incomming
	$mc.receive rcv


	# and sending!
	puts "Running NotKannel..."
	Rack::Handler::Mongrel.run(
		NotKannel::Sender.new,
		:Port=>13013)


# something went wrong during startup
rescue Modem::Error => err
	puts "\n[ERR] #{err.desc}\n"
	puts err.backtrace
end

