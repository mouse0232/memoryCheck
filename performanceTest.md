# performanceTest

用于快速检测VPS的CPU和内存性能的程序，基于Golang编写。功能和测试内容都很简单，出发点是因为UnixBench和Geekbench大而全，耗时太多了，不适合上手简测。

实现方法如下：

- 计算i++到2000000000时i*i的耗时
- 计算i++到100000000时内存顺序赋值的耗时

## 一键脚本
```
curl -s https://raw.githubusercontent.com/uselibrary/memoryCheck/main/performanceTest.sh | bash
```

## 输入结果
输出结果，包括CPU和内存的操作耗时，越小越好。
以E5V4 KVM VPS为例：
```
Starting CPU and RAM performance test...
Calculations took: 864.414482ms
Memory operations took: 1.26858103s
```
短期内多次运行，时间可能会大幅缩短，因为系统、内存和CPU都有缓存，加快了运行速度。
```
Starting CPU and RAM performance test...
Calculations took: 842.915184ms # CPU运行时间缩短了
Memory operations took: 363.394008ms # 内存时间大幅减小
```