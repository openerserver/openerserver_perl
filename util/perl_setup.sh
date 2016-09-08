export PERL_MM_USE_DEFAULT=1
#export PERL_CPANM_OPT="–skip-installed –notest –auto-cleanup=0"
apt-get update
yum update
apt-get -y install gcc make wget libssl-dev cpan
yum -y install gcc make wget openssl-devel cpan

cpan JSON::XS
cpan DBD::SQLite
cpan AnyEvent
cpan EV
cpan Digest::SHA1
cpan Storable::AMF
cpan Geo::IP::PurePerl
cpan IP::QQWry
cpan LWP::MediaTypes
cpan HTTP::Parser2::XS
cpan IO::All
cpan URI::Escape::XS                  
cpan AnyEvent::HTTP
cpan DateTime
cpan String::Random
cpan Email::Valid
cpan Net::DNS
cpan Proc::Daemon
cpan IO::Pty
cpan Net::SSLeay
cpan Net::DNS::ToolKit
cpan AnyEvent::Fork
cpan App::cpanminus
cpan Net::Frame::Layer::DNS
cpan Simple::IPInfo
cpan Crypt::Passwd::XS
cpan Net::Ifconfig::Wrapper
cpan Net::IPAddress::Util
cpan Net::Ping
