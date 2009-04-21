#!/usr/bin/env ruby
# vim: noet

# import rspec
require "rubygems"
require "spec"

# import the main library
here = File.dirname(__FILE__)
require "#{here}/../lib/rubygsm.rb"

# import the mock modems to test against
here = File.dirname(__FILE__)
require "#{here}/../lib/mock/modem.rb"
require "#{here}/../lib/mock/modem/slow.rb"
require "#{here}/../lib/mock/modem/failing.rb"
