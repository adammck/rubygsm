Gem::Specification.new do |s|
	s.name     = "rubygsm"
	s.version  = "0.42"
	s.date     = "2013-10-05"
	s.summary  = "Send and receive SMS with a GSM modem"
	s.email    = "adam.mckaig@gmail.com"
	s.homepage = "http://github.com/adammck/rubygsm"
	s.authors  = ["Adam Mckaig"]
	s.has_rdoc = true

	s.files = [
		"rubygsm.gemspec",
		"README.rdoc",
		"lib/rubygsm.rb",
		"lib/rubygsm/core.rb",
		"lib/rubygsm/errors.rb",
		"lib/rubygsm/log.rb",
		"lib/rubygsm/msg/incoming.rb",
		"lib/rubygsm/msg/outgoing.rb",
		"bin/gsm-modem-band"
	]

	s.executables = [
		"gsm-modem-band",
		"sms"
	]

	s.add_dependency("serialport", [">= 1.1.0"])
end
