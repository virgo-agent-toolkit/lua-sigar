@ECHO off

IF NOT "x%1" == "x" GOTO :%1

GOTO :build

:build
cmake -H. -Bbuild -G"Visual Studio 12 Win64"
cmake --build build --config Release -- /maxcpucount
COPY build\Release\sigar.dll .
