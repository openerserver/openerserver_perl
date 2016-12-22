# NAME

opener_server.pl - Http Container for run any code with http server.
 
## VERSION
 
Version 1.0

## SYNOPSIS
 
 
    perl opener_server.pl 10008 0
    start a https server which listen on 10008 with built-in api.
    '0' means not autorun code in opener.conf.
  
## DESCRIPTION


    opener_server.pl is a http container. It's the implement of OPener_Server protocol.
    It aims to quick run code with http server. 
	opener_server.pl is very simple programme. It only have one file and all code are in it.
	It's easy to read and to be changed. You can change all by yourself.
    You can injection any code to a http server to get any function you want.
    You can connect programme lannguange with http.
 

## Manange API

### http service manage

	{action:'new_http_server',port:"",ip:""}

start http server which listen on 'port' and 'ip'.
	
	{action:'new_https_server',port:"",ip:"",cert_file:""} 

start https server which listen on 'port' and 'ip' with certificate file is 'cert_file'. Certificate file is same dir with opener_server.pl.

	{action:'stop_server',ip:"",port:""} 

stop http or https server which listen on 'port' and 'ip'.

### register url to get new http api

Host Example: host:"127.0.0.1:80" or host: "www.aa.com:443". If you need match all, use "*". Example: host:"*.80" to match all request on 80 port.
Url Example: url:"/aa/11/22". If you need match all, use "*". Example: url:"/aa/*". 

	{action:'reg_url',url:"",host:'*:*',type:'file',go:""}

reg a "url" with "host", the url point to a file where location is "go". 

	{action:'reg_url',url:"",host:'*:*',type:'file_index',go:""} 

reg a "url" with "host", the url point to a dir where location is "go".  The url display all files in the "go".

	{action:'reg_url',url:"",host:'*:*',type:'file_down',go:""}  

reg a "url" with "host", the url point to a file where location is "go". When you goto the url, browser will download the file.

	{action:'reg_url',url:"*",host:'*:*',type:'file_root',go:""} 

reg a "url" with "host", the url point to a dir where location is "go". When opener_server.pl can't find you requset file, it will find it in the root dir at last.

	{action:'reg_url',url:"",host:'*:*',type:'http_get',go:""}   

reg a "url" with "host", the url point to a function which code is in "go". The request url type is GET.

	{action:'reg_url',url:"",host:'*:*',type:'form_post',go:""}  

reg a "url" with "host", the url point to a function which code is in "go". The request url type is POST, it's specail for form post action.

	{action:'reg_url',url:"",host:'*:*',type:'ajax_post',go:""}  

reg a "url" with "host", the url point to a function which code is in "go". The request url type is POST, it's specail for ajax post action.

	{action:'reg_url',url:"",host:'*:*',type:'html5_file_post',go:""} 

reg a "url" with "host", the url point to a function which code is in "go". The request url type is POST, it's specail for html5 file upload action.

	{action:'remote_reg_url',remote_url:"",url:"",host:'*:*',type:""} 

reg a "url" with "host", the url point to a function which code is in "remote_url".


### container service manage

	{action:'list_url',host:""}

list all registered urls with "host".

	{action:'del_url',url:"",host:""} 

delete a registered "url" with "host".

	{action:'list_server'} 

list all start http or https service.

	{action:'start_worker',port:"",autorun:"1"} 
	
start a new process with opener_server.pl. It's a clone process of opener_server.pl with manager "port". If "autorun" is true, new opener_server.pl process will run the injection startup code. 

	{action:'stop'} 

quit the current opener_server.pl process.

	{action:'clear_all'} 

clear all injection code and registered url to get a clean opener_server.pl process(not recommend).


### code injection 

	{action:'code',code:""}

inject "code" to current opener_server.pl container. "code" should be utf8 encoding.

	{action:'remote_code',remote_url:""} 

inject code to current opener_server.pl container. The code content is on a http location of "remote_url" 

	{action:'script',script:""} 

start a new perl process to run "script". "script" should be utf8 encoding.

	{action:'remote_script',remote_url:""} 

start a new perl process to run "script". The script content is on a http location of "remote_url" 


### Get opener_server.pl log

	{action:'get_logs',id:""}

Get the logs in opener_server.pl. "id" come from 0 and means get logs which more than "id".   


### reg or clear startup

	{action:'',reg_startup:"1"}

If reg_startup is true, this action will reg autorun with current manager port of opener_server.pl.

	{action:'clear_startup'} 

clear all startup code of current opener_server.pl process


### reg or clear default startup 

	{action:'',reg_default_startup:"1"}

If reg_default_startup is true, this action will reg autorun with all manager port of opener_server.pl as default run.

	{action:'clear_default_startup'} 

clear all default_startup code of all opener_server.pl process


## AUTHOR

    Larry Wang "<a at openerserver.com>"

## License

    The Apache License
    Version 2.0, January 2004
    http://www.apache.org/licenses/

## WebSite

    https://www.openerserver.com

