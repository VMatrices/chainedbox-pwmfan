# chainedbox-pwmfan

我家云/粒子云第三方系统风扇自动调速脚本



### 注意

不同系统设备树不同，请根据自身情况修改脚本init_fan、stop_fan方法



#### 目前已知的情报

gpio79为风扇电源，可通过以下方式开启：

```
echo 79 > /sys/class/gpio/export
echo high > /sys/class/gpio/gpio79/direction
```

关闭：

```
echo low > /sys/class/gpio/gpio79/direction
echo 79 > /sys/class/gpio/unexport
```

> 来源：[**粒子云风扇调速原理** ](https://www.right.com.cn/forum/forum.php?tid=1005987)




![Screen](/preview.png)



