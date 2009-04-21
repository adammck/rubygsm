#!/usr/bin/env ruby
# vim: noet

here = File.dirname(__FILE__)
require "#{here}/../_setup.rb"
$modem = Gsm::Mock::SlowModem
require "#{here}/../rubygsm.rb"
