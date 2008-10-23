#!/usr/bin/env ruby
# vim: noet


if ARGV.empty?
	puts "Usage: inject.rb [SENDER] [MESSAGE]"
	puts
	puts "Creates a file in /tmp/sms, to be collected"
	puts "by notkannel.rb, and injected into the SMS"
	puts "application as if it were a real incoming"
	puts "message."
	exit
end


# if the first argument is a phone number,
# use it as the sender. otherwise, 12345
sender = ARGV.first.match(/^\+?\d+/)\
       ? ARGV.shift : 12345


# the rest of the arguments are
# assumed to be the message body
msg = ARGV.join


rnd = rand(888888) + 111111
fn = "/tmp/sms/#{rnd}.txt"
File.open(fn, "w") do |f|
	f.write "#{sender}: #{msg}"
end

