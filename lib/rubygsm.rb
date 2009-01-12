#!/usr/bin/env ruby
# vim: noet

dir = File.dirname(__FILE__)
require "#{dir}/rubygsm/core.rb"
require "#{dir}/rubygsm/errors.rb"
require "#{dir}/rubygsm/log.rb"

# messages are now passed around
# using objects, rather than flat
# arguments (from, time, msg, etc)
require "#{dir}/rubygsm/msg/incoming.rb"
require "#{dir}/rubygsm/msg/outgoing.rb"

# during development, it's important to EXPLODE
# as early as possible when something goes wrong
Thread.abort_on_exception = true
Thread.current["name"] = "main"
