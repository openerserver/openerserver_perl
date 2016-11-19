# opener_server.pl 是OPener_Server 容器标准的Perl实现

opener_server.pl 默认启动就是一个https服务器，使用opener.pem证书文件,监听在默认端口10008上。  

该https服务器提供了一些基本的api，让你可以做到以下事情：

* 指定一个端口，启动一个新的http或者https服务器
* 停止在某个端口上运行的http或者https服务器
* 
* 建立一个文件浏览的url地址，并把它挂到某个端口与域名上
* 建立一个目录浏览的url地址，并把它挂到某个端口与域名上
* 建立一个单文件下载的url地址，并把它挂到某个端口与域名上
* 建立一个根目录(让所有找不到的文件，最后去这个根目录查找)，并把它挂到某个端口与域名上
* 建立一个HTTP GET模式的url，然后绑定一段代码来处理这个GET请求（这段代码可以位于本地、也可以位于远程http服务器），并把它挂到某个端口与域名上
* 建立一个上传的url地址，用来处理html5模式下的文件上传，然后绑定一段代码来处理这个POST请求（这段代码可以位于本地、也可以位于远程http服务器），并把它挂到某个端口与域名上
* 建立一个HTTP POST模式的url，用来处理ajax post上来的数据，然后绑定一段代码来处理这个POST请求（这段代码可以位于本地、也可以位于远程http服务器），并把它挂到某个端口与域名上
* 建立一个HTTP POST模式的url，用来处理form post上来的数据，然后绑定一段代码来处理这个POST请求（这段代码可以位于本地、也可以位于远程http服务器），并把它挂到某个端口与域名上
* 
* 注入一段代码，直接在opener_server的perl环境里运行
* 从远端的http服务器上取回一段代码，，直接在opener_server的perl环境里运行
* 启动一个新perl进程，直接执行一段脚本内容。
* 启动一个新perl进程，直接执行一段远端http服务器上的脚本内容。
* 
* 指定一个管理端口，启动一个新的opener_server.pl进程。
* 退出当前的opener_server.pl进程
* 取回当前系统内部的日志

### * 运行方法与运行参数

1. 第一次开始运行前，请先使用util/create_pem.sh脚本随机生成一个opener.pem证书文件。  
   运行方式：bash create_pem.sh opener  
   opener.pem证书文件也可以自己申请：内容是先私有证书，再公共颁发的证书，再中间证书（如果有的话），再CA的根证书。  
   生成opener.pem后，就可以直接用perl来运行opener_server.pl  

2. perl opener_server.pl 10008 0  
   第一个参数：10008(默认值)代表：opener_server.pl 的管理端口为10008，启动一个Https服务在10008端口并使用默认的opener.pem证书文件。  
   第二个参数：0 代表：不自动运行配置文件中的代码；1（默认值）：代表自动运行配置文件中的代码。  

### * 运行所需要perl模块

  以下为必须额外安装的库文件
  JSON::XS (提供json解析、封装功能)  
  AnyEvent (必须安装, 提供异步非阻塞模式)  
  EV  (必须安装, 提供异步非阻塞模式)  
  HTTP::Parser2::XS (必须安装, 提供http头解析功能)  
  URI::Escape::XS (必须安装, 提供url解析及封装)  
  IO::All (必须安装, 提供文件操作功能)  
  AnyEvent::Fork  (必须安装, 提供生成新进程功能)  
  LWP::MediaTypes (必须安装, 提供http文档类型解析功能)  
  AnyEvent::HTTP (必须安装, 提供http客户端功能)  
  Net::SSLeay (必须安装, 提供ssl\tls加密解密功能)  

  以下为 需要 安装的库文件（在其他的程序中可能使用到）
  Digest::SHA1  
  DBD::SQLite   
  Storable::AMF  
  Geo::IP::PurePerl  
  IP::QQWry  
  DateTime  
  String::Random   
  Email::Valid  
  Net::DNS  
  IO::Pty  
  Net::DNS::ToolKit  
  App::cpanminus  
  Net::Frame::Layer::DNS  
  Simple::IPInfo  
  Crypt::Passwd::XS  
  Net::Ifconfig::Wrapper  
  Net::IPAddress::Util  
  Net::Ping  


###  * 管理API描述（OPener_Server容器标准）

##### 基本实例
默认管理接口为https下的10008端口，通过用ajax POST一个json字符串到该url地址:/op下来管理。  
例如jquery方式：
```perl
$.ajax({
		  url: https://192.168.3.133:10008/op,
		  cache: false,
		  headers: {
			  opener_flag:"opener"
		  },
		  data: {"action":"","reg_startup":""},
		  type: 'POST',
		  dataType: 'json',
		  success: function(data){
			if (data.result=='ok')
			{	
				success(data);			
			}else{
				console.log('error');
			}
		  },
		  error: function(dd,mm){
			console.log('error:'+dd+mm);
			}
	});

```
发送管理请求的json字符串基本格式为：{action:"",reg_startup:""}  

* 发送管理请求后的返回结果：  
{url:'/op',result:'error',action:"",reason:""} ### 操作错误，reason代表错误原因。  
{url:'/op',result:'ok',action:""}    ### 操作正确  

* action字段代表：不同的请求。  
* reg_startup字段代表：是否将该action注册到启动列表中。  
  为 1 的话，当前action插入到启动列表中。先插入先执行  
  为-1 的话，则从服务器端删掉这条注册的action  
  为 0 的话（默认值），不注册这个action。  
  reg_startup请求有重复，重复则放弃本次reg_startup注册。  
  当注入的启动代码重复的时候，返回错误，并不予以注入。  

json字符串中特殊格式为：{action:"",reg_startup:"",ready:""}  
* ready字段为真时代表：当前请求完成后，再执行下面的action请求; 默认为假，所有的action请求，可以同步发送到服务器端。  
  因为很多时候，action的请求需要有先后顺序，例如你注入一段代码以后，才可能执行这段代码中的sub，所以必须等待前面的action完成  
* ready字段不属于OPener_Server标准协议，所以不发送到opener_server。只是一个在客户端发起的时候告诉客户端如何处理这些action的一个字段。  

##### 安全问题
在ajax_post的时候，必须加入一个http header：opener_flag，用来鉴定此次请求是否安全。  
opener_server.pl 的默认 opener_flag是opener  


##### API列表：
```perl

### 下面部分为 http服务器管理的api
{action:'new_http_server',port:"",ip:""} ###在端口为port、地址为ip上启动一个http server。
{action:'new_https_server',port:"",ip:"",cert_file:""} ###在端口为port 、地址为ip上启动一个https server，并配置一个证书：cert_file，证书文件和当前opener_server.pl进程在同一个目录下。
{action:'stop_server',ip:"",port:""} ### 停止一个 ip地址是ip,端口是port的 服务。

### 下面部分为生成新的http api的api
### host："地址:端口号"。例如：host:"www.aa.com:443"。如果需要匹配全部则用*代替，例如： host:"*.80", 匹配所有的到80端口的请求。
### url："/aa/11/22"。如果需要匹配全部则用*代替，例如：url:"/aa/*"
{action:'reg_url',url:"",host:'*:*',type:'file',go:""}       ### 指定host上的url为单个文件的浏览，文件地址在go内
{action:'reg_url',url:"",host:'*:*',type:'file_index',go:""} ### 指定host上的url为文件目录的浏览，目录地址在go内
{action:'reg_url',url:"",host:'*:*',type:'file_down',go:""}  ### 指定host上的url为单个文件的下载，文件地址在go内
{action:'reg_url',url:"*",host:'*:*',type:'file_root',go:""} ### 指定host上的根目录的设定，目录地址在go内
{action:'reg_url',url:"",host:'*:*',type:'http_get',go:""}   ### 指定host上的url为http get方式的请求，这个请求的处理的代码位于go内。常用于get一个虚拟地址，使用go处理好数据并返回。
{action:'reg_url',url:"",host:'*:*',type:'form_post',go:""}  ### 指定host上的url为form的post方式的请求，这个请求的处理的代码位于go内。
{action:'reg_url',url:"",host:'*:*',type:'ajax_post',go:""}  ### 指定host上的url为ajax的post方式的请求（也可以说是Http 的post模式），这个请求的处理的代码位于go内。
{action:'reg_url',url:"",host:'*:*',type:'html5_file_post',go:""} ### 指定host上的url为html5的文件 post上方式的请求。使用ajax post模式上传大的文件。上传成功后调用go
{action:'remote_reg_url',remote_url:"",url:"",host:'*:*',type:"",go:""} ### 从远程url地址中取回需要reg的go内容，然后执行reg_url操作

### 下面部分为 容器管理的api
{action:'list_url',host:""} ###列出当前进程的该host下所有注册url地址，
{action:'del_url',url:"",host:""} ### 删掉一个host下的注册url
{action:'list_server'} ### 列出当前进程内的所有 服务列表。

{action:'clear_startup'} ### 清除当前进程的所有启动代码
{action:'start_worker',port:"",autorun:""} ### 开启一个新的opener_server.pl进程容器，指定这个容器的管理端口是port, autorun来决定这个新的进程容器是否执行已经注册的启动代码。为0的话，不执行注册的启动代码，那么新的容器将是一个干净的容器。 为 1 的话则执行。
{action:'stop'}  ### 退出当前进程，主要用于退出当前应用程序的进程
{action:'clear_all'} ### 清除该进程内所有后添加部分，恢复到一个干净的http server 容器。这个模式未必能清除所有后添加部分，不推荐使用。

### 下面部分为 注入代码的api
{action:'code',code:""} ### 在当前进程容器中，注入code代码。code内的代码以utf8的编码格式，注入运行。
{action:'remote_code',remote_url:""} ### 在当前进程容器中插入一个远程代码，代码位于：remote_url的http服务器上。
{action:'script',script:""} ### 启动一个新的进程，执行script内容，script内容为utf8的编码格式。
{action:'remote_script',remote_url:""} ### 从remote_url中取回script内容，然后启动一个新的进程去执行。

### 下面部分为 取回系统日志的api
{action:'get_logs',id:""}  ### 取回当前系统的内部日志，id用来指定从该id以后的取回。

```

### * 如何注入代码（未完成）
#### 以下皆为opener_server.pl 具体实现，不属于OPener_Server的标准

###### reg_url部分

reg_url的go字段中，注入的代码。
基本实例：
```perl
	my ($r,$key,$data)=@_; ### 接收参数
	unless ($n->{http_sec}->($r,$key)) {
		return 0;
	}
	eval{$data=decode_json($data)};
	if ($@) {
		$n->{send_resp}->($r,$key, {type=>'/test',result=>'error',reason=>"Post data error"});
		return 0;
	}
	$n->{send_resp}->($r,$key,encode_json {action=>'test',result=>'ok'});

```

###### code部分
基本实例：
```perl
$config->{opener_flag}='opener';

```



### * 文件列表：
* opener_server.pl 是OPener_Server 容器标准的Perl实现。

* opener.pem 是opener_server.pl的https管理端口需要的证书文件。

* util\perl_setup.sh 是 perl 运行环境安装脚本。在运行opener_server.pl之前，必须运行。

* util\create_pem.sh 是生成pem证书文件的脚本。 方法：bash create_pem.sh opener 在根目录下生成一个opener.pem

* opener.conf 中心配置文件。储存所有的启动代码，包括各个管理端口的。文件内容为JSON结构。opener_server.pl第一次启动会自动生成该文件。  
  例如：
  
```json  
{"10101":{"startup":[{"port":"443","reg_startup":"1","cert_file":"http://aaaa.opzx.org/ssl_pem_down?opener=1&file=test.pem","host":"","action":"new_https_server","md5":"19f3767346c32d32f1e7f49ac5de79cb"}]},"10008":{"startup":[]}}
### {https port->{startup->[{action=>'',md5=>''},{action=>'',md5=>''}]}} 
### 其中md5是opener_server.pl自动生成的，为了防止有重复的action插入（理论上，不需要重复的action插入）
```


### * 性能情况
在干净的opener_server.pl情况下，其基本http性能和node.js的http服务器性能相当。


### *下载：
1. Open Source：https://github.com/openerserver/openerserver_perl/archive/master.zip
2. virtualbox image：
3. 树莓派的image:



