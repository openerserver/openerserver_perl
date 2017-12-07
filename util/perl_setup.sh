export PERL_MM_USE_DEFAULT=1
#export PERL_CPANM_OPT="–skip-installed –notest –auto-cleanup=0"
apt-get update
yum update
apt-get -y install gcc make wget libssl-dev cpan
yum -y install gcc make wget openssl-devel cpan

cpan -T JSON::XS
cpan -T DBD::SQLite
cpan -T AnyEvent
cpan -T EV
cpan -T Digest::SHA1
cpan -T Storable::AMF
cpan -T Geo::IP::PurePerl
cpan -T IP::QQWry
cpan -T LWP::MediaTypes
cpan -T HTTP::Parser2::XS
cpan -T IO::All
cpan -T URI::Escape::XS                  
cpan -T AnyEvent::HTTP
cpan -T DateTime
cpan -T String::Random
cpan -T Email::Valid
cpan -T Net::DNS
cpan -T Proc::Daemon
cpan -T IO::Pty
cpan -T Net::SSLeay
cpan -T Net::DNS::ToolKit
cpan -T AnyEvent::Fork
cpan -T App::cpanminus
cpan -T Net::Frame::Layer::DNS
cpan -T Simple::IPInfo
cpan -T Crypt::Passwd::XS
cpan -T Net::Ifconfig::Wrapper
cpan -T Net::IPAddress::Util
cpan -T Net::Ping
