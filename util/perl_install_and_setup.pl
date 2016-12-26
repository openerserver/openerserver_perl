export PERL_MM_USE_DEFAULT=1
#apt-get update
apt-get -y install gcc make wget libssl-dev pptp-linux
yum -y install gcc make wget openssl-devel pptp-linux
wget http://www.cpan.org/src/5.0/perl-5.22.2.tar.gz
tar zxvf perl-5.22.2.tar.gz
cd perl-5.22.2
./Configure -Dprefix=/perl -des
make install
/perl/bin/cpan  JSON::XS
/perl/bin/cpan DBD::SQLite
/perl/bin/cpan AnyEvent
/perl/bin/cpan EV
/perl/bin/cpan Digest::SHA1
/perl/bin/cpan Storable::AMF
/perl/bin/cpan Geo::IP::PurePerl
/perl/bin/cpan IP::QQWry
/perl/bin/cpan LWP::MediaTypes
/perl/bin/cpan HTTP::Parser2::XS
/perl/bin/cpan IO::All
/perl/bin/cpan URI::Escape::XS
/perl/bin/cpan AnyEvent::HTTP
/perl/bin/cpan DateTime
/perl/bin/cpan String::Random
/perl/bin/cpan Email::Valid
/perl/bin/cpan Net::DNS
/perl/bin/cpan Proc::Daemon
/perl/bin/cpan IO::Pty
/perl/bin/cpan Net::SSLeay
/perl/bin/cpan Net::DNS::ToolKit
/perl/bin/cpan AnyEvent::Fork
/perl/bin/cpan App::cpanminus
/perl/bin/cpan Net::Frame::Layer::DNS
/perl/bin/cpan Simple::IPInfo
/perl/bin/cpan Crypt::Passwd::XS
/perl/bin/cpan Net::Ifconfig::Wrapper
/perl/bin/cpan Net::IPAddress::Util
/perl/bin/cpan Net::Ping/perl/bin/cpan Net::DNS::ToolKit
/perl/bin/cpan AnyEvent::Fork
/perl/bin/cpan App::cpanminus
/perl/bin/cpan Net::Frame::Layer::DNS
/perl/bin/cpan Simple::IPInfo
/perl/bin/cpan Crypt::Passwd::XS
/perl/bin/cpan Net::Ifconfig::Wrapper
/perl/bin/cpan Net::IPAddress::Util
/perl/bin/cpan Net::Ping
