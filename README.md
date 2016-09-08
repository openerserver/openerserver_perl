# opener_server.pl opener_server 标准的Perl实现。

### API描述
```perl
1. 首先你必须有一个http server 的实现。这个http server 的实现可以提供http api以管理自己。
2. 管理自己的模式为ajax模式post json字符串到url地址的/op下。
json字符串为：{action:'',reg_startup:""}
### reg_startup为真的话，当前动作插入到启动菜单中。如果进程的autorun为真，则进程启动的时候，自动运行这些reg_startup为真的动作。
### reg_startup的动作先执行，最后容器运行的时候先执行。

{action:'code',code:''} ### 在当前进程容器中，插入代码。code内代码以utf8的编码格式，插入运行。

### host："ip地址:端口号"。如果需要匹配全部则用*代替。
### url："/aa/11/22"。如果需要匹配全部则用*代替。
{action:'reg_url',url:"",host:'*:*',type:'file',go:""}       ### 指定host上的url为单个文件的浏览，文件地址在go内
{action:'reg_url',url:"",host:'*:*',type:'file_index',go:""} ### 指定host上的url为文件目录的浏览，目录地址在go内
{action:'reg_url',url:"",host:'*:*',type:'file_down',go:""}  ### 指定host上的url为单个文件的下载，文件地址在go内
{action:'reg_url',url:"*",host:'*:*',type:'file_root',go:""} ### 指定host上的http server 根目录的设定，目录地址在go内
{action:'reg_url',url:"",host:'*:*',type:'http_get',go:""}   ### 指定host上的url为http get方式的请求，这个请求的处理的代码位于go内。常用于get一个虚拟地址，使用go处理好数据并返回。
{action:'reg_url',url:"",host:'*:*',type:'form_post',go:""}  ### 指定host上的url为form的post方式的请求，这个请求的处理的代码位于go内。
{action:'reg_url',url:"",host:'*:*',type:'ajax_post',go:""}  ### 指定host上的url为ajax的post方式的请求（也可以说是Http 的post模式），这个请求的处理的代码位于go内。
{action:'reg_url',url:"",host:'*:*',type:'html5_file_post',go:""} ### 指定host上的url为html5的文件 post上方式的请求。使用ajax post模式上传大的文件。上传成功后调用go
{action:'remote_reg_url',remote_url:"",url:"",host:'*:*',type:'',go:""} ### 从远程url地址中取回需要reg的go内容，然后执行reg_url操作

{action:'new_http_server',port:'',host:''} ###在端口 port ，ip地址 host上按照http server的模式监听。
{action:'new_https_server',port:'',host:'',cert_file:''} ###在端口 port ，ip地址 host上按照https server的模式监听，并配置一个证书：cert_file，证书文件和当前进程在同一个地址。
{action:'list_url',host:""} ###列出当前进程的该host下所有注册url地址，
{action:'del_url',url:"",host:""} ### 删掉一个host下的注册url
{action:'list_server'} ### 列出当前进程内的所有 服务列表。
{action:'stop_server',host:"",port:""} ### 停止一个 ip地址是host,端口是port的 服务。
{action:'clear_startup'} ### 清除当前进程的启动代码
{action:'remote_code',remote_url:""} ### 在当前进程容器中插入一个远程代码，代码位于：remote_url。

{action:'script',script:""} ### 启动一个新的进程，执行script内容。
{action:'remote_script',remote_url:""} ### 从remote_url中取回script内容，然后启动一个新的进程
{action:'clear_all'} ### 清除该进程内所有后添加部分，恢复到一个干净的http server 容器。
{action:'start_worker',port:"",autorun:""} ### 开启一个新的进程容器，指定这个容器的管理端口是port, autorun来决定这个新的进程容器是否随最初的管理进程容器一同启动。
{action:'stop'} ## 退出当前进程，主要用于退出当前应用程序的进程

3. 默认的管理端口上的http server均为https模式。
4. 管理的时候，需要在http header中添加一个 opener_flag 字段，字段内容用来鉴定该请求是否为认证的请求。
5. 发送管理请求后的返回结果：
{url:'/op',result:'error',action:"",reason:""} ### 操作错误返回
{url:'/op',result:'ok',action:""}    ### 操作正确返回
6. {action:'new_http_server',port:'',host:'',reg_startup:'1'}客户端发送管理请求并带reg_startup>0时，需要容器检测一下本次请求是否与之前的reg_startup请求有重复。重复则放弃本次reg_startup注册。如果reg_startup为-1，则从服务器删掉这条注册。

7. 客户端发送请求到容器时，需要满足两种形式：
. 请求正常情况必须是并发请求。
. 当需要的时候，可以阻塞，等待前一个执行的结果返回后，再继续执行。
8. 可以任意启动一个http 或者https服务器
9. 当注入的启动代码重复的时候，返回错误，并不予以注入。
```

### 文件列表：
* Opener_Server.pl 是Opener_Server 容器标准的Perl实现。

* Opener.pem 是opener_server.pl https管理端口需要的证书文件。

* util\perl_setup.sh 是 perl 运行环境设置工具。在运行Opener_server.pl之前，必须运行。

* util\create_pem.sh 是生成pem文件的脚步。 在运行Opener_server.pl 之前，需要运行一下：bash create_pem.sh opener 
在根目录下生成一个opener.pem


