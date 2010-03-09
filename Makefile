#######################################################################
#
# Makefile for MAD-X development version
#
#######################################################################

CC=gcc
f95=ifort
ARCH=32
DEBUG=NO
ONLINE=YES
MEMLEAKS=NO
PROFILE=NO
PLUGIN_SUPPORT=NO
SLC4=YES
SLC5=NO
FC12=NO
NTPSA=YES

ONMAC=NO

ifeq ($(findstring arwin, $(OSTYPE)),arwin)
  ONMAC=YES
# Presently g95 is no longer the default for Darwin since
# gfortran is more available. The latter comes automatically
# with gcc. Special LIBX is needed for g95 (see below)
# ATTENTION: gfortran is broken in gcc4.4 on Darwin therefore 
# back to g95 
#  f95=g95
  f95=gfortran
#  for darwin go now by default to 64 bit executables
  ARCH=64

#!!!!!!!!!!!!!!!!!!!!!!!!!!!
# DON'T TOUCH FOR DARWIN !!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!

  DEBUG=NO
  MEMLEAKS=NO
  PROFILE=NO
  SLC4=NO
  SLC5=NO
  FC12=NO
endif

#######################################################################
# Compilers
#######################################################################

#!!!!!!!!!!!!!!!!!!
# C compilers
#!!!!!!!!!!!!!!!!!!
# CC=gcc

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# FORTRAN90 compilers proven to work
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Production: Lahey
# f95=lf95

# GNU g95
# f95=g95

# For gfortran the version of gcc has to be > 4.3.2 not standard for SLC4
# GNU gfortran
# f95=gfortran

# NAG f95
# f95=f95

# Intel ifort
# f95=ifort

#######################################################################
# Compile flags
#######################################################################

ifeq ($(ARCH),32)
  M32= -m32
else
  ifeq ($(findstring arwin, $(OSTYPE)),arwin)
    M32= -m64
  endif
endif

# Production: C compiler flag options
 GCCP_FLAGS= -g $(M32) -funroll-loops -D_CATCH_MEM -D_WRAP_FORTRAN_CALLS -D_WRAP_C_CALLS -I. -D_FULL
# to turn off fatal error at memory overflow add -D_DONOTCATCHOVERFLOW

# Standard FORTRAN flags
 f95_FLAGS= -c -funroll-loops -I.


#######################################################################
# Link options
#######################################################################

LDOPT=-static $(M32)

#######################################################################
# Compiler special treatment
#######################################################################


ifeq ($(f95),lf95)
  ifeq ($(ARCH),32)
    f95_FLAGS= --o2 --tp -c -Wa,--32
  else
    f95_FLAGS= --o2 --tp -c
  endif
endif

ifeq ($(f95),f95)
  ifeq ($(ARCH),32)
    f95_FLAGS= -gline -c -Wc,-m32 -Wl,-m32 -maxcontin=100 -ieee=full -D_NAG
    LDOPT= -Bstatic -Wl,-m32
  else
    f95_FLAGS= -gline -c -maxcontin=100 -ieee=full -D_NAG
    LDOPT= -Bstatic
  endif
endif

ifeq ($(f95),ifort)
    f95_FLAGS+= -assume noold_unit_star -D_INTEL_IFORT_SET_RECL
endif


ifeq ($(f95),g95)
  ifeq ($(ARCH),32)
    f95_FLAGS+= -Wa,--32 -fno-second-underscore
  else
    f95_FLAGS+= -Wa,--64 -fno-second-underscore
  endif
endif

ifeq ($(f95),gfortran)
  f95_FLAGS+= -fno-range-check
endif

ifeq ($(DEBUG),YES)
  ifeq ($(f95),lf95)
    # Replace Makefile_develop
    # lff95 compiler options with severe lf95/Fujitsu flags
    f95_FLAGS+= -X9 -AERTp -Ncompdisp -V -li -m6 -r5 -g -Hesu -a -e0 -E iu -Am --pca --private --trap
    GCCP_FLAGS+= -Wall -pedantic
  endif
  ifeq ($(f95),f95)
    # Replace Makefile_nag
    f95_FLAGS+= -C=all -nan
    GCCP_FLAGS+= -Wall -pedantic
  endif
  ifeq ($(f95),g95)
    # Replace Makefile_nag
    f95_FLAGS+= -ggdb3
    GCCP_FLAGS+= -Wall -pedantic -ggdb3
  endif
  ifeq ($(f95),gfortran)
    f95_FLAGS+= -Wall -pedantic
    GCCP_FLAGS+= -Wall -pedantic
  endif
else
  GCCP_FLAGS+= -O4
  # use level 4 optimization, except for lf95 or on MAC
  ifneq ($(f95),lf95)
    ifeq ($(ONMAC),NO)
      f95_FLAGS+= -O4
	endif
  endif
endif

ifeq ($(SLC4),YES)
  ifeq ($(f95),gfortran)
    # Needed on SLC4
    #
    # works on SLC4 genuine 32bit
    #
    # source /afs/cern.ch/sw/lcg/contrib/gcc/4.3/i686/setup.csh
    # GF_HOME=/afs/cern.ch/sw/lcg/contrib/gcc/4.3/i686/bin/
    #
    # works on SLC4 lxplus 64bit needed for 32bit
    #
    # source /afs/cern.ch/sw/lcg/contrib/gcc/4.3/slc4_amd64_gcc43/setup.csh
    GF_HOME= /afs/cern.ch/sw/lcg/contrib/gcc/4.3/slc4_amd64_gcc43/bin/
     CC=$(GF_HOME)gcc
    f95=$(GF_HOME)gfortran
    f95_FLAGS+= $(M32)
  endif
endif

LIBX= -L/usr/X11R6/lib -lX11 -L/usr/lib -lpthread -lstdc++

ifeq ($(findstring arwin, $(OSTYPE)),arwin)
  ONLINE=NO
  ifeq ($(f95),g95)
    LIBX= -L/usr/X11R6/lib -lX11 -L/usr/lib -lpthread -L/sw/lib/gcc4.4/lib -lstdc++ -L/sw/lib/gcc4.4/lib/gcc/i686-apple-darwin9/4.4.0 -lgcc_eh  
  endif
endif

ifeq ($(SLC4),YES)
  ifeq ($(ARCH),32)
    LIBX= -L/usr/X11R6/lib -lX11 -L/usr/lib -lpthread -L/usr/lib/gcc/i386-redhat-linux/3.4.3 -lstdc++
    ifneq ($(f95),ifort)
      LIBX+= /usr/lib/gcc/x86_64-redhat-linux5E/4.1.2/32/libgcc_eh.a
    endif
  else
    LIBX= -L/usr/X11R6/lib64 -lX11 -L/usr/lib/gcc/i386-redhat-linux/3.4.3 -lstdc++
    ifneq ($(f95),ifort)
      LIBX+= /usr/lib/gcc/x86_64-redhat-linux5E/4.1.2/libgcc_eh.a
    endif
  endif
endif

ifeq ($(SLC5),YES)
  ifeq ($(ARCH),32)
    LIBX= libX11.a  -L/usr/lib -lpthread -L/usr/lib/gcc/i386-redhat-linux/3.4.6 -lstdc++
    ifneq ($(f95),ifort)
      LIBX+= /usr/lib/gcc/x86_64-redhat-linux6E/4.3.2/32/libgcc_eh.a
    endif
  else
    LIBX= libX11_64.a -lstdc++
    ifneq ($(f95),ifort)
      LIBX+= /usr/lib/gcc/x86_64-redhat-linux6E/4.3.2/libgcc_eh.a
    endif
  endif
endif

ifeq ($(FC12),YES)
  ifeq ($(ARCH),64)
    LIBX= -lX11 -lxcb -lXau -lXdmcp -lpthread -lstdc++
  else
    LIBX= -L/usr/lib/ -lX11 -lxcb -lXau -lXdmcp -lpthread -L/usr/lib/gcc/i686-redhat-linux/4.4.2/ -lstdc++ -L/usr/lib/gcc/x86_64-redhat-linux/4.4.2/32/ -lgcc_eh
  endif
endif

ifeq ($(MEMLEAKS),YES)
  ifeq ($(f95),f95)
    f95_FLAGS+= -C=all -mtrace=size,line
    GCCP_FLAGS+= -Wall -pedantic -D_MEM_LEAKS
    LDOPT+= -mtrace=size,line
  endif
endif

ifeq ($(ONLINE),YES)
  GCCP_FLAGS+= -D_ONLINE
  ifeq ($(f95),ifort)
    LIBX+= -limf
  endif
  ifeq ($(ARCH),32)
    LIBX+= libSDDS1c.a libSDDS1.a librpnlib.a libmdbmth.a libmdblib.a libgsl.a libz.a
  else
    LIBX+= libSDDS1c64.a libSDDS164.a librpnlib64.a libmdbmth64.a libmdblib64.a libgsl64.a libz64.a
  endif
endif

ifeq ($(PROFILE),YES)
  f95_FLAGS+= -pg
  GCCP_FLAGS+= -pg
  LDOPT+= -pg
endif

ifeq ($(PLUGIN_SUPPORT),YES)
  GCCP_FLAGS+= -DPLUGIN_SUPPORT
  LDOPT=-dynamic $(M32)
  LDOPT=--export $(M32)
endif

ifeq ($(findstring arwin, $(OSTYPE)),arwin)
# allows running of madx under Macinstosh System 10
# include headers for gxx11c
  GCCP_FLAGS += -I /usr/X11R6/include/
  ifeq ($(f95),g95)
    f95_FLAGS= -c -funroll-loops -I. -fno-second-underscore $(M32)
  endif
  ifeq ($(f95),gfortran)
    f95_FLAGS += $(M32)
  endif
  LDOPT= $(M32)
endif

default: madx

# dependencies of madxp which combines the C-code
madxp.o: madxp.c madxn.c madxu.c aperture.c madxe.c madxc.c matchc.c matchc2.c sxf.c makethin.c c6t.c madxreg.c madxreg.h madx.h madxl.h madxd.h madxdict.h c6t.h matchptcknobs.h fortran_wrappers.h c_wrappers.h
	$(CC) $(GCCP_FLAGS) -c -o madxp.o madxp.c

# automatically generated code
fortran_wrappers.h:
	python wrap_fortran_calls.py # creates fortran_wrappers.c fortran_wrappers.h fortran_prototypes.h fortran_wrappers_prototypes.h

c_wrappers.h:
	python wrap_C_calls.py	

fortran_wrappers.o: fortran_wrappers.c
	$(CC) $(GCCP_FLAGS) -c fortran_wrappers.c

c_wrappers.o: c_wrappers.c
	$(CC) $(GCCP_FLAGS) -c c_wrappers.c

matchptcknobs.o: matchptcknobs.h matchptcknobs.c madx.h

# fortran code dependencies on header files fi
dynap.o: dynap.f90 deltra.fi dyntab.fi wmaxmin0.fi tunes.fi
emit.o: emit.f90 twiss0.fi bb.fi emit.fi twtrr.fi
ibsdb.o: ibsdb.f90 ibsdb.fi name_len.fi physcons.fi
match.o: match.f90 name_len.fi match.fi
matchjc.o: matchjc.f90 name_len.fi match.fi
matchsa.o: matchsa.f90 name_len.fi match.fi
plot.o: plot.f90 plot.fi plot_b.fi plot_c.fi plot_math.fi
resindex.o: resindex.f90 resindex.fi
sodd.o: sodd.f90
survey.o: survey.f90 twtrr.fi
touschek.o: touschek.f90 touschek.fi name_len.fi physcons.fi
trrun.o: trrun.f90 twiss0.fi name_len.fi track.fi bb.fi twtrr.fi
twiss.o: twiss.f90 twiss0.fi twissa.fi twissl.fi twissc.fi twissotm.fi track.fi bb.fi name_len.fi twtrr.fi twiss_elp.fi twiss_map.fi
util.o: util.f90 twiss0.fi twtrr.fi

# f90 dependencies
a_scratch_size.o: a_scratch_size.f90
b_da_arrays_all.o: a_scratch_size.o b_da_arrays_all.f90
ifeq ($(NTPSA),YES)
  c_dabnew_berz.o: b_da_arrays_all.o c_dabnew_berz.f90
  c_tpsa_interface.o: c_dabnew_berz.o c_tpsa_interface.F90
  d_lielib.o: c_tpsa_interface.o d_lielib.f90
  h_definition.o: a_scratch_size.o c_dabnew_berz.o d_lielib.o h_definition.f90 a_def_frame_patch_chart.inc a_def_all_kind.inc a_def_sagan.inc a_def_element_fibre_layout.inc
  tpsa.o: tpsa.cpp tpsa.h
	$(CC) $(GCCP_FLAGS) -c -o tpsa.o tpsa.cpp
  TPSA= tpsa.o
  FILT_TP_OUT= c_dabnew.o
  FILT_TP_OUT_F90=
else
  c_dabnew.o: b_da_arrays_all.o c_dabnew.f90
  d_lielib.o: c_dabnew.o d_lielib.f90
  h_definition.o: a_scratch_size.o c_dabnew.o d_lielib.o h_definition.f90 a_def_frame_patch_chart.inc a_def_all_kind.inc a_def_sagan.inc a_def_element_fibre_layout.inc
  TPSA=
  FILT_TP_OUT= c_dabnew_berz.o
  FILT_TP_OUT_F90= c_tpsa_interface.o
endif
i_tpsa.o: h_definition.o i_tpsa.f90
j_tpsalie.o: i_tpsa.o j_tpsalie.f90
k_tpsalie_analysis.o: j_tpsalie.o k_tpsalie_analysis.f90
l_complex_taylor.o: k_tpsalie_analysis.o l_complex_taylor.f90
m_real_polymorph.o: l_complex_taylor.o m_real_polymorph.f90
n_complex_polymorph.o: m_real_polymorph.o n_complex_polymorph.f90
o_tree_element.o: n_complex_polymorph.o o_tree_element.f90
Sa_extend_poly.o: o_tree_element.o Sa_extend_poly.f90
Sb_sagan_pol_arbitrary.o: Sa_extend_poly.o Sb_sagan_pol_arbitrary.f90
Sc_euclidean.o: Sb_sagan_pol_arbitrary.o Sc_euclidean.f90
Sd_frame.o: Sc_euclidean.o Sd_frame.f90
Se_status.o: Sd_frame.o Se_status.f90 a_def_all_kind.inc a_def_sagan.inc \
	a_def_element_fibre_layout.inc
Sf_def_all_kinds.o: Se_status.o Sf_def_all_kinds.f90 a_def_worm.inc
Sg_sagan_wiggler.o: Sf_def_all_kinds.o Sg_sagan_wiggler.f90
Sh_def_kind.o: Sg_sagan_wiggler.o Sh_def_kind.f90
Si_def_element.o: Sh_def_kind.o Si_def_element.f90
Sk_link_list.o: Si_def_element.o Sk_link_list.f90
Sl_family.o: Sk_link_list.o Sl_family.f90
Sm_tracking.o: Sl_family.o Sm_tracking.f90
Sma0_beam_beam_ptc.o: Sm_tracking.o Sma0_beam_beam_ptc.f90
Sma_multiparticle.o: Sma0_beam_beam_ptc.o Sma_multiparticle.f90
Sn_mad_like.o: Sma_multiparticle.o Sn_mad_like.f90
So_fitting.o: Sn_mad_like.o So_fitting.f90
Sp_keywords.o: So_fitting.o Sp_keywords.f90
Spb_fake_gino_sub.o: Sp_keywords.o Spb_fake_gino_sub.f90
Sq_orbit_ptc.o: Sp_keywords.o Sq_orbit_ptc.f90
Sqb_accel_ptc.o: Sq_orbit_ptc.o Sqb_accel_ptc.f90
Sr_spin.o: Sqb_accel_ptc.o Sr_spin.f90
Sra_fitting.o: Sr_spin.o Sra_fitting.f90
madx_ptc_module.o: Sra_fitting.o madx_ptc_setcavs.o madx_ptc_knobs.o twtrr.fi name_len.fi twiss0.fi madx_ptc_module.f90
St_pointers.o: Sp_keywords.o madx_ptc_module.o St_pointers.f90
madx_ptc_track_run.o: Sp_keywords.o madx_ptc_module.o name_len.fi bb.fi madx_ptc_track_run.f90
madx_ptc_intstate.o: Sp_keywords.o madx_ptc_intstate.f90
madx_ptc_trackcavs.o: Sp_keywords.o madx_ptc_intstate.o  madx_ptc_setcavs.o madx_ptc_module.o name_len.fi madx_ptc_trackcavs.f90
madx_ptc_setcavs.o  : Sp_keywords.o madx_ptc_intstate.o name_len.fi madx_ptc_setcavs.f90
madx_ptc_script.o  : Sp_keywords.o twissa.fi madx_ptc_script.f90
madx_ptc_knobs.o : Sp_keywords.o madx_ptc_intstate.o madx_ptc_knobs.inc twissa.fi madx_ptc_knobs.f90 
madx_ptc_eplacement.o  : Sp_keywords.o madx_ptc_intstate.o madx_ptc_module.o twissa.fi madx_ptc_eplacement.f90
madx_ptc_normal.o: madx_ptc_module.o madx_ptc_normal.f90
madx_ptc_twiss.o: madx_ptc_module.o madx_ptc_setcavs.o madx_ptc_knobs.o madx_ptc_distrib.o madx_ptc_knobs.inc madx_ptc_distrib.inc twissa.fi madx_ptc_twiss.f90
madx_ptc_distrib.o: madx_ptc_module.o madx_ptc_distrib.inc twissa.fi madx_ptc_distrib.f90

wrap.o: madx_ptc_module.o  madx_ptc_intstate.o \
	madx_ptc_normal.o madx_ptc_twiss.o madx_ptc_distrib.o \
	madx_ptc_setcavs.o madx_ptc_trackcavs.o \
	madx_ptc_knobs.o \
	madx_ptc_script.o St_pointers.o \
	wrap.f90
user2_photon.o: madx_ptc_track_run.o user2_photon.f90 photoni.inc
run_madx.o: madx_ptc_module.o run_madx.f90
madx_main.o: run_madx.o madx_main.F90

# implicit rule to compile with C
%.o : %.c
	$(CC) $(GCCP_FLAGS) -c -o $(@) $<

# implicit rule to compile f90 code with f95
%.o : %.f90
	$(f95) $(f95_FLAGS) $<

# implicit rule to compile f90 code with f95
%.o : %.F90
	$(f95) $(f95_FLAGS) $<

# madx_objects  = $(filter-out gxx11psc.o , $(patsubst %.c,%.o,$(wildcard *.c)))
madx_objects = madxp.o gxx11c.o matchptcknobs.o rplot.o fortran_wrappers.o c_wrappers.o $(TPSA)
madx_objects += $(filter-out gxx11ps.o $(FILT_TP_OUT), $(patsubst %.f90,%.o,$(wildcard *.f90)))
madx_objects += $(filter-out $(FILT_TP_OUT_F90),$(patsubst %.F90,%.o,$(wildcard *.F90)))

madx: $(madx_objects)
	$(f95) $(LDOPT) -o madx $(madx_objects) $(LIBX)
	strip madx

clean:
	rm -f *.o
	rm -f *.g90
	rm -f *.mod
	rm -f core
	rm -f *~
	python wrap_fortran_calls.py --clean
	python wrap_C_calls.py --clean

info:
	@echo default C compiler CC "    " = $(CC)
	@echo GCC_FLAGS "                " = $(GCC_FLAGS)
	@echo f95 "                      " = $(f95)
	@echo LIBX "                     " = $(LIBX)
	@echo the OS is "                " = $(OS)
	@echo the OSTYPE is "            " = $(OSTYPE)
	@echo madx_objects "             " = $(madx_objects)
