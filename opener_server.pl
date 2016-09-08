#!/usr/bin/perl

use strict;
our $VERSION=1.0;

use Data::Dumper;
use EV;
use AnyEvent;

use AnyEvent::Handle;
use AnyEvent::Socket;
use AnyEvent::Util;
use LWP::MediaTypes qw(guess_media_type);
use JSON::XS;
use HTTP::Parser2::XS;
use IO::All;
use Encode qw/encode decode encode_utf8 decode_utf8/;
use URI::Escape::XS qw/encodeURIComponent decodeURIComponent/;
use Cwd;
use AnyEvent::HTTP;
use AnyEvent::Fork;
use Digest::MD5 qw(md5 md5_hex md5_base64);


########## for perl devkit complie 2015-01-20 #################
if (defined $AnyEvent::MODEL) {
   # AnyEvent already initialised, so load Coro::AnyEvent
#   require AnyEvent::Impl::EV;
} else {
   # AnyEvent not yet initialised, so make sure to load Coro::AnyEvent
   # as soon as it is
#   push @AnyEvent::post_detect, sub { require AnyEvent::Impl::EV };
}

my $cvar = AnyEvent->condvar;
my $self={};
my $g={}; ## 外部程序的function
$self->{out_function}=\$g;

my $n={}; ## 内部程序的function
$self->{in_function}=\$n;

my $config={};
$self->{out_config}=\$config; ## 外部程序的 配置

my $timer={}; ## 外部计时器
$self->{out_timer}=\$timer;

my $url_reg={}; ### url 注册列表
$self->{url_reg}=\$url_reg;

my $http_header_split="\015\012\015\012";
my $normal_split="\015\012";

my $w32encoding;
if ($^O eq 'MSWin32') {
	eval{ 
		require Win32::Codepage::Simple;
		$w32encoding='cp'.Win32::Codepage::Simple::get_codepage();
		};
	if ($@) {
		$n->{logs}->("Win32::Codepage::Simple not install");
	}
}

#$n->{new_http_server}->(undef,80);
#$n->{new_https_server}->(undef,443,'jingxiang.net.pem');
sub test_work_dir{
	unless (-d './upload') {
		mkdir './upload';
	}
}

$self->{log_count}=0;
$self->{display_debug}=1;
$self->{log_max_size}=1000000;
$self->{manager_port}=10008;

if ($ARGV[0]>10008) {
	$self->{manager_port}=$ARGV[0];
}
if ($ARGV[1] eq '0') {
	$self->{autorun_startup}=0;
}else{
	$self->{autorun_startup}=1;
}

$n->{new_manager_server}=sub {
#	test_work_dir();
#	$n->{new_http_server}->(undef,'10009');
	unless ($n->{new_https_server}->(undef,$self->{manager_port},'opener.pem')) {
		die "manager start error, no pem file\n";
	}
};


$n->{new_http_server}=sub {
	my($server_host,$server_port,$timeout,$max_form_data)=@_;
	unless ($timeout) {
		$timeout=$self->{default_server_config}->{timeout};
	}
	unless ($max_form_data) {
		$max_form_data=$self->{default_server_config}->{max_form_data};
	}
	unless ($server_host) {
		$server_host=undef;
	}
	unless ($n->{create_http_server}->($server_host,$server_port,0,$timeout,$max_form_data)) {
		return 0;
	}
	return 1;
};
$n->{new_https_server}=sub {
	my($server_host,$server_port,$cert_file,$timeout,$max_form_data)=@_;
	unless ($timeout) {
		$timeout=$self->{default_server_config}->{timeout};
	}
	unless ($max_form_data) {
		$max_form_data=$self->{default_server_config}->{max_form_data};
	}
	unless ($server_host) {
		$server_host=undef;
	}
	if ($cert_file=~/^http(.*)\?opener(.*)\&file=(.*)/) { ### https://www.aa.com/ssl_pem_down?opener=14124&file=ovpn_in.pem  必须这个结构
		my $ssl_file=$3;
		my $cc= AnyEvent->condvar; ### 这里下载证书，并阻断并不是最佳方案。 以后可以考虑去除，全部以消息推送来传递消息。
		$cc->begin;
		$n->{http_download}->($cert_file,$ssl_file,sub{
			if ($_[0]) {
				unless ($n->{create_http_server}->($server_host,$server_port,$ssl_file,$timeout,$max_form_data)) {
					$cc->send(0);
				}else{
					$cc->send(1);
				}
		   } elsif (defined $_[0]) {
			  $n->{logs}->('please retry later $cert_file');
			  $cc->send(0);
		   } else {
			   $n->{logs}->("$cert_file not exists");
			  $cc->send(0);
		   }
		});
		my $results =$cc->recv;
		return $results;
	}else{
		if (-e $cert_file) {
			unless ($n->{create_http_server}->($server_host,$server_port,$cert_file,$timeout,$max_form_data)) {
				return 0;
			}
		}else{
			$n->{logs}->("ssl file:$cert_file not exists");
			return 0;
		}
	}
	return 1;
};

$n->{create_http_server}=sub{
	my($server_host,$server_port,$ssl,$timeout,$max_form_data)=@_;
	eval{
		$self->{daemon}->{"$server_host,$server_port"}=tcp_server $server_host,$server_port, sub {
			my ($fh, $host, $port) = @_;
			$n->{handle_http_server_data}->($fh, $host, $port,$ssl,$server_host,$server_port,$timeout,$max_form_data);
		} ;
	};
	if ($@) {
		$n->{logs}->("Dup port for http server:$server_host,$server_port");
		return 0;
	}
	return 1;
};


$n->{handle_http_server_data}=sub {
	my ($fh,$host,$port,$cert_file,$server_host,$server_port,$timeout,$max_form_data) = @_;
	my $key="$host,$port";
	$self->{server}->{$key}=AnyEvent::Handle->new (
		fh => $fh,
		timeout => $timeout, 
		max_form_data => $max_form_data,
		server_ip=>$server_host,
		server_port=>$server_port,
		client_ip=>$host,
		client_port=>$port,
#		autocork=>1,  ## wait for a little time before send.
		keepalive=>1,
#		($cert_file? (tls => "accept", tls_ctx =>{cert_file=>$cert_file,prepare=>sub{Net::SSLeay::CTX_set_read_ahead ($_[0]->ctx, 0)}}): ()), ### CTX_set_read_ahead 设置提前读入的值为0
		($cert_file? (tls => "accept", tls_ctx =>{cert_file=>$cert_file}): ()), 
		on_error => sub {
			my ($hdl, $fatal, $msg) = @_;
			$n->{logs}->("server: $key, $fatal, $msg");
			$n->{on_disconnect}->($key);
		},
		on_read => sub {
#			$n->{logs}->($n->{handle_http_server_data}->{rbuf});
			$self->{server}->{$key}->unshift_read (line =>
			  $http_header_split,
			  sub {
				my ($hdl, $data) = @_;
				my $r={};
				$r->{_header}=$data; ### header中不包含双回车换行
				$data.=$http_header_split;
				my $rv = parse_http_request($data, $r);
				if ($rv == -1 ||$rv == -2) {
					$n->{logs}->("$key header parse error:$data\n");
					$n->{on_disconnect}->($key);
					return 0;
				} 
#				$n->{logs}->(Dumper($r));
#				$n->{logs}->("$r->{_uri}\n");
				$n->{process_http_request}->($r,$key);

				});
		},
	);
};

### url 匹配顺序 先找host:port，然后找*.host:port, 然后*:port，最后找*:*
### $r->{_uri} 以/ 开头
### $r->{_uri}先精确匹配，然后匹配带 /*的 url_reg数据，例如：$r->{_uri}= /aa/bb/cc ,url_reg->{$host}->{'/aa/*'} ,最后就会匹配这个。

$n->{process_http_request}=sub {
	my $r=shift;
	my $key=shift;
	my ($host,$port);
	unless ($r->{_method} eq 'CONNECT') {
		($host,$port)=split(':',$r->{host}->[0]);
		unless ($port) {
			$port=$self->{server}->{$key}->{server_port};
		}
	}else{ ### 代表这个是https代理服务器的connect 通道请求
		$host='*';
		$port=$self->{server}->{$key}->{server_port};
		$r->{_uri}='/*';
	}
	
#	$n->{logs}->("$host,$port");
	unless (exists $url_reg->{"$host:$port"}) { ## 如果没有明确的host 定义的话
		
		my @aa=split('\.',$host); 
		my $f=0;
		while (@aa) {
			shift @aa;
			my $h='*.'.join('.',@aa);
			if (exists $url_reg->{"$h:$port"}) {
				$host="$h:$port";
				$f=1;
				last;
			}
		}
		unless ($f) {
			if (exists $url_reg->{'*:'.$port}) {
				$host='*:'.$port;
			}else{
				$host='*:*'; ### 默认，缺省的地址，必须存
				}
		}
	}else{
		$host="$host:$port";
	}
#	$n->{logs}->($r->{_uri});
	if (substr($r->{_uri},0,7) eq 'http://') {
		$r->{_proxy_url}=$r->{_uri};
		my $hh=length $r->{host}->[0];
		$r->{_uri}=substr($r->{_uri},7+$hh);
	}elsif (substr($r->{_uri},0,8) eq 'https://') {
		$r->{_proxy_url}=$r->{_uri};
		my $hh=$r->{host}->[0];
		$r->{_uri}=substr($r->{_uri},8+$hh);
	}else{}
	if (exists $url_reg->{$host}->{$r->{_uri}} ) {
		$n->{process_uri}->($r->{_uri},$r,$key,$host);
	}else{
		my @bb=split('/',$r->{_uri});
		my @cc;
		while (@bb) {
			my $h=join('/',@bb).'/*'; ### url_reg的时候必须加/*, 才能代表匹配下面所有的数据
			if (exists $url_reg->{$host}->{$h}) {
				$r->{_uri}="/".join('/',@cc); ### 将$r->{_uri} 重新更改为匹配后面剩余的部分。
				$n->{process_uri}->($h,$r,$key,$host);
				return 1;
			}
			unshift @cc,pop @bb;
		}
		if (exists $url_reg->{$host}->{'/*'}) { ### 专门用来匹配 '/*'
			$n->{process_uri}->('/*',$r,$key,$host);
			return 1;
		}
		$n->{send_response_error}->($r,$key,'404','reg not found:'.$r->{_request_uri});
	}
	return 1;
};

$n->{process_uri}=sub {
	my ($uri,$r,$key,$host)=@_;
	$self->{default_server_config}->{process_uri}={host=>$host,uri=>$uri};
	if($r->{_method} eq 'OPTIONS' && exists $r->{'access-control-request-method'}){ ### specail for cross domain ajax post 
		my $res = "$r->{_protocol} 200 OK\015\012";
		my $hdr={};
		$hdr->{'Access-Control-Allow-Origin'}= $r->{origin}->[0];
		$hdr->{'Access-Control-Allow-Methods'} =$r->{'access-control-request-method'}->[0];
		$hdr->{'Access-Control-Allow-Headers'} =$r->{'access-control-request-headers'}->[0];
		$hdr->{'Access-Control-Max-Age'} = 1728000;
		$r->{'_keepalive'} ? $hdr->{'Connection'} = 'keep-alive' : $hdr->{'Connection'} = 'close';
		$hdr->{'Date'} = AnyEvent::HTTP::format_date(time);
		$hdr->{'Expires'} = $hdr->{'Date'};
		$hdr->{'Cache-Control'} = "max-age=0";
		$hdr->{'Content-Length'} = 0;
		
		$hdr->{'Content-Type'} = 'text/plain';
		while (my ($h, $v) = each %$hdr) {
		   $res .= "$h: $v\015\012";
		}
		$res .= "\015\012";
		if (exists $self->{server}->{$key}) {
			$self->{server}->{$key}->push_write($res);
		}
		unless ($r->{'_keepalive'}) {
			$n->{on_disconnect}->($key);
		}
		return 1;
	}elsif ($url_reg->{$host}->{$uri}->{type} eq 'file_down') {  ### 单个文件的下载
		$n->{send_file}->($url_reg->{$host}->{$uri}->{go},$r,$key,1);
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'file') {  ### 单个文件的浏览
		$n->{send_file}->($url_reg->{$host}->{$uri}->{go},$r,$key);
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'file_index') {  ### 文件目录的浏览
		$n->{send_file_index}->($url_reg->{$host}->{$uri}->{go},$r,$key);
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'file_root') {  ### 根目录
		my $file=$url_reg->{$host}->{$uri}->{go}.$r->{_uri};
		if (-d $file) {	 ### 如果给定的$r->{_uri} 为一个目录，则返回该目录下的index.html文件，否则返回错误。
			if (-e $file.'\index.html') {
				$n->{send_file}->($file.'\index.html',$r,$key);
			}else{
				$n->{send_response_error}->($r,$key,'404','not found:'.$r->{_request_uri});
			}
		}elsif (-e $file) {	
			$n->{send_file}->($file,$r,$key);
		}
		else{
			$n->{send_response_error}->($r,$key,'404','not found:'.$r->{_request_uri});
		}
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'http_get') {  ### 普通的get处理。用于常用的get一个虚拟地址，返回处理好的数据
		if (exists $r->{_query_string}) {
			foreach my $e (split('&',$r->{_query_string})) {
				my($k,$v)=split('=',$e);
				$r->{_query_string_hash}->{$k}=$v;
			}
		}
		$url_reg->{$host}->{$uri}->{go}->($r,$key);
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'form_post' && $r->{_method} eq 'POST') { ### form的post 处理
		$n->{form_post}->($url_reg->{$host}->{$uri}->{go},$r,$key);
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'html5_file_post' && $r->{_method} eq 'POST') { ###针对html5的文件上传。使用ajax post模式上传文件。上传成功后调用go
		$n->{html5_file_post}->($url_reg->{$host}->{$uri}->{go},$r,$key);
	}elsif($url_reg->{$host}->{$uri}->{type} eq 'ajax_post' && $r->{_method} eq 'POST') { ###普通的ajax的post处理
		$n->{ajax_post}->($url_reg->{$host}->{$uri}->{go},$r,$key);
	}else{
		$n->{logs}->("$key no uri process:$uri,$url_reg->{$host}->{$uri}->{type}");
		$n->{on_disconnect}->($key);
		return 0;
	}
	return 1;
};

$n->{ajax_post}=sub {
	my ($go,$r,$key)=@_;
	if ($r->{_content_length}) {
		$self->{server}->{$key}->push_read (chunk=>$r->{_content_length},sub{
			my ($hdl, $data) = @_;
			$go->($r,$key,$data);
		});
	}else{
		$go->($r,$key,'');
	}
};

$n->{html5_file_post}=sub {  ### html5 file upload

	my ($go,$r,$key)=@_;
	if ($r->{_content_length}) {
		$self->{server}->{$key}->push_read (chunk=>$r->{_content_length},sub{
			my ($hdl, $data) = @_;
			#print Dumper $r;
			my $filename=$n->{put_local_name}->($r->{file_name}->[0]);
			if ($r->{startflag}->[0]) { ### start upload, send file info.
				unless (-e $filename) { ### create file, pre write file.
					if ($r->{file_size}->[0]>30000000000) { ## max up load 30G file
						$n->{send_response_error}->($r,$key,'404','up file size too bigger 30G');
						return 0;
					}
					if ($r->{file_split}->[0]<100000) { ## the smallest split: 100k
						$n->{send_response_error}->($r,$key,'404','file split too small');
						return 0;
					}
					my $offest=0;
					$self->{upload}->{$r->{file_name}->[0]}={statue=>'uping',filesize=>$r->{file_size}->[0],'filesplit'=>$r->{file_split}->[0],filename=>$r->{file_name}->[0]};					
					while(1) {
						$self->{upload}->{$r->{file_name}->[0]}->{un_piece}->{$offest}=$r->{file_split}->[0];
						$r->{file_size}->[0]-=$r->{file_split}->[0];
						if ($r->{file_size}->[0]<=0) {
							$self->{upload}->{$r->{file_name}->[0]}->{un_piece}->{$offest}=$r->{file_split}->[0]+$r->{file_size}->[0];
							last;
						}
						$offest+=$r->{file_split}->[0];		
					}
					open(FILE,">",$filename);
					write(FILE,'0'x$r->{file_size}->[0]);
					close(FILE);
					$n->{send_normal_resp}->($r,$key,'start upload ok');
				}else{
					$n->{send_response_error}->($r,$key,'404','dup filename');
					$n->{logs}->($filename." exists");
				}
			}elsif($r->{contentflag}->[0]){ ### content upload. this is also for resume upload.
				if (exists $self->{upload}->{$r->{file_name}->[0]}->{un_piece}->{$r->{send_start}->[0]}) {
					open(FILE,"+<",$filename);
					seek(FILE,$r->{send_start}->[0],0);
					syswrite(FILE,$data);
					close(FILE);
					$self->{upload}->{$r->{file_name}->[0]}->{finish_byte}+=$self->{upload}->{$r->{file_name}->[0]}->{un_piece}->{$r->{send_start}->[0]};
					delete $self->{upload}->{$r->{file_name}->[0]}->{un_piece}->{$r->{send_start}->[0]};
					if ($self->{upload}->{$r->{file_name}->[0]}->{finish_byte} == $self->{upload}->{$r->{file_name}->[0]}->{filesize}) {
						$self->{upload}->{$r->{file_name}->[0]}->{statue}='done'; ### upload finish
						$go->($r,$key,$self->{upload}->{$r->{file_name}->[0]});
					}
					$n->{send_resp}->($r,$key,$self->{upload}->{$r->{file_name}->[0]}->{finish_byte}/$self->{upload}->{$r->{file_name}->[0]}->{filesize});
				}else{
					$n->{send_response_error}->($r,$key,'404','up file piece error');
					return 0;
				}	
			}else{
				$n->{send_response_error}->($r,$key,'404','No right http header');
			}	
		});
	}
};

$n->{form_post}=sub {
	## post small data to server include small file upload.
	### post form: multipart/form-data x-www-form-urlencoded
	### if upload size upto max_form_data, the process is bad;
	my ($go,$r,$key)=@_;
	if ($r->{_content_length}>$self->{server}->{$key}->{max_form_data} || $r->{_content_length} <1) { ## max upload file:2M
		$n->{send_response_error}->($r,$key,'404','File upload size max:2M or size=2');
		return 0;
	}
	if ($r->{'content-type'}->[0]) {
		$self->{server}->{$key}->push_read (chunk=>$r->{_content_length},sub{
			my ($hdl, $data) = @_;
			my($type,$b)=split(/\s*;\s*/,$r->{'content-type'}->[0]);
			if ($type =~/multipart\/form-data/) {
				my ($a,$boundary)=split('boundary=',$b);
				$boundary=$normal_split.'--'.$boundary;
				my @c=split($boundary,$data);
				$c[0]=substr($c[0],(length $boundary)-2); ### del normal_split from the begin of boundary
				pop @c; ### del the last word "--"
				my $hh=[];
				foreach my $one (@c) {
					$one=~m/(.*?)$http_header_split(.*)/s;
					my @h=split($normal_split,$1);
					my $post_data=$2;
					shift @h;
					foreach  (@h) {
						my ($name,$co)=split(/\s*:\s*/,$_);					
						if ($name eq 'Content-Disposition') {
							my @list=split /\s*;\s*/, $co;
							shift @list;
							foreach  (0...(@list-1)) {
								my ($n,$f)=split('=',$list[$_]);
								$f=~s/\"(.*)\"/$1/s;
								if ($_==0) {
									push @$hh,{$n=>$f,content=>$post_data};
								}else{
									$hh->[-1]->{$n}=$f;
								}
							}
						}else{
							$hh->[-1]->{$name}=$co;
						}
					}
				}
				$go->($r,$key,$hh);
			}elsif($type=~ /x-www-form-urlencoded/) {
				my $get=$n->{parse_urlencoded}->($data);
				$go->($r,$key,$get);
			}else{
				$n->{send_response_error}->($r,$key,'404','Not support content type');
				return 0;
			}
		});
	}else{
		$n->{send_response_error}->($r,$key,'404','No content type');
		return 0;
	}
};

$n->{write_file}=sub {
	my ($name,$content,$path)=@_;
	my $file;
	if ($path) {
		$file=$path.$n->{put_local_name}->($name);
	}else{
		$file='upload\\'.$n->{put_local_name}->($name);
	}
	$n->{logs}->("write file:$file\n");
	$content > io($file)->binary;
};

$n->{parse_urlencoded}=sub {
   my ($data) = @_;
   my (@pars) = split /\&/, $data;
   my $cont = {};
   for (@pars) {
      my ($name, $val) = split /=/, $_;
      $name = decodeURIComponent ($name);
      $val  = decodeURIComponent ($val);
	  $cont->{$name}=$val;
   }
   $cont
};

$n->{send_file}=sub {
	my ($go,$r,$key,$flag)=@_;
	if (-e $go) {
		my $size= -s $go;
		my $f=io($go);
		$f->binary;
		my $res = "$r->{_protocol} 200 OK\015\012";
		my $hdr={};
		$hdr->{'Connection'} = $r->{'connection'}->[0];
		$hdr->{'Date'} = AnyEvent::HTTP::format_date(time);
		$hdr->{'Expires'} = $hdr->{'Date'};
		$hdr->{'Access-Control-Allow-Origin'} = '*';
		$hdr->{'Cache-Control'} = "max-age=0";
		$hdr->{'Content-Length'} = $size;
		$hdr->{'Content-Type'} = guess_media_type($go);
		if ($flag) {
			$hdr->{'Content-Disposition'} = 'attachment; filename="'.$f->filename.'"';
		}

		while (my ($h, $v) = each %$hdr) {
		   $res .= "$h: $v\015\012";
		}
		$res .= "\015\012";
		
		if ($size > 1024000) {
			$f->block_size(512000);
			my $b;
			$f->sysread($b,512000);
			$res .= $b;
			my $read=length $b;
			if (exists $self->{server}->{$key}) {
				$self->{server}->{$key}->push_write($res);
			}
			$self->{server}->{$key}->on_drain(sub{
				$f->sysread($b,512000);
				$read+=length $b;
				if (exists $self->{server}->{$key}) {
					$self->{server}->{$key}->push_write($b);
				}
				if ($read >= $size) {
					$self->{server}->{$key}->on_drain(sub{});
				}
			});
		}else{
			$res .= $f->all;
			if (exists $self->{server}->{$key}) {
				$self->{server}->{$key}->push_write($res);
			}
		}
	}else{
		$n->{send_response_error}->($r,$key,'404',' File not exists');
	}	
};

$n->{send_file_index}=sub {
	my ($go,$r,$key)=@_;
	if (-d $go) {
		my ($a,$location,$content);
		if ($r->{_query_string}) {  ## 如何处理 ?aa=ss 这样的参数，这里有实例
			($a,$location)=split('=',$r->{_query_string});
		}
		$location=decodeURIComponent($location);
		if ($go eq '.') {
			$go=cwd();
		}
		my $dest=$go.$location;
		if (-d $dest) {
			my $body='<h3>'.'<a href="'.$r->{_uri}.'">ROOT</a>'; ## file list header
			my $con;
			foreach  (split('/',$location)) {
				$con.=encodeURIComponent($_);
				$body.='<a href="'.$r->{_uri}.'?file='.$con.'">'.$n->{get_utf8_name}->($_).'</a>'.'\\';
				$con.='/';
			}
			$body.='</h3>';
			my $io=io($dest);
			$io->chdir($go);
			$io->relative;
			my $deep=1;
			foreach  ($io->all_dirs($deep)) {
				$body.='Folder: ';
				my $href=$r->{_uri}.'?file='.encodeURIComponent($location."/".$_->pathname);
				$body.='<a href="'.$href.'">'.$n->{get_utf8_name}->($_->filename).'</a><br>';
			}
			$body.='<hr>';
			foreach  ($io->all_files($deep)) {
				$body.='<span style="display:inline-block;width: 400px;">File: ';
				my $href=$r->{_uri}.'?file='.encodeURIComponent($location."/".$_->pathname);
				$body.='<a href="'.$href.'">'.$n->{get_utf8_name}->($_->filename).'</a></span>';
				$body.='<span style="display:inline-block;margin-left: 100px;">Size:'.io($_->pathname)->size.'</span><br>';
			}
			$n->{send_normal_resp}->($r,$key,'<h1>File List</h1>'.$body);

		}elsif(-e $dest){
			$n->{send_file}->($dest,$r,$key,1);
		}else{
			$n->{send_response_error}->($r,$key,'404',' Folder not exists');
		}
	}else{
		$n->{send_response_error}->($r,$key,'404',' Folder not exists');
	}
};

$n->{send_resp}=sub { ### 可以 设置 mime type
	my ($r,$key,$data,$type)=@_;
	my $res = "$r->{_protocol} 200 OK\015\012";
	my $hdr={};
	$r->{'_keepalive'} ? $hdr->{'Connection'} = 'keep-alive' : $hdr->{'Connection'} = 'close';
	if ($r->{'origin'}->[0]) {
		 $hdr->{'Access-Control-Allow-Origin'}=$r->{'origin'}->[0];
	}else{
		$hdr->{'Access-Control-Allow-Origin'} = '*';
	}
	$hdr->{'Connection'} = $r->{'connection'}->[0];
	$hdr->{'Date'} = AnyEvent::HTTP::format_date(time);
	$hdr->{'Expires'} = $hdr->{'Date'};
	$hdr->{'Cache-Control'} = "max-age=0";

	$type ? $hdr->{'Content-Type'} = $type : $hdr->{'Content-Type'} = 'text/html; charset=utf8';
	$hdr->{'Content-Length'} = length $data;

	while (my ($h, $v) = each %$hdr) {
	   $res .= "$h: $v\015\012";
	}
	$res .= "\015\012";
	$res .= $data;
	if (exists $self->{server}->{$key}) {
		$self->{server}->{$key}->push_write($res);
	}
	unless ($r->{'_keepalive'}) {
		$n->{on_disconnect}->($key);
	}
};

$n->{send_normal_resp}=sub {
	my ($r,$key,$body)=@_;
	my $content=$self->{default_server_config}->{html_head};
	$content.=$body;
	$content.=$self->{default_server_config}->{html_foot};

	my $res = "$r->{_protocol} 200 OK\015\012";
	my $hdr={};
	$r->{'_keepalive'} ? $hdr->{'Connection'} = 'keep-alive' : $hdr->{'Connection'} = 'close';
	if ($r->{'origin'}->[0]) {
		 $hdr->{'Access-Control-Allow-Origin'}=$r->{'origin'}->[0];
	}else{
		$hdr->{'Access-Control-Allow-Origin'} = '*';
	}
	$hdr->{'Date'} = AnyEvent::HTTP::format_date(time);
	$hdr->{'Expires'} = $hdr->{'Date'};
	$hdr->{'Cache-Control'} = "max-age=0";
	
	$hdr->{'Content-Type'} = 'text/html';
	$hdr->{'Content-Length'} = length $content;

	while (my ($h, $v) = each %$hdr) {
	   $res .= "$h: $v\015\012";
	}
	$res .= "\015\012";
	$res .= $content;
	if (exists $self->{server}->{$key}) {
		$self->{server}->{$key}->push_write($res);
	}
	unless ($r->{'_keepalive'}) {
		$n->{on_disconnect}->($key);
	}
};

$n->{send_response_error}=sub {
    my ($r, $key, $code, $content) = @_;		## only code must be input
    my $msg;
	my $hdr={};
	if ($code eq '404') {
		$msg='Not Found';
    }
	if ($code eq '304') {
		$msg='Not Modified';
	}
	if ($code eq '204') {
		$msg='No Content';
	}

	$hdr->{'Content-Type'} = 'text/html; charset=UTF-8';
	$r->{'_keepalive'} ? $hdr->{'Connection'} = 'keep-alive' : $hdr->{'Connection'} = 'close';
	if ($content) {
		$hdr->{'Content-Length'} = length $content;
	}

    my $res = "$r->{_protocol} $code $msg\015\012";
  
    while (my ($h, $v) = each %$hdr) {
       $res .= "$h: $v\015\012";
    }
    $res .= "\015\012";
    $res .= $content;
	if (exists $self->{server}->{$key}) {
		$self->{server}->{$key}->push_write($res);
	}
	unless ($r->{'_keepalive'}) {
		$n->{on_disconnect}->($key);
	}
};

$n->{get_utf8_name}=sub {
	my $get=shift;
	if ($w32encoding) {
		$get=encode_utf8(decode($w32encoding, $get));
	}
	return $get;
};
$n->{put_local_name}=sub {
	my $put=shift;
	if ($w32encoding) {
		$put=encode($w32encoding, decode_utf8($put));
	}
	return $put;
};
$n->{del_url}=sub {
	my $g=shift;
	if (exists $url_reg->{$g->{host}}->{$g->{url}}) {
		delete $url_reg->{$g->{host}}->{$g->{url}};
		return 1;
	}else{
		return 0;
	}
};
$n->{reg_url}=sub {
	my $g=shift;
	if (exists $url_reg->{$g->{host}}->{$g->{url}}) {
		$n->{logs}->("$g->{host} -> $g->{url} reg dup and overwrite\n");
	}
	if ($g->{type} eq 'file') {
		unless (-e $g->{go}) {
			$n->{logs}->("reg error: $g->{go} not exists");
			return 0;
		}
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}elsif($g->{type} eq 'file_down'){
		unless (-e $g->{go}) {
			$n->{logs}->("reg error: $g->{go} not exists");
			return 0;
		}
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}elsif($g->{type} eq 'file_index'){
		unless (-d $g->{go}) {
			$n->{logs}->("reg error: $g->{go} not exists");
			return 0;
		}
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}elsif($g->{type} eq 'file_root'){
		unless (-d $g->{go}) {
			$n->{logs}->("reg error: $g->{go} not exists");
			return 0;
		}
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},go=>$g->{go},type=>$g->{type}};
	}elsif($g->{type} eq 'http_get'){
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}elsif($g->{type} eq 'form_post'){
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}elsif($g->{type} eq 'ajax_post'){
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}elsif($g->{type} eq 'html5_file_post'){
		$url_reg->{$g->{host}}->{$g->{url}}={config=>$g->{config},type=>$g->{type},go=>$g->{go}};
	}
	else{
		$n->{logs}->("reg error:$g->{url} $g->{type}\n");
		return 0;
	}
	if (exists $g->{code}) {
		$url_reg->{$g->{host}}->{$g->{url}}->{code}=$g->{code};
	}
	return 1;
};

###############################################################################

$n->{on_disconnect}=sub {
    my ($key) = @_;
	if (exists $self->{server}->{$key}) {
		$self->{server}->{$key}->destroy();
		delete $self->{server}->{$key}; 
	}
};


# example:
#$n->{reg_url}->({url=>'/file',host=>'*:*',type=>'file',go=>'C:\workspace\pjscrape.rar'});
#$n->{reg_url}->({url=>'/test',host=>'*:*',type=>'file',go=>'test.html'});
#$n->{reg_url}->({url=>'/index',host=>'*:*',type=>'file_index',go=>'.'}); ### 索引一个目录，并显示，可以点击这个目录下的所有文件，可以下载。
#$n->{reg_url}->({url=>'/down',host=>'*:*',type=>'file_down',go=>'down.html'});
#$n->{reg_url}->({url=>'/cc/*',host=>'*:*',type=>'file_root',go=>'c:\'});
#$n->{reg_url}->({url=>'/*',host=>'*:*',type=>'file_root',go=>'.'});

### {action=>'code',code=>''}
### {action=>'reg_url',go=>''}
### {action=>'new_http_server',port=>'',host=>''}
### {action=>'new_https_server',port=>'',host=>'',cert_file=>}
$n->{op_sub}=sub {
	my ($r,$key,$data)=@_;	
	unless ($n->{http_sec}->($r,$key)) {
		return 0;
	}
	
	eval{$data=decode_json($data)};
	if ($@) {
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',reason=>"Post data error"});
		return 0;
	}
	unless ($data->{action} eq 'get_logs') { ### get_logs 记录不输出，防止不断查询记录的时候总是输出这个get_logs
		$n->{logs}->(Dumper $data);
	}
	
	if ($data->{action} eq 'code') {
		my $return;
		eval $data->{code};
		if ($@) {
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',action=>'code',result=>'error',reason=>"code error:$@"});	
		}else{
			unless ($n->{reg_startup}->($data)) {
				$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'code',reason=>"dup code"});
			}else{
				$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'code','return'=>$return});
			}
		}
	}elsif ($data->{action} eq 'reg_url') {
		if ($data->{type} eq 'file') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}elsif($data->{type} eq 'file_index') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}elsif($data->{type} eq 'file_down') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}elsif($data->{type} eq 'file_root') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}else{
			unless ($data->{go}) {
				$n->{send_resp}->($r,$key,encode_json {result=>'error',url=>'/op',reason=>'no go data',action=>'reg_url'});
				return 0;
			}
			my $code;
			my $ss='$code'."=sub{$data->{go}};";
			eval $ss;
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},code=>$data->{go},go=>$code});
		}
		unless ($n->{reg_startup}->($data)) {
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'reg_url',reason=>"dup code",reg_url=>$data->{url},host=>$data->{host},type=>$data->{type}});
		}else{
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'reg_url',reg_url=>$data->{url},host=>$data->{host},type=>$data->{type}});
		}
	}elsif ($data->{action} eq 'list_url') {
		my $ss;
		if (exists $url_reg->{$data->{host}}) {
			foreach  (keys %{$url_reg->{$data->{host}}} ) {
				if ($url_reg->{$data->{host}}->{$_}->{type}=~/^file/) {
					$ss->{$_}={type=>$url_reg->{$data->{host}}->{$_}->{type},go=>$url_reg->{$data->{host}}->{$_}->{go}};
				}else{
					$ss->{$_}={type=>$url_reg->{$data->{host}}->{$_}->{type},code=>$url_reg->{$data->{host}}->{$_}->{code}};
				}
			}
			$n->{send_resp}->($r,$key,encode_json {result=>'ok',url_list=>$ss,action=>'list_url'});
		}else{
			$n->{send_resp}->($r,$key,encode_json {result=>'error',reason=>'not post op_host',action=>'list_url'});
		}
	}elsif ($data->{action} eq 'del_url') {
		if ($n->{del_url}->({url=>$data->{url},host=>$data->{host}})) {
			$n->{send_resp}->($r,$key,encode_json {result=>'ok',url=>'/op',del_url=>$data->{url},action=>'del_url'});
		}else{
			$n->{send_resp}->($r,$key,encode_json {result=>'error',url=>'/op',reason=>'no found',action=>'del_url'});
		}
	}elsif ($data->{action} eq 'new_http_server') {
		$n->{reg_startup}->($data); ## 暂时不提示是否重复注册，因为下面有端口检测，如果端口已经被使用，靠下面的提示
		if (exists $self->{daemon}->{"$data->{host},$data->{port}"}) {
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'new_http_server',reason=>"$data->{host},$data->{port} has been used"});
		}else{
			if ($n->{new_http_server}->($data->{host},$data->{port},$data->{timeout},$data->{max_form_data})) {
				$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'new_http_server',port=>$data->{port}});
			}else{
				$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'new_http_server',port=>$data->{port},reason=>'socket has been occupyed'});
			}
			
		}
	}elsif ($data->{action} eq 'new_https_server') {
		$n->{reg_startup}->($data);
		if (exists $self->{daemon}->{"$data->{host},$data->{port}"}) {
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'new_https_server',reason=>"$data->{host},$data->{port} has been used"});
		}else{
			if ($n->{new_https_server}->($data->{host},$data->{port},$data->{cert_file},$data->{timeout},$data->{max_form_data})) {
				$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'new_https_server',port=>$data->{port}});
			}else{
				$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'new_https_server',port=>$data->{port},reason=>'socket has been occupyed'});
			}			
		}
	}elsif ($data->{action} eq 'list_server') {
		my $ss=[];
		foreach  (keys %{$self->{daemon}} ) {
			push @$ss, $_;
		}
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'list_server',servers=>$ss});
	}elsif ($data->{action} eq 'stop_server') {
		unless ($data->{host}) {
			$data->{host}=undef;
		}
		$self->{daemon}->{"$data->{host},$data->{port}"}=undef;
		delete $self->{daemon}->{"$data->{host},$data->{port}"};
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'stop_server',port=>$data->{port}});
	}elsif ($data->{action} eq 'clear_startup') {
		$self->{startup}=[];
		$n->{write_startup}->();
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'clear_startup'});
	}elsif ($data->{action} eq 'remote_code') {
		my $remote_url;
		unless ($data->{remote_url}=~/^http/) {
			$remote_url=$self->{default_server_config}->{default_remote_url}.$data->{remote_url};
		}else{
			$remote_url=$data->{remote_url};
		}
		http_get $remote_url,
			timeout=>20,
			sub {
			   my ($body, $hdr) = @_;
			   if ($hdr->{Status} =~ /^2/) {
					my $return;
					eval $body;
					if ($@) {
						$n->{logs}->("remote read error:\n $body");
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_code',reason=>$@});
						return 0;
					}
					unless ($n->{reg_startup}->($data)) {
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_code',reason=>"dup code"});
					}else{
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'remote_code','return'=>$return});
					}
			   } else {
				  $n->{logs}->("remote error, $hdr->{Status} $hdr->{Reason}\n");
				  $n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_code',reason=>"http error: $hdr->{Status} $hdr->{Reason}"});
			   }
			};		
	}elsif ($data->{action} eq 'remote_reg_url') { ### 远程仅提供代码。配置还是跟随data一起发送。
		my $remote_url;
		unless ($data->{remote_url}=~/^http/) {
			$remote_url=$self->{default_server_config}->{default_remote_url}.$data->{remote_url};
		}else{
			$remote_url=$data->{remote_url};
		}
		http_get $remote_url,
			timeout=>20,
			sub {
			   my ($body, $hdr) = @_;
			   if ($hdr->{Status} =~ /^2/) {
				    $data->{go}=$body;
					if ($data->{type} eq 'file') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}elsif($data->{type} eq 'file_down') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}elsif($data->{type} eq 'file_index') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}elsif($data->{type} eq 'file_root') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}else{
						my $code;
						my $ss='$code'."=sub{$data->{go}};";
						eval $ss;
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},code=>$data->{go},go=>$code});
					}
					
					unless ($n->{reg_startup}->($data)) {
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_reg_url',reason=>"dup code"});
					}else{
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'remote_reg_url'});
					}
			   } else {
				  $n->{logs}->("remote error, $hdr->{Status} $hdr->{Reason}\n");
				  $n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_reg_url',reason=>"http error: $hdr->{Status} $hdr->{Reason}"});
			   }
			};		
	}elsif ($data->{action} eq 'script') {
		AnyEvent::Fork->new_exec->eval($data->{script},$$); ### $$传递的当前进程的id号
		unless ($n->{reg_startup}->($data)) {
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'script',reason=>"dup code"});
		}else{
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'script'});
		}
	}elsif ($data->{action} eq 'remote_script') {
		my $remote_url;
		unless ($data->{remote_url}=~/^http/) {
			$remote_url=$self->{default_server_config}->{default_remote_url}.$data->{remote_url};
		}else{
			$remote_url=$data->{remote_url};
		}
		http_get $remote_url,
			timeout=>20,
			sub {
			   my ($body, $hdr) = @_;
			   if ($hdr->{Status} =~ /^2/) {
				    $data->{script}=$body;
					AnyEvent::Fork->new_exec->eval($data->{script},$$);
					unless ($n->{reg_startup}->($data)) {
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_script',reason=>"dup code"});
					}else{
						$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'remote_script'});
					}
					
			   } else {
				  $n->{logs}->("remote error, $hdr->{Status} $hdr->{Reason}\n");
				  $n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'remote_script',reason=>"http error: $hdr->{Status} $hdr->{Reason}"});
			   }
			};		
	}elsif ($data->{action} eq 'clear_all') {
		$g={}; ## 外部程序的function
		$config={}; ## 配置文件
		$timer={}; ## 外部计时器
		$url_reg={}; ### url 注册列表
		$self->{server}={};  ### 连接的客户端 全部断开
		$self->{middle_client} ={}; ## 主动连接的 客户端全部停止
		$self->{daemon}={};  ### 启动的服务器全部停止
		$n->{reg_url}->({url=>'/op',host=>'*:'.$self->{manager_port},type=>'ajax_post',go=>$n->{op_sub} });
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'clear_all'});
	}elsif ($data->{action} eq 'start_worker') { ### autorun =0的时候，启动进程不运行starup脚本
		AnyEvent::Fork->new_exec->eval($self->{default_server_config}->{start_worker_script},$self->{default_server_config}->{execute_name},$self->{default_server_config}->{script_name}, $data->{port}, $data->{autorun});
		unless ($n->{reg_startup}->($data)) {
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',action=>'start_worker',reason=>"dup code"});
		}else{
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'start_worker'});
		}
	}elsif ($data->{action} eq 'stop') {
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'stop'});
		$timer->{stop}= AnyEvent->timer (
		   interval => 0.1,
		   cb    => sub { 
				unless (exists $self->{server}->{$key}) { ### 等待请求的客户端退出后，再退出整个进程
					$cvar->send 
				}
			},
		);
 
	}elsif ($data->{action} eq 'get_logs') {
		my $last_id=$self->{log_count};
		if ($data->{id}) {
			my $ll={};
			foreach  (sort {$b<=>$a} keys %{$self->{logs}}) {
				if ($_>$data->{id}) {
					$ll->{$_}=$self->{logs}->{$_};
				}else{
					last;
				}
			}
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'get_logs',logs=>$ll,last_id=>$last_id});
		}else{
			$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'ok',action=>'get_logs',logs=>$self->{logs},last_id=>$last_id});
		}
		
	}
	else{
		$n->{send_resp}->($r,$key,encode_json {url=>'/op',result=>'error',reason=>"no action",action=>$data->{action}});
	}
};


$n->{reg_url}->({url=>'/op',host=>'*:'.$self->{manager_port},type=>'ajax_post',go=>$n->{op_sub} }); ### for ssl

#$n->{reg_url}->({url=>'/op',host=>'*:10009',type=>'ajax_post',go=>$n->{op_sub} }); ### for normal http http暂时默认不开放

$n->{start}=sub {
	#### 改变 $self->{default_server_config} 的方式：code模块，直接修改变量即可
	$self->{default_server_config}->{timeout}=30;
	$self->{default_server_config}->{default_remote_url}='http://'.'remote.opzx.org'.'/';
	$self->{default_server_config}->{max_form_data}=5000000;
	$self->{default_server_config}->{opener_flag}='opener';
$self->{default_server_config}->{html_head}=<<'HEAD';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<script type="text/javascript" src='js/jquery.min.js'></script>
<title></title>
</head> 
<body>
HEAD

$self->{default_server_config}->{html_foot}=<<'FOOT';
</body>
</html>
FOOT

$self->{default_server_config}->{start_worker_script}=<<'GO';
my $pid;
if ($pid = fork) {  exit 0; }
exec @_;
GO

	$self->{default_server_config}->{execute_name}=$^X;
	$self->{default_server_config}->{script_name}=$0;
	$self->{startup}=[];
	$n->{new_manager_server}->();
	$n->{read_startup}->();
	if ($self->{autorun_startup}) {
		$n->{run_startup}->(0);
	}
	
};

$n->{reg_startup}=sub {
	my $data=shift;
	if ($data->{reg_startup}>0) {
		my $cal;
		foreach  (sort keys %$data) {
			$cal.=$_.$data->{$_};
		}
		$data->{md5}=md5_hex($cal);
		foreach  (@{$self->{startup}}) {### 遍历所有的startup
			if ($_->{md5} eq $data->{md5}) {
				return 0;
			}
		}
		push @{$self->{startup}},$data;
		$n->{write_startup}->();
	}elsif ($data->{reg_startup}<0) {
		my $cal;
		$data->{reg_startup}=1; ### 修改更正一下，以找到相应的需要删除的选项。
		foreach  (sort keys %$data) {
			$cal.=$_.$data->{$_};
		}
		$data->{md5}=md5_hex($cal);
		my $i=0;
		foreach  (@{$self->{startup}}) {### 遍历所有的startup
			if ($_->{md5} eq $data->{md5}) {
				splice(@{$self->{startup}},$i,1);
				last;
			}
			$i++;
		}
		$n->{write_startup}->();
	}
	return 1;
};
$n->{read_startup}=sub {

	my $data;
	my $config_file='opener.conf';
	if (-e $config_file) {
		$data=io($config_file)->all;
	}else{
		'{}'>io($config_file);
		return 0;
	}

	my $get;
	eval{$get=decode_json($data)};
	if ($@) {
		$n->{logs}->("read local config error: \n $data when read_startup");
#		return 0;
	}
	if (exists $get->{$self->{manager_port}}) { ### 每个管理端口，代表一个单独的进程。
		if (exists $get->{$self->{manager_port}}->{startup}) { 
			$self->{startup}=$get->{$self->{manager_port}}->{startup};
		}
	}
	
	return 1;
};
$n->{write_startup}=sub {
	my $io = io('opener.conf')->lock;
	my $data=$io->all;
	
	my $store;
	eval{$store=decode_json($data)};
	if ($@) {
		$n->{logs}->("read local error: \n $data when write_startup");
		return 0;
	}
	$store->{$self->{manager_port}}->{startup}=$self->{startup};
	my $data2=encode_json($store);
	$data2 > $io;
	$io->unlock;
};

### remote 有两种形式：
### 1. 直接https连接模式，将https连接存储在本地。
### 2. 默认连接模式，提供一个字符串，将默认主域名与字符串连接，合成一个https连接。
### remote 运行是从一个地址取回数据后，直接运行。多个地址的取回没有先后，谁先取回谁先运行。

### 确保startup里面的程序，顺序执行。
### 重复的命令可能重复运行。必须在传入以前检查。
$n->{run_startup}=sub {
	my $i=shift;
	unless ($i<@{$self->{startup}}) {
		return 0;
	}
	my $data=$self->{startup}->[$i];
	$i++;
	if ($data->{action} eq 'code') {
		eval $data->{code};
		if ($@) {
			$n->{logs}->("$@ \n startup run code error: \n $data->{code}");
			return 0; ### 有错误，就直接退出，不再进一步执行 startup
		}
		$n->{run_startup}->($i);
	}elsif ($data->{action} eq 'reg_url') {
		if ($data->{type} eq 'file') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}elsif($data->{type} eq 'file_down') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}elsif($data->{type} eq 'file_index') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}elsif($data->{type} eq 'file_root') {
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
		}else{
			my $code;
			my $ss='$code'."=sub{$data->{go}};";
			eval $ss;
			$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},code=>$data->{go},go=>$code});
		}
		$n->{run_startup}->($i);
	}elsif ($data->{action} eq 'new_http_server') {
		unless (exists $self->{daemon}->{"$data->{host},$data->{port}"}) {
			unless ($n->{new_http_server}->($data->{host},$data->{port},$data->{timeout},$data->{max_form_data})) {
				$n->{logs}->("Socket:$data->{host},$data->{port} has been occupyed by other programme");
			}
		}
		$n->{run_startup}->($i);
	}elsif ($data->{action} eq 'new_https_server') {
		unless (exists $self->{daemon}->{"$data->{host},$data->{port}"}) {
			unless ($n->{new_https_server}->($data->{host},$data->{port},$data->{cert_file},$data->{timeout},$data->{max_form_data})) {
				$n->{logs}->("Socket:$data->{host},$data->{port} has been occupyed by other programme");
			}
		}
		$n->{run_startup}->($i);
	}elsif ($data->{action} eq 'remote_code') {
		my $remote_url;
		unless ($data->{remote_url}=~/^http/) {
			$remote_url=$self->{default_server_config}->{default_remote_url}.$data->{remote_url};
		}else{
			$remote_url=$data->{remote_url};
		}
		http_get $remote_url,
			timeout=>20,
			sub {
			   my ($body, $hdr) = @_;
			   if ($hdr->{Status} =~ /^2/) {
					eval $body;
					if ($@) {
						$n->{logs}->("remote read error:\n $body");
						return 0;
					}
					$n->{run_startup}->($i);
			   } else {
				  $n->{logs}->("remote error, $hdr->{Status} $hdr->{Reason}\n");
			   }
			};		
	}elsif ($data->{action} eq 'remote_reg_url') {
		my $remote_url;
		unless ($data->{remote_url}=~/^http/) {
			$remote_url=$self->{default_server_config}->{default_remote_url}.$data->{remote_url};
		}else{
			$remote_url=$data->{remote_url};
		}
		http_get $remote_url,
			timeout=>20,
			sub {
			   my ($body, $hdr) = @_;
			   if ($hdr->{Status} =~ /^2/) {
				    $data->{go}=$body;
				    if ($data->{type} eq 'file') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}elsif($data->{type} eq 'file_down') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}elsif($data->{type} eq 'file_index') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}elsif($data->{type} eq 'file_root') {
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},go=>$data->{go}});
					}else{
						my $code;
						my $ss='$code'."=sub{$data->{go}};";
						eval $ss;
						$n->{reg_url}->({config=>$data->{config},url=>$data->{url},host=>$data->{host},type=>$data->{type},code=>$data->{go},go=>$code});
					}
					$n->{run_startup}->($i);
			   } else {
				  $n->{logs}->("remote error, $hdr->{Status} $hdr->{Reason}\n");
			   }
			};		
	}elsif ($data->{action} eq 'script') {
		AnyEvent::Fork->new_exec->eval($data->{script},$$);
		$n->{run_startup}->($i);
	}elsif ($data->{action} eq 'remote_script') {
		my $remote_url;
		unless ($data->{remote_url}=~/^http/) {
			$remote_url=$self->{default_server_config}->{default_remote_url}.$data->{remote_url};
		}else{
			$remote_url=$data->{remote_url};
		}
		http_get $remote_url,
			timeout=>20,
			sub {
			   my ($body, $hdr) = @_;
			   if ($hdr->{Status} =~ /^2/) {
				   AnyEvent::Fork->new_exec->eval($body,$$);
				   $n->{run_startup}->($i);
			   } else {
				  $n->{logs}->("remote error, $hdr->{Status} $hdr->{Reason}\n");
			   }
			};		
	}elsif ($data->{action} eq 'start_worker') { ### 这里和上面的实现不一样，没有用autorun。每次自动启动新进程的时候，必须启动startup的内容。
		AnyEvent::Fork->new_exec->eval($self->{default_server_config}->{start_worker_script},$self->{default_server_config}->{execute_name},$self->{default_server_config}->{script_name}, $data->{port});
		$n->{run_startup}->($i);
	}
	else{
		$n->{logs}->("no action: $data->{action}");
		return 0;
	}

};

$n->{http_sec}=sub{
	my ($r,$key)=@_;
	my $flag;
	if ($config->{opener_flag}) {
		$flag=$config->{opener_flag};
	}else{
		$flag=$self->{default_server_config}->{opener_flag};
	}
	unless ($r->{opener_flag}->[0] eq $flag) {
		$n->{logs}->("$key sec error");
		$n->{on_disconnect}->($key);
		return 0;
	}
	return 1;
};

$n->{http_ajax_post}=sub{
	my ($data, $cb) = @_;
	unless ($cb) {
		$cb=sub{};
	}
	my $opener=$data->{opener};
	delete $data->{opener};
	my $bindip;
	if (exists $data->{bindip}) {
		$bindip=$data->{bindip};
		delete $data->{bindip};
	}

	unless ($data->{opener_flag}) {
		$data->{opener_flag}='opener';
	}
	my $json_code=encode_json $data;
	http_request
	  POST    => $opener,
	  headers => { "user-agent" => "OPener 1.0" ,"opener_flag"=>$data->{opener_flag}},
	  body=> $json_code,
	  tls_ctx=>{method =>'TLSv1'},
	  on_prepare=>sub{
		my ($fh) = shift;
		if ($bindip) {
			my $bind = AnyEvent::Socket::pack_sockaddr 0, AnyEvent::Socket::aton($bindip);
			bind $fh,$bind;
		}
		
		}, 
	  keepalive=>1,
	  persistent=>1,  #### 默认是重用连接
	  timeout => 30,
	  sub {
		 my ($body, $hdr) = @_;
		 if ($hdr->{Status} =~ /^2/) {
			$data->{retry}=0;
			$cb->(1,$body,$hdr);
		 }elsif ($hdr->{Status} =~ /^4/) {
			$cb->(0,$body,$hdr);
		 }else{
#			 $cb->(0,$body,$hdr);
			if ($hdr->{Status}==596) {
				 $data->{opener}=$opener;
				 unless (exists $data->{retry}) {
					$data->{retry}=0;
				 }
				 $data->{retry}+=1;
				 unless ($data->{retry}>3) {
					 $n->{http_ajax_post}->($data,$cb);
				 }else{
					$cb->(0,$body,$hdr);
				 }
			}
		 }
		 return 1;
	};

};

$n->{http_get}=sub{
	my ($data, $cb) = @_;
	unless ($cb) {
		$cb=sub{};
	}
	my $opener=$data->{opener};
	http_request
	  GET    => $opener,
	  headers => { "user-agent" => "OPener 1.0" ,opener_flag=>$data->{opener_flag}},
	  timeout => 30,
	  sub {
		 my ($body, $hdr) = @_;
		 if ($hdr->{Status} =~ /^2/) {
			$data->{retry}=0;
			$cb->(1,$body,$hdr);
		 }elsif ($hdr->{Status} =~ /^4/) {
			$cb->(0,$body,$hdr);
		 }else{
			if ($hdr->{Status}==596) {
				 $data->{opener}=$opener;
				 unless (exists $data->{retry}) {
					$data->{retry}=0;
				 }
				 $data->{retry}+=1;
				 unless ($data->{retry}>3) {
					 $n->{http_get}->($data,$cb);
				 }else{
					$cb->(0,$body,$hdr);
				 }
			}
		 }
		 return 1;
	};

};

$n->{http_download}=sub{
   my ($url, $file, $cb) = @_;
   unless ($cb) {
		$cb=sub{};
	}
   open my $fh, "+>", $file or $n->{logs}->("$file: $!");
 
   my %hdr;
   my $ofs = 0;
 
   if (stat $fh and -s _) {
      $ofs = -s _;
      $hdr{"if-unmodified-since"} = AnyEvent::HTTP::format_date +(stat _)[9];
      $hdr{"range"} = "bytes=$ofs-";
   }
 
   http_get $url,
      headers   => \%hdr,
	  timeout=>30,
      on_header => sub {
         my ($hdr) = @_;
 
         if ($hdr->{Status} == 200 && $ofs) {
            # resume failed
            truncate $fh, $ofs = 0;
         }
 
         sysseek $fh, $ofs, 0;
 
         1
      },
      on_body   => sub {
         my ($data, $hdr) = @_;
 
         if ($hdr->{Status} =~ /^2/) {
            length $data == syswrite $fh, $data
               or return; # abort on write errors
         }
 
         1
      },
      sub {
         my (undef, $hdr) = @_;
 
         my $status = $hdr->{Status};
 
         if (my $time = AnyEvent::HTTP::parse_date $hdr->{"last-modified"}) {
            utime $fh, $time, $time;
         }
 
         if ($status == 200 || $status == 206 || $status == 416) {
            # download ok || resume ok || file already fully downloaded
            $cb->(1, $hdr);
 
         } elsif ($status == 412) {
            # file has changed while resuming, delete and retry
            unlink $file;
            $cb->(0, $hdr);
 
         } elsif ($status == 500 or $status == 503 or $status =~ /^59/) {
            # retry later
            $cb->(0, $hdr);
 
         } else {
            $cb->(undef, $hdr);
         }
      }
   ;
};

$n->{logs}=sub {
	my $c=shift;
#	time.": $c\n" > io('opener.logs') if $self->{log_debug};
	warn "$c" if $self->{display_debug};
	$self->{log_count}++;
	$self->{logs}->{$self->{log_count}}={'c'=>$c,'t'=>time,'s'=>length $c};
	
	$self->{log_size}+=length $c;
	if ($self->{log_size}>$self->{log_max_size}) {
		foreach  (sort {$a<=>$b} keys %{$self->{logs}}) {
			$self->{log_size}-=$self->{logs}->{$_}->{s};
			delete $self->{logs}->{$_};
			if ($self->{log_size}<$self->{log_max_size}) {
				last;
			}
		}
	}
};


$n->{start}->();
$cvar->recv;
