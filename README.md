RubyGSM is a rather plain Ruby library (not a Gem yet) which uses
(Ruby/SerialPort)[http://ruby-serialport.rubyforge.org/] to send
and receive SMS messages via a GSM modem.

It also includes notkannel.rb, which provides a similar HTTP interface
to [Kannel](http://kannel.org), which can be used as a fragile drop-in
replacement. It's not for production (yet), but is functional enough to
run [SmsApp](http://githib.com/adammck/smsapp) Applications, including
[Unitard](http://github.com/adammck/unitard).


Devices Tested
==============

Multitech MTCBA-G-F2
Multitech MTCBA-G-F4
Wavecom M1306B
