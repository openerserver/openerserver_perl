export PERL_MM_USE_DEFAULT=1
#apt-get update
apt-get -y install gcc make wget libssl-dev pptp-linux
yum -y install gcc make wget openssl-devel pptp-linux
wget http://www.cpan.org/src/5.0/perl-5.26.1.tar.gz
tar zxvf perl-5.26.1.tar.gz
cd perl-5.26.1
./Configure -Dprefix=/perl -des
make install
/perl/bin/cpan -T JSON::XS
/perl/bin/cpan -T DBD::SQLite
/perl/bin/cpan -T AnyEvent
/perl/bin/cpan -T EV
/perl/bin/cpan -T Digest::SHA1
/perl/bin/cpan -T Storable::AMF
/perl/bin/cpan -T Geo::IP::PurePerl
/perl/bin/cpan -T IP::QQWry
/perl/bin/cpan -T LWP::MediaTypes
/perl/bin/cpan -T HTTP::Parser2::XS
/perl/bin/cpan -T IO::All
/perl/bin/cpan -T URI::Escape::XS
/perl/bin/cpan -T AnyEvent::HTTP
/perl/bin/cpan -T DateTime
/perl/bin/cpan -T String::Random
/perl/bin/cpan -T Email::Valid
/perl/bin/cpan -T Net::DNS
/perl/bin/cpan -T Proc::Daemon
/perl/bin/cpan -T IO::Pty
/perl/bin/cpan -T Net::SSLeay
/perl/bin/cpan -T Net::DNS::ToolKit
/perl/bin/cpan -T AnyEvent::Fork
/perl/bin/cpan -T App::cpanminus
/perl/bin/cpan -T Net::Frame::Layer::DNS
/perl/bin/cpan -T Simple::IPInfo
/perl/bin/cpan -T Crypt::Passwd::XS
/perl/bin/cpan -T Net::Ifconfig::Wrapper
/perl/bin/cpan -T Net::IPAddress::Util
/perl/bin/cpan -T Net::Ping
