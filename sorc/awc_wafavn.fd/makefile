# makefile for waf programs
#
FC = ifort
FFLAGS = -g -O2 -convert big_endian -assume noold_ldout_format
MKDEP = sfmakedepend.pl
DEPFILE = makedepend.out

.SUFFIXES:
%.o : %.f90
	$(FC) $(FFLAGS) -c $<

%.o : %.f
	ifort $(FFLAGS) -c $<

#------------------------------------------------------------------------------

OBJS = waf_main.o \
	waf_calc.o \
	waf_cat.o \
	waf_cb.o \
	waf_config.o \
	waf_filter.o \
	waf_glob.o \
	waf_icng.o \
	waf_phys.o \
	waf_tcld.o \
	cfgini.o \
	funcphys.o \
	fuzzy.o \
	getoptions.o \
	kinds.o \
	physcons.o \
	tokenize.o

PROG = awc_wafavn

LIBS = -L . -L /nwprod/lib -lbacio_4 -lip_4 -lsp_4 -mkl -lw3nco_4 -lw3emc_4
#SRC_ALL = $(patsubst %.o,%.f90, $(OBJS))
SRC_ALL = waf_main.f90 \
        waf_calc.f90 \
        waf_cat.f90 \
        waf_cb.f90 \
        waf_config.f90 \
        waf_filter.f90 \
        waf_glob.f90 \
        waf_icng.f90 \
        waf_phys.f90 \
        waf_tcld.f90 \
        cfgini.f90 \
        funcphys.f90 \
        fuzzy.f90 \
        getoptions.f90 \
        kinds.f90 \
        physcons.f90 \
        tokenize.f90
#------------------------------------------------------------------------------
all:	$(PROG)

$(PROG):	$(OBJS)
	$(FC) $(FFLAGS) -o $@ $(OBJS) $(LIBS)

depend:
	rm -f $(DEPFILE)
	$(MKDEP) -f $(DEPFILE) $(SRC_ALL)

clean:
	rm -f *.o *.mod

#-----------------------------------------------------------------------------
# dependency file
-include $(DEPFILE)
