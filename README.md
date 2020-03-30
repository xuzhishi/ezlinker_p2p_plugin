# ezlinker_p2p_plugin:MQTT客户端点对点通信插件
## 1.简介
MQTT标准协议规定：如果两个客户端之间要通信，必须订阅相同的topic。但是这种做法不适合单个客户端之间的直接通信。为了解决类似点对点通信的需求，写了一个简单的插件来实现这个功能。
> p2p不是搞传销的那个p2p，含义是:point to point.
## 2.使用方法
本插件为EMQX新增一个内置topic：`$p2p`，客户端需要订对点通信的时候，只需要按照以下格式来发送即可：
```
含义：给topic下客户端id为topic的客户端单独发送一条数据
topic:$p2p/{clientId}/{topic}
payload:数据内容
```
其中`{clientId}`就是要发送的对端的clientid.如果是python客户端，A客户端给B发送数据，最简单的代码描述应该是这样：
```python
client.publish('$p2p/B/topic1', json.dumps({a:1,b:2}, ensure_ascii=False))
```
> 注意:`{clientId}`为空的时候不发送任何数据，也不会返回任何数据


## 3.开源协议
-------

Apache License Version 2.0

## 4.作者
------
wwhai，QQ：751957846（email：+@qq.com）
