#!/usr/bin/env ruby
# vim: noet

here = File.dirname(__FILE__)
require "#{here}/../_setup.rb"
$modem = Gsm::Mock::FailingModem
require "#{here}/../rubygsm.rb"
