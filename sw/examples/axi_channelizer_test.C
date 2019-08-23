#include <owocomm/axi_pipe.H>
#include <owocomm/buffer_pool.H>
#include <owocomm/fm_decoder.H>
#include <owocomm/convolve.H>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdexcept>
#include <complex>
#include <vector>
#include <algorithm>

using namespace std;
using namespace OwOComm;


typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint8_t u8;
typedef uint64_t u64;



static const long reservedMemAddr = 0x20000000;
static const long reservedMemSize = 0x10000000;
volatile uint8_t* reservedMem = NULL;
volatile uint8_t* reservedMemEnd = NULL;

static const long channelsArrayAddr = 0x43C40000;
volatile uint32_t* channelsArray = NULL;

// the number of elements in each burst
static const int burstLength = 4;

// buffer size in bytes
static const int sz = 1024*1024;

// number of aggregates in each frame
static const int frameElements = 8192;

AXIPipe* axiPipe;
MultiBufferPool bufPool;

int mapReservedMem() {
	int memfd;
	if((memfd = open("/dev/mem", O_RDWR | O_SYNC)) < 0) {
		perror("open");
		printf( "ERROR: could not open /dev/mem\n" );
		return -1;
	}
	channelsArray = (volatile uint32_t*) mmap(NULL, 4096, ( PROT_READ | PROT_WRITE ), MAP_SHARED, memfd, channelsArrayAddr);
	if(channelsArray == NULL) {
		close(memfd);
		throw runtime_error(string("ERROR: could not map channelizer array: ") + strerror(errno));
	}
	reservedMem = (volatile uint8_t*) mmap(NULL, reservedMemSize, ( PROT_READ | PROT_WRITE ), MAP_SHARED, memfd, reservedMemAddr);
	if(reservedMem == NULL) {
		perror("mmap");
		printf( "ERROR: could not map reservedMem\n" );
		return -1;
	}
	reservedMemEnd = reservedMem + reservedMemSize;
	close(memfd);
	return 0;
}

static inline uint64_t timespec_to_ns(const struct timespec *tv)
{
	return (uint64_t(tv->tv_sec) * 1000000000)
		+ (uint64_t)tv->tv_nsec;
}
int64_t operator-(const timespec& t1, const timespec& t2) {
	return int64_t(timespec_to_ns(&t1)-timespec_to_ns(&t2));
}


int myLog2(int n) {
	int res = (int)ceil(log2(n));
	assert(int(pow(2, res)) == n);
	return res;
}

volatile uint64_t* buf(int i) {
	return (volatile uint64_t*)(reservedMem + sz*i);
}



class AXIPipeRecv {
public:
	// user parameters
	AXIPipe* axiPipe = nullptr;
	MultiBufferPool* bufPool = nullptr;
	uint32_t hwFlags = AXIPIPE_FLAG_INTERRUPT;
	int bufSize = 0;
	int nTargetPending = 8;

	// this callback is called for every completed buffer;
	// if the function returns false we don't free the buffer.
	function<bool(volatile uint8_t*)> cb;

	// internal state
	int nPending = 0;
	void start() {
		while(nPending < nTargetPending) {
			nPending++;
			volatile uint8_t* buf = bufPool->get(bufSize);
			uint32_t marker = axiPipe->submitWrite(buf, bufSize, hwFlags);
			//printf("submit write; acceptance %d\n", axiPipe->write🅱ufferAcceptance());
			axiPipe->waitWriteAsync(marker, [this, buf]() {
				//printf("write complete\n");
				if(cb(buf))
					bufPool->put(buf);
				nPending--;
				start();
			});
		}
	}
};

uint32_t bytesWritten = 0;
void test1() {
	bytesWritten = axiPipe->regs[AXIPIPE_REG_BYTESWRITTEN];

	AXIPipeRecv pipeRecv;
	pipeRecv.axiPipe = axiPipe;
	pipeRecv.bufPool = &bufPool;
	pipeRecv.bufSize = sz;
	pipeRecv.cb = [](volatile uint8_t* buf) {
		uint32_t bw = axiPipe->regs[AXIPIPE_REG_BYTESWRITTEN];
		uint32_t tmp = bw - bytesWritten;
		bytesWritten = bw;
		fprintf(stderr, "got %d bytes\n", tmp);
		write(1, (void*) buf, sz);
		return true;
	};
	pipeRecv.start();
	while(true) {
		if(waitForIrq(axiPipe->irqfd) < 0) {
			perror("wait for irq");
			return;
		}
		axiPipe->dispatchInterrupt();
	}
}

// bit-reversals; ripped off of stackoverflow
uint8_t reverse8(uint8_t n) {
	static constexpr unsigned char lookup[16] = {
		0x0, 0x8, 0x4, 0xc, 0x2, 0xa, 0x6, 0xe,
		0x1, 0x9, 0x5, 0xd, 0x3, 0xb, 0x7, 0xf, };
	// Reverse the top and bottom nibble then swap them.
	return (lookup[n&0b1111] << 4) | lookup[n>>4];
}
uint16_t reverse16(uint16_t n) {
	return (reverse8((uint8_t)n) << 8) | reverse8(n>>8);
}
uint32_t reverse32(uint32_t n) {
	return (reverse16((uint16_t)n) << 16) | reverse16(n>>16);
}

void setChannels(vector<int>& ch) {
	int nChannels = ch.size();
	assert(nChannels * frameElements < (sz/8));
	// sort small to large by bit-reversed value
	int nBits = 10;
	sort(ch.begin(), ch.end(), [&](int a, int b) {
		a = reverse16(a << (16-nBits));
		b = reverse16(b << (16-nBits));
		return a < b;
	});
	fprintf(stderr, "channel list: ");
	for(int i=0; i<nChannels; i++)
		fprintf(stderr, "%d ", ch.at(i));
	fprintf(stderr, "\n");
	
	for(int i=0; i<nChannels; i++)
		channelsArray[i] = ch.at(i);

	// set the tlast bit on the last channel
	channelsArray[nChannels - 1] = ch.at(nChannels - 1) | (1 << nBits);
	channelsArray[nChannels] = 0;
}


// fm demodulator

typedef uint64_t SAMPTYPE;
static constexpr int firLength = 128;
static constexpr int bufLength = 1024 - firLength;
extern const double filter_taps[firLength];

struct FMReceiver {
	static const int decimation = 2;
	FMDecoder<SAMPTYPE> fmDec;
	convolve<float> conv;
	int bufLength = 0;
	uint32_t totalSamples = 0;
	bool useFIR = false;

	void init(int bufLength, int firLength, const double* filterTaps) {
		this->bufLength = bufLength;
		conv.init(firLength, bufLength);
		fprintf(stderr, "fftw init done\n");
		conv.setWaveform(filterTaps);
	}

	// buf must be at most bufLength samples, and outBuf array must be at least
	// bufLength/decimation samples. returns number of samples output.
	int process(SAMPTYPE* buf, int16_t* outBuf, int length) {
		// demodulate fm
		fmDec.putSamples(buf, length);

		// apply fir filter
		int l = fmDec.outBuf.length();
		float* res = &fmDec.outBuf[0];
		if(useFIR)
			res = conv.process(&fmDec.outBuf[0], l);

		// decimate and output
		int offs = (decimation - (totalSamples % decimation)) % decimation;
		auto* inPtr = res + offs;
		auto* inPtrEnd = res + l;
		int16_t* outPtr = outBuf;
		for(; inPtr < inPtrEnd; inPtr += decimation) {
			float tmp = (*inPtr)*20000;
			if(tmp > 32767) tmp = 32767;
			if(tmp < -32767) tmp = -32767;
			*outPtr = (int16_t) tmp;
			outPtr++;
		}
		totalSamples += l;
		return (outPtr - outBuf);
	}
};

template<class SAMPLE>
FMDecoderMultiBase<SAMPLE>* createFMDecoderMulti(int nChannels) {
	switch(nChannels) {
		case 1: return new FMDecoderMulti<SAMPLE, 1>();
		case 2: return new FMDecoderMulti<SAMPLE, 2>();
		case 3: return new FMDecoderMulti<SAMPLE, 3>();
		case 4: return new FMDecoderMulti<SAMPLE, 4>();
		case 5: return new FMDecoderMulti<SAMPLE, 5>();
		case 6: return new FMDecoderMulti<SAMPLE, 6>();
		case 7: return new FMDecoderMulti<SAMPLE, 7>();
		case 8: return new FMDecoderMulti<SAMPLE, 8>();
		default: throw logic_error("no FMDecoderMulti for channel count: " + to_string(nChannels));
	}
}

void test2(const vector<int>& ch) {
	int nChannels = ch.size();
	int bytesExpected = ch.size() * frameElements * 8;

	fprintf(stderr, "size of each frame: %d bytes\n", bytesExpected);

	bytesWritten = axiPipe->regs[AXIPIPE_REG_BYTESWRITTEN];

	AXIPipeRecv pipeRecv;
	pipeRecv.axiPipe = axiPipe;
	pipeRecv.bufPool = &bufPool;
	pipeRecv.bufSize = sz;

	//FMReceiver fmr;
	//int outBufLen = bufLength*4;
	//int16_t outBuf[outBufLen];
	//fmr.init(bufLength, firLength, filter_taps);

	auto* fmDec = createFMDecoderMulti<SAMPTYPE>(nChannels);
	uint32_t totalSamples = 0;

	pipeRecv.cb = [&](volatile uint8_t* buf) {
		uint32_t bw = axiPipe->regs[AXIPIPE_REG_BYTESWRITTEN];
		uint32_t tmp = bw - bytesWritten;
		bytesWritten = bw;
		fprintf(stderr, "got %d bytes\n", tmp);

		uint64_t* samples = (uint64_t*) buf;
		int nSamples = frameElements;

		fmDec->putSamples(samples, nSamples);

		for(int c=0; c<nChannels; c++) {
			int l = fmDec->outBuf.at(c).length();
			float* res = &fmDec->outBuf.at(c)[0];
			int16_t outBuf[l];
			for(int i=0; i<l; i++) {
				float tmp = res[i]*20000;
				if(tmp > 32767) tmp = 32767;
				if(tmp < -32767) tmp = -32767;
				outBuf[i] = (int16_t) tmp;
			}
			write(100 + c, outBuf, l*sizeof(int16_t));
		}
		return true;
	};
	pipeRecv.start();
	while(true) {
		if(waitForIrq(axiPipe->irqfd) < 0) {
			perror("wait for irq");
			return;
		}
		axiPipe->dispatchInterrupt();
	}
}




int main(int argc, char** argv) {
	if(argc < 2) {
		fprintf(stderr, "usage: %s channel0 [channel1...]\n", argv[0]);
		return 1;
	}
	if(mapReservedMem() < 0) {
		return 1;
	}
	axiPipe = new OwOComm::AXIPipe(0x43C30000, "/dev/uio3");
	axiPipe->reservedMem = reservedMem;
	axiPipe->reservedMemEnd = reservedMemEnd;
	axiPipe->reservedMemAddr = reservedMemAddr;

	bufPool.init(reservedMem, reservedMemSize);
	bufPool.addPool(sz, 20);

	int nChannels = argc - 1;
	vector<int> ch(nChannels, 0);
	for(int i=0; i<nChannels; i++) {
		ch.at(i) = atoi(argv[i + 1]);
	}
	setChannels(ch);

	test2(ch);
	
	return 0;
}













/*

FIR filter designed with
http://t-filter.appspot.com

sampling frequency: 320000 Hz

* 0 Hz - 13000 Hz
  gain = 1
  desired ripple = 0.4 dB
  actual ripple = 0.3806386332428803 dB

* 18000 Hz - 160000 Hz
  gain = 0
  desired attenuation = -50 dB
  actual attenuation = -47.84072245140471 dB

*/


const double filter_taps[firLength] = {
  -0.00028185415483487935,
  -0.0028833484484290807,
  -0.0015150468243349416,
  -0.002012333199126038,
  -0.002233886636270149,
  -0.002359588512620966,
  -0.002335026524412514,
  -0.0021433418380115993,
  -0.0017723565612100237,
  -0.001235563695702269,
  -0.0005505188841624926,
  0.0002331247591525449,
  0.0010635571877093478,
  0.001870765346846531,
  0.002577179750627487,
  0.0031117548213575033,
  0.0034071584495971446,
  0.0034072385660940184,
  0.0030861240423279337,
  0.0024397667737905727,
  0.0014932457873353272,
  0.0003050045739950766,
  -0.0010362348999757532,
  -0.002419840337628585,
  -0.003721107153418528,
  -0.004809100975247718,
  -0.005556200278199705,
  -0.005857100106817205,
  -0.005637745111753706,
  -0.004864307109836954,
  -0.0035513770755946374,
  -0.0017647241615606699,
  0.00037884074194201263,
  0.0027149006871115414,
  0.00504502515714739,
  0.007151026943354539,
  0.008812357752283506,
  0.00982483226508616,
  0.01002109159679512,
  0.009290082711841775,
  0.007592219746153424,
  0.0049700164680046,
  0.0015552252746707446,
  -0.0024347646034875406,
  -0.006706705877029423,
  -0.010906515717399161,
  -0.014641125731774065,
  -0.017505536347250137,
  -0.019112448876661567,
  -0.019123459294539832,
  -0.017277234042688275,
  -0.013414472063429106,
  -0.007496804003217301,
  0.00038208954184499797,
  0.009994749695212158,
  0.020988455752334555,
  0.0329021893586017,
  0.045190546950760344,
  0.0572565968153717,
  0.0684895349808587,
  0.07830307669957391,
  0.08617332243439708,
  0.09167331828315775,
  0.09450134155336554,
  0.09450134155336554,
  0.09167331828315775,
  0.08617332243439708,
  0.07830307669957391,
  0.0684895349808587,
  0.0572565968153717,
  0.045190546950760344,
  0.0329021893586017,
  0.020988455752334555,
  0.009994749695212158,
  0.00038208954184499797,
  -0.007496804003217301,
  -0.013414472063429106,
  -0.017277234042688275,
  -0.019123459294539832,
  -0.019112448876661567,
  -0.017505536347250137,
  -0.014641125731774065,
  -0.010906515717399161,
  -0.006706705877029423,
  -0.0024347646034875406,
  0.0015552252746707446,
  0.0049700164680046,
  0.007592219746153424,
  0.009290082711841775,
  0.01002109159679512,
  0.00982483226508616,
  0.008812357752283506,
  0.007151026943354539,
  0.00504502515714739,
  0.0027149006871115414,
  0.00037884074194201263,
  -0.0017647241615606699,
  -0.0035513770755946374,
  -0.004864307109836954,
  -0.005637745111753706,
  -0.005857100106817205,
  -0.005556200278199705,
  -0.004809100975247718,
  -0.003721107153418528,
  -0.002419840337628585,
  -0.0010362348999757532,
  0.0003050045739950766,
  0.0014932457873353272,
  0.0024397667737905727,
  0.0030861240423279337,
  0.0034072385660940184,
  0.0034071584495971446,
  0.0031117548213575033,
  0.002577179750627487,
  0.001870765346846531,
  0.0010635571877093478,
  0.0002331247591525449,
  -0.0005505188841624926,
  -0.001235563695702269,
  -0.0017723565612100237,
  -0.0021433418380115993,
  -0.002335026524412514,
  -0.002359588512620966,
  -0.002233886636270149,
  -0.002012333199126038,
  -0.0015150468243349416,
  -0.0028833484484290807,
  -0.00028185415483487935
};




