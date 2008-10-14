RubyGSM is a rather plain Ruby library (not a Gem yet) which uses
Ruby/SerialPort to send and receive SMS messages via a GSM modem.

It also includes notkannel.rb, which provides a similar HTTP interface
to [Kannel](http://kannel.org). It's not for production (yet), but is
functional enough to run [SmsApp](http://githib.com/adammck/smsapp)
Applications, including [Unitard](http://github.com/adammck/unitard).


### Sample Usage
    # initialize the modem
    m = Modem.new("/dev/ttyS0")
    mc = ModemCommander.new(m)

    class ReverseApp
        def initialize(mc)
            @mc = mc
        end

        def send(to, msg)
            puts ">> #{to}: #{msg}"
            @mc.send to, msg
        end

        def incomming(from, msg)
            puts "<< #{from}: #{msg}"
            send from, msg.reverse
        end
    end

    # create an instance of the application, and call
    # the "incomming" method when a new sms arrives
    app = ReverseApp.new(mc)
    mc.receive app.method(:incomming)

### Devices Tested
* Multitech MTCBA-G-F2
* Multitech MTCBA-G-F4
* Wavecom M1306B
