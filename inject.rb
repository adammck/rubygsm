#!/usr/bin/env ruby
# vim: noet

# create the target dir, if necessary
path = "/tmp/sms"
`mkdir #{path}`\
unless File.exists?(path)


while true
	msg = gets
	sender = 123456789
	
	# if the line starts with a phone number,
	# use it as the sender. otherwise, 12345
	pat = /^\+?(\d+)\s*/
	if m = msg.match(pat)
		sender = m.captures[0]
		msg.gsub! pat, ""
	end

	# save the line to a badly-calculated
	# random file in /tmp/sms, to be picked
	# up by notkannel.rb and injected
	rnd = rand(888888) + 111111
	fn = "/tmp/sms/#{rnd}.txt"
	File.open(fn, "w") do |f|
		f.write "#{sender}: #{msg}"
	end
end

