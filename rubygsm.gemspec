Gem::Specification.new do |s|
	s.name     = "rubygsm"
	s.version  = "0.2"
	s.date     = "2008-12-18"
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
		"lib/rubygsm/log.rb"
	]
	
	s.add_dependency("toholio-serialport", ["> 0.7.1"])
end
