#!/usr/bin/perl

package opener_manager;
use AnyEvent;
use AnyEvent::HTTP;
use JSON::XS;
use Data::Dumper;

use base Exporter::;

our @EXPORT = qw(new_url list_url del_url start_http_port start_https_port list_server stop_server new_code clear_startup remote_code remote_url new_script remote_script push_action run request_http wait_request_http clear_default_startup);

#our $reg_url;
our $opener_flag='alexe';
our $request_timeout=60; 
our $run={};
my $run_count=0;
my $cvar;
my $debug=0;

#$.ajax({
#	  url: "http://127.0.0.1/query_dns",
#	  cache: false,
#	  headers: {
##		  opener_flag:'test'
#	  },
#	  type: 'POST',
#	  dataType: 'json',
#	   data: JSON.stringify({'account':'130501y9k7',pass:'mm5xoe'}),
#	  success: function(data){
#		console.log(data);
#	  },
#	  error: function(){
#		console.log('error');
#		}
#	});


#stop_port('127.0.0.1',80);
#del_url('127.0.0.1:80','/test');
#list_url('127.0.0.1:80');
#start_http_port('127.0.0.1','80');

#new_url('127.0.0.1:80','/test','http_get',$self->{test});

#list_server();



#start_https_port('127.0.0.1','8080','http://127.0.0.1/ssl_pem_down?opener=111&file=1.pem');
######################### public function

sub new_code{
	my ($opener,$code,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'code',code=>$code,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'code',code=>$code,reg_startup=>$startup});
	}
	return 1;
}
sub new_url{
	my ($opener,$host,$url,$type,$go,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'reg_url',url=>$url,host=>$host,type=>$type,go=>$go,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'reg_url',url=>$url,host=>$host,type=>$type,go=>$go,reg_startup=>$startup});
	}
	return 1;
}

sub list_url{
	my ($opener,$host,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'list_url',host=>$host});
	}else{
		wait_request_http({opener=>$opener,action=>'list_url',host=>$host});
	}
	return 1;
}

sub del_url{
	my ($opener,$host,$url,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'del_url',url=>$url,host=>$host});
	}else{
		wait_request_http({opener=>$opener,action=>'del_url',url=>$url,host=>$host});
	}
	return 1;
}

sub start_http_port{
	my ($opener,$host,$port,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'new_http_server',port=>$port,ip=>$host,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'new_http_server',port=>$port,ip=>$host,reg_startup=>$startup});
	}
	return 1;
}
sub start_https_port{
	my ($opener,$host,$port,$cert_file,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'new_https_server',port=>$port,ip=>$host,cert_file=>$cert_file,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'new_https_server',port=>$port,ip=>$host,cert_file=>$cert_file,reg_startup=>$startup});
	}
	return 1;
}

sub list_server{
	my ($opener,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'list_server'});
	}else{
		wait_request_http({opener=>$opener,action=>'list_server'});
	}
	return 1;
}
sub stop_server{
	my ($opener,$host,$port,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'stop_server',port=>$port,host=>$host});
	}else{
		wait_request_http({opener=>$opener,action=>'stop_server',port=>$port,host=>$host});
	}
	return 1;	
}
sub start_server{
	my ($opener,$port,$autorun,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'start_worker',port=>$port,autorun=>$autorun});
	}else{
		wait_request_http({opener=>$opener,action=>'start_worker',port=>$port,autorun=>$autorun});
	}
	return 1;	
}

sub clear_startup{
	my ($opener,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'clear_startup'});
	}else{
		wait_request_http({opener=>$opener,action=>'clear_startup'});
	}
	return 1;
}

sub clear_default_startup{
	my ($opener,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'clear_default_startup'});
	}else{
		wait_request_http({opener=>$opener,action=>'clear_default_startup'});
	}
	return 1;
}


sub remote_code{
	my ($opener,$remote_url,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'remote_code',remote_url=>$remote_url,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'remote_code',remote_url=>$remote_url,reg_startup=>$startup});
	}
	return 1;
}

sub remote_url{
	my ($opener,$host,$url,$type,$remote_url,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'remote_reg_url',url=>$url,host=>$host,type=>$type,remote_url=>$remote_url,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'remote_reg_url',url=>$url,host=>$host,type=>$type,remote_url=>$remote_url,reg_startup=>$startup});
	}
	return 1;
}

sub new_script{
	my ($opener,$script,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'script',script=>$script,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'script',script=>$script,reg_startup=>$startup});
	}
	return 1;
}

sub remote_script{
	my ($opener,$remote_url,$startup,$ready)=@_;
	unless ($ready) {
		request_http({opener=>$opener,action=>'remote_script',remote_url=>$remote_url,reg_startup=>$startup});
	}else{
		wait_request_http({opener=>$opener,action=>'remote_script',remote_url=>$remote_url,reg_startup=>$startup});
	}
	return 1;
}


sub request_http{
	my $data= shift;
	my $opener=$data->{opener};
	delete $data->{opener};
	my $json_code=encode_json $data;
	$cvar->begin;
	http_request
	  POST    => $opener,
	  headers => { "user-agent" => "OPener 1.0" ,opener_flag=>$opener_flag},
	  body=> $json_code,
	  timeout => $request_timeout,
	  sub {
		 my ($body, $hdr) = @_;
		 if ($hdr->{Status} =~ /^2/) {
			$data->{retry}=0;
			eval{$body=decode_json($body)};
			if ($@) {
				return 0;
			}
			warn "$opener:\n", Dumper $body; warn "\n";
		 }else{
			warn "http error:$opener \n";
			if ($hdr->{Status}==596 || $hdr->{Status}==595 || $hdr->{Status}==597) {
				 $data->{opener}=$opener;
				 unless (exists $data->{retry}) {
					$data->{retry}=0;
				 }
				 $data->{retry}+=1;
				 unless ($data->{retry}>3) {
					 request_http($data);
				 }
			}
		 }
		$cvar->end;
		 return 1;
	};
}

sub wait_request_http{
	my $data= shift;
	my $opener=$data->{opener};
	delete $data->{opener};

	my $json_code=encode_json $data;
	my $cc= AnyEvent->condvar;
	$cc->begin;
	http_request
	  POST    => $opener,
	  headers => { "user-agent" => "OPener 1.0" ,opener_flag=>$opener_flag},
	  body=> $json_code,
	  timeout => $request_timeout,
	  sub {
		 my ($body, $hdr) = @_;
		 if ($hdr->{Status} =~ /^2/) {
			 $data->{retry}=0;
			eval{$body=decode_json($body)};
			if ($@) {
				return 0;
			}
			warn "$opener:\n", Dumper $body; warn "\n";
			$cc->end;
		 }else{
			warn "http wait error:$opener $json_code $hdr->{Status} \n";
			$cc->send($hdr->{Status});
		 }
	};
	my $c=$cc->recv;
	if ($c==596 || $c==595 || $c==597) {
		 $data->{opener}=$opener;
		 unless (exists $data->{retry}) {
			$data->{retry}=0;
		 }
		 $data->{retry}+=1;
		 unless ($data->{retry}>3) {
			 warn "retry:$data->{retry}";
			 wait_request_http($data);
		 }
	}
	return 1;
}

sub push_action{
	my $data=shift;
	push @{$run->{$data->{opener}}}, $data;
	return 1;
}
### push_action({opener=>$reg_url,action=>'code',code=>$self->{main_proxy},ready=>1});
### ready=1 
### run($reg_url); 
sub run{
	my $k=shift;
#	warn $run_count,"\n";
	if ($run_count ==0) {
		$cvar= AnyEvent->condvar;
		$cvar->begin;
	}
	unless ($run_count<@{$run->{$k}}) {
#		warn "recv $run_count\n";
		$cvar->end;
		$cvar->recv;
		$run_count =0;
		delete $run->{$k};
		return 0;
	}
	my $data=$run->{$k}->[$run_count];
	$run_count++;
	if ($data->{"ready"}) {
		wait_request_http($data);
	}else{
		request_http($data);
	}
	run($k);
}

1
