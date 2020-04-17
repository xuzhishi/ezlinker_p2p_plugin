# ezlinker_p2p_plugin:MQTT客户端点对点通信插件
## 1.简介
MQTT标准协议规定：如果两个客户端之间要通信，必须订阅相同的topic。但是这种做法不适合单个客户端之间的直接通信。为了解决类似点对点通信的需求，写了一个简单的插件来实现这个功能。
> p2p不是搞传销的那个p2p，含义是:point to point.
## 2.使用方法
本插件为EMQX新增一个内置topic：`$p2p`，客户端需要订对点通信的时候，只需要按照以下格式来发送即可：
```
含义：给topic下客户端id为topic的客户端单独发送一条数据
topic:$p2p/{clientId}
payload:数据内容
```
其中`{clientId}`就是要发送的对端的clientid.如果是python客户端，A客户端给B发送数据，最简单的代码描述应该是这样：
```python
client.publish('$p2p/B/topic1', json.dumps({a:1,b:2}, ensure_ascii=False))
```
> 注意:`{clientId}`为空的时候不发送任何数据，也不会返回任何数据

这里给出一个简单的客户端方便测试:

```python
import paho.mqtt.client as mqtt
import json
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))
    ## client.subscribe("/device/10001/s2c")

def on_message(client, userdata, msg):
    print(msg.topic+" " + ":" + str(msg.payload))

client = mqtt.Client("p1")
client.username_pw_set("username", "password")
client.on_connect = on_connect
client.on_message = on_message
client.connect("10.168.1.159",1883, 60)

def run():
    client.loop_forever()

import time
import threading
main=threading.Thread(target = run)
main.start()
# msg={"action":"1","msgid":"20190221095350622453353","type":"1","price":"1"}
# client.publish(topic="/device/NodeMcu1",payload=json.dumps(msg))
# while 1:
#    time.sleep(1)
#    client.publish(topic="/device/NodeMcu1",payload=json.dumps(msg))
```
## 3.开源协议
-------

Apache License Version 2.0

## 4.作者
------
wwhai，QQ：751957846（email：+@qq.com）
