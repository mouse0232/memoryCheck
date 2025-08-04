#!/usr/bin/env bash

# 兼容部分系统 echo 不支持 -e，定义 echo 为 echo -e
function echo() {
    command echo -e "$@"
}

# 遇到错误、未定义变量或管道失败时立即退出
# set -euo pipefail


# 设置并检测 locale，优先使用 en_US.UTF-8
if locale -a | grep -qi '^en_US\.utf8$'; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
elif locale -a | grep -qi '^en_US\.utf-8$'; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
else
    echo -e "\033[33mWarning: en_US.UTF-8 locale is not available, current locale: $LANG\033[0m"
fi

echo -e "\033[33m内存超售检测开始\033[0m"
echo -e "\033[0m====================\033[0m"

# 检查内存分配是否超出物理内存+swap（超售）
echo -e "\033[36m检查内存分配是否超出物理内存+swap \033[0m"
commit_limit="$(awk '/CommitLimit/ {print $2}' /proc/meminfo 2>/dev/null)"
if [[ $? -ne 0 ]]; then
    echo -e "\033[31m错误：awk 获取 CommitLimit 失败\033[0m"; exit 1
fi
committed_as="$(awk '/Committed_AS/ {print $2}' /proc/meminfo 2>/dev/null)"
if [[ $? -ne 0 ]]; then
    echo -e "\033[31m错误：awk 获取 Committed_AS 失败\033[0m"; exit 1
fi
if [[ -z "$commit_limit" || -z "$committed_as" ]]; then
    echo -e "\033[33m警告：无法获取 CommitLimit 或 Committed_AS 信息\033[0m"
elif [[ "$committed_as" -gt "$commit_limit" ]]; then
    echo -e "\033[31m警告：系统内存分配已超出物理内存+swap总和（超售）\033[0m"
    echo -e "\033[31mCommitted_AS: $committed_as kB, CommitLimit: $commit_limit kB\033[0m"
else
    echo -e "\033[32m系统内存分配未超出物理内存+swap总和\033[0m"
    echo -e "\033[32mCommitted_AS: $committed_as kB, CommitLimit: $commit_limit kB\033[0m"
fi
echo -e "\033[0m====================\033[0m"

# 检查是否使用了 SWAP 超售内存
echo -e "\033[36m检查是否使用了 SWAP 超售内存\033[0m"
memSize=""
awk_memtotal=$(awk '/MemTotal/ {printf("%d", $2/1024)}' /proc/meminfo 2>/dev/null || true)
if [[ -n "$awk_memtotal" && "$awk_memtotal" -gt 0 ]]; then
    memSize="$awk_memtotal"
else
    # 兜底方案，尝试用 free 命令（兼容英文和中文）
    free_mem=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || true)
    if [[ -n "$free_mem" && "$free_mem" -gt 0 ]]; then
        memSize="$free_mem"
    else
        echo -e "\033[33m警告：无法获取内存总量\033[0m"
        memSize="1024" # 默认1G，防止后续命令报错
    fi
fi
dd_output=""
dd_output=$(dd if=/dev/zero of=/dev/null bs=1M count="$memSize" 2>&1)
if [[ $? -ne 0 ]]; then
    echo -e "\033[31m错误：dd 命令执行失败\033[0m"
    speed="0"
else
    speed="$(echo "$dd_output" | awk '{print $(NF-1)}' | awk 'END {print}' | awk -F '[，,]' '{print $NF}')"
fi
speed="$(echo "$speed" | awk '{printf("%.0f\n",$1)}')"
if [[ -z "$speed" || "$speed" == "0" ]]; then
    echo -e "\033[33m警告：无法检测内存 IO 速度\033[0m"
    speed="0"
fi
echo -e "\033[34m内存 IO 速度: $speed GB/s\033[0m"
if [[ "$speed" -lt 10 ]]; then
    echo -e "\033[31m内存 IO 速度低于 10 GB/s\033[0m"
    echo -e "\033[31m可能存在 SWAP 超售内存\033[0m"
else
    echo -e "\033[32m内存 IO 速度正常\033[0m"
    echo -e "\033[32m未使用 SWAP 超售内存\033[0m"
fi
echo -e "\033[0m====================\033[0m"

# 检查是否使用了气球驱动 Balloon 超售内存
echo -e "\033[36m检查是否使用了 气球驱动 Balloon 超售内存\033[0m"
lsmod 2>/dev/null | grep -q "virtio_balloon"
lsmod_status=$?
if [[ $lsmod_status -eq 2 ]]; then
    echo -e "\033[31m错误：lsmod 命令执行失败\033[0m"
elif [[ $lsmod_status -eq 0 ]]; then
    echo -e "\033[31m存在 virtio_balloon 模块\033[0m"
    echo -e "\033[31m可能使用了 气球驱动 Balloon 超售内存\033[0m"
else
    echo -e "\033[32m不存在 virtio_balloon 模块\033[0m"
    echo -e "\033[32m未使用 气球驱动 Balloon 超售内存\033[0m"
fi
echo -e "\033[0m====================\033[0m"

# 检查是否使用了 Kernel Samepage Merging (KSM) 超售内存
echo -e "\033[36m检查是否使用了 Kernel Samepage Merging (KSM) 超售内存\033[0m"
ksm_run="0"
if [[ -f "/sys/kernel/mm/ksm/run" ]]; then
    ksm_run="$(cat /sys/kernel/mm/ksm/run 2>/dev/null || true)"
    # 不再判断$?，直接用内容判断
    if [[ -z "$ksm_run" ]]; then
        echo -e "\033[31m错误：读取 /sys/kernel/mm/ksm/run 失败\033[0m"
        ksm_run="0"
    fi
fi
if [[ "$ksm_run" == "1" ]]; then
    echo -e "\033[31mKernel Samepage Merging 状态为 1\033[0m"
    echo -e "\033[31m可能使用了 Kernel Samepage Merging (KSM) 超售内存\033[0m"
else
    echo -e "\033[32mKernel Samepage Merging 状态正常\033[0m"
    echo -e "\033[32m未使用 Kernel Samepage Merging (KSM) 超售内存\033[0m"
fi
echo -e "\033[0m====================\033[0m"
