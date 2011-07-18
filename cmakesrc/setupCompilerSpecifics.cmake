
#fortran compiler stuff... extensive example
# FFLAGS depend on the compiler

# SET(CMAKE_FORTRAN_COMPILER mpif77)
if (CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
    message( "--- ifort is recommended fortran compiler ---")
   # General:
    set(CMAKE_Fortran_FLAGS " -fno-range-check -fno-f2c ") # remove -g -O2 from main list
    
   # Release flags:
    # ON APPLE machines and on 32bit Linux systems, -O2 seems to be the highest optimization level possible
    # for file l_complex_taylor.f90
    if(APPLE OR ${CMAKE_SIZEOF_VOID_P} EQUAL 4)
        set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -O2 ")
    else()
      set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -O4 ")
    endif()
    
   # Debug flags:
    set(CMAKE_Fortran_FLAGS_DEBUG   " -O0 -g ")
    
   # Additional option dependent flags:
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif ()
    if (MADX_GOTOBLAS2)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fexternal-blas")
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -lgoto2 ")
    endif (MADX_GOTOBLAS2)
    

elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "Intel")
    set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -assume noold_unit_star -D_INTEL_IFORT_SET_RECL")
    set(CMAKE_Fortran_FLAGS_DEBUG   " -f77rtl -O3 -g -assume noold_unit_star -D_INTEL_IFORT_SET_RECL")
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif ()
    if(MADX_FEDORA_FIX)
        message( WARNING "Only use the Fedora fix if you are using Fedora!" )
        set(CMAKE_Fortran_FLAGS " -no-ipo ")
    endif()

elseif(CMAKE_Fortran_COMPILER MATCHES "lf95")
    message( WARNING " This compiler is not yet confirmed working properly with CMake")
    if ( MADX_FORCE_32 )
        message( WARNING " On a 64 bit system you need to use the toolchain-file (see README) to get anywhere with the 32bit compiler.")
    endif ( MADX_FORCE_32 )
    set(CMAKE_Fortran_FLAGS_RELEASE " --o2 --tp  ")
    set(CMAKE_SKIP_RPATH ON)
    set(CMAKE_Fortran_FLAGS_DEBUG   " --info --f95 --lst -V -g  --ap --trace --trap --verbose  --chk aesux ")
    set(CMAKE_SHARED_LIBRARY_LINK_Fortran_FLAGS "") #suppress rdynamic which doesn't work for lf95...
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif ()

elseif(CMAKE_Fortran_COMPILER MATCHES "nagfor")
    message( WARNING " Make sure you use the same gcc as nagfor is compiled with, or linking WILL fail.")
    set(CMAKE_SKIP_RPATH ON)
    set(CMAKE_Fortran_FLAGS_RELEASE " -gline -maxcontin=100 -ieee=full -D_NAG ")
    set(CMAKE_Fortran_FLAGS_DEBUG   " -gline -maxcontin=100 -ieee=full -D_NAG -C=all -nan ")
    set(CMAKE_SHARED_LIBRARY_LINK_Fortran_FLAGS "") #suppress rdynamic which isn't recognized by nagfor...
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -Bstatic ")
    endif ()

elseif(CMAKE_Fortran_COMPILER MATCHES "g77")
    message( WARNING " This compiler is not yet confirmed working for mad-x")
    message( "--- ifort is recommended fortran compiler ---")
    set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -fno-f2c -O3 ")
    set(CMAKE_Fortran_FLAGS_DEBUG   " -fno-f2c -O0 -g ")
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif ()

elseif(CMAKE_Fortran_COMPILER MATCHES "g95")
    message( "--- ifort is recommended fortran compiler ---")
    set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -fno-second-underscore -fshort-circuit -O2 ")
    set(CMAKE_Fortran_FLAGS_DEBUG   " -fno-second-underscore -O3 -g -Wall -pedantic -ggdb3")  
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif ()

elseif(CMAKE_Fortran_COMPILER_ID MATCHES "PathScale")
    message( WARNING " This compiler is not yet confirmed working for mad-x")
    message( "--- ifort is recommended fortran compiler ---")
    set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -O3 ")
    set(CMAKE_Fortran_FLAGS_DEBUG   " -O0 -g ")  
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif()

else()
    message( "--- ifort is recommended fortran compiler ---")
    message( WARNING " Your compiler is not recognized. Mad-X might not compile successfully.")
    message("Fortran compiler full path: " ${CMAKE_Fortran_COMPILER})
    message("Fortran compiler: " ${Fortran_COMPILER_NAME})
    set(CMAKE_Fortran_FLAGS_RELEASE " -funroll-loops -fno-range-check -O2")
    set(CMAKE_Fortran_FLAGS_DEBUG   "-O0 -g")
    if ( MADX_STATIC )
        set(CMAKE_Fortran_LINK_FLAGS   "${CMAKE_Fortran_LINK_FLAGS} -static ")
    endif ( MADX_STATIC )
endif()
#end fortran compiler stuff...


# General compile flags:
set(CMAKE_C_FLAGS_DEBUG   " ${CMAKE_C_FLAGS_DEBUG} -Wall -pedantic ")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -funroll-loops -D_CATCH_MEM -D_WRAP_FORTRAN_CALLS -D_WRAP_C_CALLS -D_FULL -I. -I${CMAKE_CURRENT_SOURCE_DIR} ")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -funroll-loops -D_CATCH_MEM -D_WRAP_FORTRAN_CALLS -D_WRAP_C_CALLS -D_FULL -I. -I${CMAKE_CURRENT_SOURCE_DIR} ") #needed for c++ linking
set(CMAKE_CXX_FLAGS_DEBUG " ${CMAKE_CXX_FLAGS_DEBUG} -g -Wall")
set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -D_CATCH_MEM -D_WRAP_FORTRAN_CALLS -D_WRAP_C_CALLS -D_FULL -I. -I${CMAKE_CURRENT_SOURCE_DIR} ") 


# C stuff:
if(CMAKE_C_COMPILER_ID MATCHES "GNU" AND NOT CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
# this will probably crash on windows...
  execute_process(COMMAND ${C_COMPILER_NAME} -print-search-dirs
                  OUTPUT_VARIABLE gccsearchdirs)
  string(REGEX REPLACE ".*libraries: =(.*)\n"  "\\1" gcclibs "${gccsearchdirs}")
  # need to do this many times because lf95 segfaults on lists with :
  string(REPLACE "/:/"  "/ -L/" gcclibs "${gcclibs}")
  # adding these to the linking process which is handled by a non-gnu fortran compiler in your case
  link_directories(${gcclibs}) 
endif()
# end C stuff


if(MADX_ONLINE )
    message("Online Model turned on" )
    if( NOT MADX_STATIC )
        message( WARNING "You might have problems finding the shared libraries for SDDS" )
    endif()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_ONLINE ")
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -D_ONLINE ")
endif()
