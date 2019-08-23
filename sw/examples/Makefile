
CXX := clang++-7
AXI_UTIL_PATH ?= ../../../axi-util/sw
FPGA_FFT_PATH ?= ../../../fpga-fft/sw
CFLAGS ?= -O2

INCLUDES ?= -I$(AXI_UTIL_PATH)/include -I$(FPGA_FFT_PATH)/include -I../include
LIBS ?= -lfftw3 -lfftw3f

REQUIRED_CXXFLAGS := --std=c++0x -finput-charset=UTF-8 -fextended-identifiers

CXXFLAGS2 := $(REQUIRED_CXXFLAGS) $(INCLUDES) $(CFLAGS)

all: fm_decoder_test axi_channelizer_test

%.o: %.C
	$(CXX) -c $(CXXFLAGS2) $< -o $@

$(FPGA_FFT_PATH)/libaxi_fft.a: FORCE
	$(MAKE) -C $(FPGA_FFT_PATH) libaxi_fft.a

$(AXI_UTIL_PATH)/libaxi_pipe.a: FORCE
	$(MAKE) -C $(AXI_UTIL_PATH) libaxi_pipe.a

FORCE:

fm_decoder_test: fm_decoder_test.o
	$(CXX) $(LIBS) $^ -o $@

axi_channelizer_test: axi_channelizer_test.o $(AXI_UTIL_PATH)/libaxi_pipe.a
	$(CXX) $(LIBS) $^ -o $@

clean:
	rm -f fm_decoder_test axi_channelizer_test *.o
