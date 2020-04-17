# ezlinker_p2p_plugin:MQTT客户端点对点通信插件
## 1.简介
MQTT标准协议规定：如果两个客户端之间要通信，必须订阅相同的topic。但是这种做法不适合单个客户端之间的直接通信。为了解决类似点对点通信的需求，写了一个简单的插件来实现这个功能。本插件仅仅是为了增强EMQX的功能，不是Mqtt协议的规范，请多大家注意。
> p2p不是搞传销的那个p2p，含义是:point to point.
## 2.使用方法
本插件为EMQX新增一个内置topic：`$p2p/{client_id}`，客户端需要订对点通信的时候，只需要 给topic下客户端id为topic的客户端单独发送一条数据
```
topic:$p2p/{client_id}
payload:数据内容
```

其中`{client_id}`就是要发送的对端的clientid.如果是python客户端，A客户端给B发送数据，最简单的代码描述应该是这样：
```python
client.publish('$p2p/client1', json.dumps({a:1,b:2}, ensure_ascii=False))
```
> 注意:`{clientId}`为空的时候不发送任何数据，也不会返回任何数据

这里给出一个简单的客户端方便测试:

```python
import paho.mqtt.client as mqtt
import json
# 连接成功以后打印
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))

# 注意 我们没有给客户端订阅任何Topic，就可以收的到消息
def on_message(client, userdata, msg):
    print(msg.topic+" " + ":" + str(msg.payload))

client = mqtt.Client("client1")
client.username_pw_set("username", "password")
client.on_connect = on_connect
client.on_message = on_message
client.connect("10.168.1.159",1883, 60)
client.loop_forever()
```
## 3.注意事项
- client_id 不可空；
- 不需要订阅 `$p2p/`,不然会收到2条消息。
## 4.开源协议
-------

Apache License Version 2.0

## 4.作者
------
wwhai，QQ：751957846（email：+@qq.com）
