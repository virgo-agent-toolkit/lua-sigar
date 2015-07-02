@ECHO off

IF NOT "x%1" == "x" GOTO :%1

GOTO :build

:build
cmake -H. -Bbuild -G"Visual Studio 12 Win64"
cmake --build build --config Release -- /maxcpucount
COPY build\Release\sigar.dll .

:build32
cmake -H. -Bbuild32 -G"Visual Studio 12"
cmake --build build32 --config Release -- /maxcpucount
COPY build32\Release\sigar.dll sigar32.dll
