# opener_server.pl 的教程

## Hello world

用jquery：

```javascript

var url="https://test1.openerserver.com:10008/op";  // 安装了opener_server的服务器地址：test1.openerserver.com 
var start_http_server="{'action':'new_http_server','ip':'','port':'1008'}"; // 开启一个新的http服务器，监听在端口1008上
var reg_url="{'action':'reg_url','type':'http_get','url':'/helloworld','host':'*:1008','go':"+hello_fun+"}"; 
//注册一个url地址 /helloworld ，绑定到1008端口上，设定这个url处理模式为http get模式，最后处理这个url的代码放到 hello_fun

var hello_fun=`
  my ($r,$key)=@_; ### 接收传入参数，$r 包含所有这个http请求相关信息，$key包含该http请求的唯一id
  $n->{send_normal_resp}->($r,$key,'Hello World'); ### 发送返回，返回内容是html，加入一个hello world字符串。

`;
var opener_flag='opener'; // 设定http header中opener_flag字段，相当于访问该opener_server的密码
url_post_data(url,JSON.stringify(start_http_server)); 
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
```

在一个含有jquery代码的html页面上，执行上面的代码就可以了。  
然后访问 http://test1.openervpn.com:1008/helloworld 就可以看到结果。  
