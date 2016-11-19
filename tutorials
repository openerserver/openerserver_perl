# opener_server.pl 的教程

## Hello world

用jquery：

··· javascript

var url="https://test1.openerserver.com:10008/op";
var start_http_server="{'action':'new_http_server','ip':'','port':'1008'}";
var reg_url="{'action':'reg_url','type':'http_get','url':'/helloworld','host':'*:1008','go':helloworld}";
var helloworld=`
  my ($r,$key)=@_;
  $n->{send_normal_resp}->($r,$key,'Hello World');

`;
url_post_data(url,JSON.stringify(start_http_server));url_post_data(url,JSON.stringify(start_http_server));
url_post_data(url,JSON.stringify(reg_url));
function url_post_data(go,data){
	$.ajax({
		  url: go,
		  cache: false,
		  headers: {
			  opener_flag:opener_flag
		  },
		  data: data,
		  type: 'POST',
		  dataType: 'json',
		  success: function(data){
			if (data.result=='ok')
			{	
        console.log(data);		
			}else{
				console.log('error');
			}
		  },
		  error: function(dd,mm){
			console.log('error:');
			console.log(dd);
			console.log(mm);
			}
	});
}
···


## opener_server.pl 的特点：

opener_server.pl 最初是面向提供http api开发的程序，最终opener_server.pl也继承了这些能力。  
* 首先，建议opener_server.pl运行在云服务器上。一旦opener_server.pl开始运行，就相当于你对该云服务器有了一个http外壳。  
  你可以通过http 来操纵使用这个服务器，做任何事情（如果使用root权限运行）。
* opener_server.pl 带来的是http 协议的更全面的覆盖。与opener_server.pl 交互的只有http协议。  
  现在还不支持http2协议，对http2协议，还在继续观察。
* 
