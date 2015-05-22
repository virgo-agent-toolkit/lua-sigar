PROJECT(sigar)

if(MSVC)
  # Statically build against C runtime (use the right version for Release/Debug)
  set(CompilerFlags
        CMAKE_CXX_FLAGS
        CMAKE_CXX_FLAGS_DEBUG
        CMAKE_CXX_FLAGS_RELEASE
        CMAKE_C_FLAGS
        CMAKE_C_FLAGS_DEBUG
        CMAKE_C_FLAGS_RELEASE
        )
  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
  endforeach()
endif()

cmake_minimum_required(VERSION 2.6)

INCLUDE(CheckIncludeFiles)
INCLUDE(CheckFunctionExists)
INCLUDE(CheckTypeSize)
INCLUDE(CTest)
INCLUDE(InstallRequiredSystemLibraries)

ENABLE_TESTING()

SET(CPACK_PACKAGE_VERSION_MAJOR "1")
SET(CPACK_PACKAGE_VERSION_MINOR "6")
SET(CPACK_PACKAGE_VERSION_PATCH "2")
SET(CPACK_PACKAGE_VENDOR "Hyperic")
SET(CMAKE_MACOSX_RPATH 1)
INCLUDE(CPack)

INCLUDE_DIRECTORIES(deps/lua)

IF(WIN32) 
  ## make sure we only use the smallest set of 
  ## headers on win32. Otherwise we get clashes 
  ## between winsock2.h and winsock.h
  ADD_DEFINITIONS(-DWIN32_LEAN_AND_MEAN)

  # force the correct version for the redist manifest
  ADD_DEFINITIONS(-D_BIND_TO_CURRENT_MFC_VERSION=1 -D_BIND_TO_CURRENT_CRT_VERSION=1)
  # turn off security warnings for system calls
  ADD_DEFINITIONS(-D_CRT_SECURE_NO_WARNINGS)

  # Download luvi.lib
  FILE(DOWNLOAD
    "https://github.com/luvit/luvi/releases/download/v2.0.9/luvi-static-Windows-amd64.lib"
    "${CMAKE_BINARY_DIR}/luvi.lib"
  )
  # Download luvi_renamed.lib to support renaming luvi.exe
  FILE(DOWNLOAD
    "https://github.com/luvit/luvi/releases/download/v2.0.9/luvi_renamed-static-Windows-amd64.lib"
    "${CMAKE_BINARY_DIR}/luvi_renamed.lib"
  )
  # Delay load luvi.exe when loaded as support code by this DLL
  SET(SIGAR_LINK_FLAGS "${SIGAR_LINK_FLAGS} /DELAYLOAD:luvi.exe /INCLUDE:__pfnDliFailureHook2")
ENDIF(WIN32)

## sigar has some base files + a set of platform specific files

MESSAGE(STATUS "CMAKE_SYSTEM_NAME is ${CMAKE_SYSTEM_NAME}")

ADD_DEFINITIONS(-DLUA_COMPAT_MODULE)
INCLUDE_DIRECTORIES(deps/sigar/include/)

INCLUDE(CheckCSourceCompiles)

MACRO (CHECK_STRUCT_MEMBER _STRUCT _MEMBER _HEADER _RESULT)
   SET(_INCLUDE_FILES)
   FOREACH (it ${_HEADER})
      SET(_INCLUDE_FILES "${_INCLUDE_FILES}#include <${it}>\n")
   ENDFOREACH (it)

   SET(_CHECK_STRUCT_MEMBER_SOURCE_CODE "
${_INCLUDE_FILES}
int main()
{
   static ${_STRUCT} tmp;
   if (sizeof(tmp.${_MEMBER}))
      return 0;
  return 0;
}
")
   CHECK_C_SOURCE_COMPILES("${_CHECK_STRUCT_MEMBER_SOURCE_CODE}" ${_RESULT})

ENDMACRO (CHECK_STRUCT_MEMBER)


## linux
IF(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  SET(SIGAR_SRC deps/sigar/src/os/linux/linux_sigar.c)

  INCLUDE_DIRECTORIES(deps/sigar/src/os/linux/)
ENDIF(CMAKE_SYSTEM_NAME STREQUAL "Linux")

## macosx, freebsd
IF(CMAKE_SYSTEM_NAME MATCHES "(Darwin|FreeBSD)")
  SET(SIGAR_SRC deps/sigar/src/os/darwin/darwin_sigar.c)

  INCLUDE_DIRECTORIES(deps/sigar/src/os/darwin/)
  IF(CMAKE_SYSTEM_NAME MATCHES "(Darwin)")
    ADD_DEFINITIONS(-DDARWIN)
    SET(SIGAR_LINK_FLAGS "-framework CoreServices -framework IOKit")
  ELSE(CMAKE_SYSTEM_NAME MATCHES "(Darwin)")
    ## freebsd needs libkvm
    SET(SIGAR_LINK_FLAGS "-lkvm")
  ENDIF(CMAKE_SYSTEM_NAME MATCHES "(Darwin)")
ENDIF(CMAKE_SYSTEM_NAME MATCHES "(Darwin|FreeBSD)")

## solaris
IF (CMAKE_SYSTEM_NAME MATCHES "(Solaris|SunOS)" )
  SET(SIGAR_SRC
    deps/sigar/src/os/solaris/solaris_sigar.c
    deps/sigar/src/os/solaris/get_mib2.c
    deps/sigar/src/os/solaris/kstats.c
    deps/sigar/src/os/solaris/procfs.c
  )

  INCLUDE_DIRECTORIES(deps/sigar/src/os/solaris/)
  ADD_DEFINITIONS(-DSOLARIS)
  SET(SIGAR_LINK_FLAGS -lkstat -ldl -lnsl -lsocket -lresolv)
ENDIF(CMAKE_SYSTEM_NAME MATCHES "(Solaris|SunOS)" )

## solaris
IF (CMAKE_SYSTEM_NAME MATCHES "(hpux)" )
  SET(SIGAR_SRC deps/sigar/src/os/hpux/hpux_sigar.c)
  INCLUDE_DIRECTORIES(deps/sigar/src/os/hpux/)
  ADD_DEFINITIONS(-DSIGAR_HPUX)
  SET(SIGAR_LINK_FLAGS -lnm)
ENDIF(CMAKE_SYSTEM_NAME MATCHES "(hpux)" )

## aix
IF (CMAKE_SYSTEM_NAME MATCHES "(AIX)" )
  SET(SIGAR_SRC deps/sigar/src/os/aix/aix_sigar.c)

  INCLUDE_DIRECTORIES(os/aix/)
  SET(SIGAR_LINK_FLAGS -lodm -lcfg)
ENDIF(CMAKE_SYSTEM_NAME MATCHES "(AIX)" )

IF(WIN32)
  SET(SIGAR_SRC deps/sigar/src/os/win32/wmi.cpp deps/sigar/src/os/win32/peb.c deps/sigar/src/os/win32/win32_sigar.c)
  INCLUDE_DIRECTORIES(deps/sigar/src/os/win32)
  CHECK_STRUCT_MEMBER(MIB_IPADDRROW wType "windows.h;iphlpapi.h" wType_in_MIB_IPADDRROW)
  add_definitions(-DHAVE_MIB_IPADDRROW_WTYPE=${wType_in_MIB_IPADDRROW})
ENDIF(WIN32)

SET(SIGAR_SRC ${SIGAR_SRC}
  deps/sigar/src/sigar.c
  deps/sigar/src/sigar_cache.c
  deps/sigar/src/sigar_fileinfo.c
  deps/sigar/src/sigar_format.c
  deps/sigar/src/sigar_getline.c
  deps/sigar/src/sigar_ptql.c
  deps/sigar/src/sigar_signal.c
  deps/sigar/src/sigar_util.c
  deps/sigar/bindings/lua/sigar-cpu.c                 
  deps/sigar/bindings/lua/sigar-disk.c                
  deps/sigar/bindings/lua/sigar-fs.c                  
  deps/sigar/bindings/lua/sigar-load.c                 
  deps/sigar/bindings/lua/sigar-mem.c                 
  deps/sigar/bindings/lua/sigar-netif.c               
  deps/sigar/bindings/lua/sigar-proc.c                
  deps/sigar/bindings/lua/sigar-swap.c                
  deps/sigar/bindings/lua/sigar-sysinfo.c             
  deps/sigar/bindings/lua/sigar-test.lua              
  deps/sigar/bindings/lua/sigar-who.c                 
  deps/sigar/bindings/lua/sigar.c                     
)

ADD_LIBRARY(sigar MODULE ${SIGAR_SRC})

IF(UNIX AND (CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64"))
  SET_TARGET_PROPERTIES(sigar PROPERTIES COMPILE_FLAGS "-fPIC")
ENDIF(UNIX AND (CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64"))

IF(WIN32)
	TARGET_LINK_LIBRARIES(sigar luvi luvi_renamed ws2_32 netapi32 version)
ENDIF(WIN32)

IF (UNIX)
  SET_TARGET_PROPERTIES(sigar
    PROPERTIES
    PREFIX ""
    SUFFIX ".so"
  )
ENDIF (UNIX)

IF (WIN32)
  SET_TARGET_PROPERTIES(sigar
    PROPERTIES
    PREFIX ""
    SUFFIX ".dll"
  )
ENDIF (WIN32)

IF (APPLE)
  SET(CMAKE_SHARED_MODULE_CREATE_C_FLAGS "${CMAKE_SHARED_MODULE_CREATE_C_FLAGS} -flat_namespace -undefined suppress")
ENDIF (APPLE)

IF(SIGAR_LINK_FLAGS)
  SET_TARGET_PROPERTIES(sigar PROPERTIES LINK_FLAGS "${SIGAR_LINK_FLAGS}")
ENDIF(SIGAR_LINK_FLAGS)
