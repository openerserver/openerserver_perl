# opener_server.pl 的教程

## Hello world

用jquery：

```javascript

var start_http_server={'action':'new_http_server','ip':'','port':'1008'}; // 开启一个新的http服务器，监听在端口1008上
var reg_url={'action':'reg_url','type':'http_get','url':'/helloworld','host':'*:1008','go':hello_fun}; 
//注册一个url地址 /helloworld ，绑定到1008端口上，设定这个url处理模式为http get模式，最后处理这个url的代码放到 hello_fun

var hello_fun=`my ($r,$key)=@_; 
$n->{send_normal_resp}->($r,$key,'Hello Worlds'); 

`;
//### 接收传入参数，$r 包含所有这个http请求相关信息，$key包含该http请求的唯一id
//### 发送返回，返回内容是html，加入一个hello world字符串。

url_post_data(url,JSON.stringify(start_http_server)); 
url_post_data(url,JSON.stringify(reg_url));

var url="https://test1.openerserver.com:10008/op";  // 安装了opener_server的服务器地址：test1.openerserver.com 
var opener_flag='opener'; // 设定http header中opener_flag字段，相当于访问该opener_server的密码
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


## Http shell

同样是使用jquey, 你已经使用了上面那段代码生成了helloworld，下面你只要下面的代码就可以有一个http shell：
```javascript

var start_http_server2={'action':'new_http_server','ip':'','port':'1009'}; // 开启一个新的http服务器，监听在端口1009上
var reg_url={'action':'reg_url','type':'ajax_post','url':'/shell','host':'*:1009','go':shell}; 
//注册一个url地址 /shell ，绑定到1008端口上，设定这个url处理模式为ajax post模式，最后处理这个url的代码放到 shell

var shell=`my ($r,$key,$data)=@_; 
my $rr=`$data`;
$n->{send_resp}->($r,$key,{type=>'/shell',result=>'ok',g=>$rr});
`;

url_post_data(url,JSON.stringify(start_http_server2)); 
url_post_data(url,JSON.stringify(reg_url));

```

Shell代码只有三行:
``` perl
my ($r,$key,$data)=@_;  ### 接收参数
my $rr=`$data`;         ### 执行，并取得结果
$n->{send_resp}->($r,$key,{type=>'/shell',result=>'ok',g=>$rr});  ### 通过http 返回结果
```

测试执行效果：
```javascript
var url2="http://test1.openerserver.com:1009/shell"; 
url_post_data(url2,'ls');
```

## 添加一个http api，做md5运算

继续jquey：
```javascript

var reg_url={'action':'reg_url','type':'ajax_post','url':'/md5','host':'*:1009','go':md5_run}; 
//注册一个url地址 /shell ，绑定到1008端口上，设定这个url处理模式为ajax post模式，最后处理这个url的代码放到 shell

var md5_run=`my ($r,$key,$data)=@_; 
my $rr=md5_hex($data);
$n->{send_resp}->($r,$key,{type=>'/md5',result=>'ok',g=>$rr});
`;

url_post_data(url,JSON.stringify(reg_url));

```

测试执行效果：
```javascript
url_post_data("http://test1.openerserver.com:1009/md5",'test string');
```
