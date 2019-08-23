#pragma once
#include <complex>
#include <stdexcept>
#include <fftw3.h>
#include <assert.h>
#include <string.h>

// convolution using fftw

namespace OwOComm {
	static inline void fftw_execute(const fftwf_plan& p) {
		::fftwf_execute(p);
	}
	static inline void fftw_execute(const fftw_plan& p) {
		::fftw_execute(p);
	}
	static inline void fftw_destroy_plan(const fftwf_plan& p) {
		::fftwf_destroy_plan(p);
	}
	static inline void fftw_destroy_plan(const fftw_plan& p) {
		::fftw_destroy_plan(p);
	}

	template<class FLOATTYPE>
	struct convolve {
		typedef std::complex<FLOATTYPE> COMPLEXTYPE;
		typedef fftwf_complex FFTW_COMPLEX;
		typedef fftwf_plan FFTW_PLAN;
		
		FLOATTYPE* buffer;
		COMPLEXTYPE* filt;
		COMPLEXTYPE* tmp1;
		FLOATTYPE* tmp2;
		int os,bs;
		FFTW_PLAN p1,p2;

		template<class T> T* allocate(int len) {
			void* tmp = fftw_malloc(len * sizeof(T));
			if(tmp == nullptr)
				throw std::bad_alloc();
			return (T*) tmp;
		}
		// overlapSize is the length of the FIR impulse response;
		// bufSize is the max length of each buffer passed to process()
		void init(int overlapSize, int bufSize) {
			assert(sizeof(FFTW_COMPLEX) == sizeof(COMPLEXTYPE));
			os = overlapSize;
			bs = bufSize;
			buffer = allocate<FLOATTYPE>(os+bs);
			filt = allocate<COMPLEXTYPE>((os+bs)/2+1);
			tmp1 = allocate<COMPLEXTYPE>((os+bs)/2+1);
			tmp2 = allocate<FLOATTYPE>(os+bs);
			p1 = fftwf_plan_dft_r2c_1d(os+bs, buffer, (FFTW_COMPLEX*) tmp1, FFTW_PRESERVE_INPUT | FFTW_ESTIMATE);
			p2 = fftwf_plan_dft_c2r_1d(os+bs, (FFTW_COMPLEX*) tmp1, tmp2, FFTW_ESTIMATE);
		}
		void deinit() {
			jackfft_free(buffer);
			jackfft_free(filt);
			jackfft_free(tmp1);
			jackfft_free(tmp2);
		}
		static inline void mult(COMPLEXTYPE& c1, COMPLEXTYPE& c2, FLOATTYPE r) {
			FLOATTYPE r1 = c1.real() / r;
			FLOATTYPE i1 = c1.imag() / r;
			c1 = {r1*c2.real() - i1*c2.imag(),
					r1*c2.imag() + i1*c2.real()};
		}
		template<class F>
		FLOATTYPE* process(F* data, int sz) {
			memmove(buffer, buffer+sz, (os+bs-sz)*sizeof(FLOATTYPE));
			FLOATTYPE* buffer1 = buffer+os+bs-sz;
			for(int i=0; i<sz; i++)
				buffer1[i] = FLOATTYPE(data[i]);
			fftw_execute(p1);
			for(int i=0; i<(os+bs)/2+1; i++) {
				mult(tmp1[i], filt[i], os+bs);
			}
			fftw_execute(p2);
			return tmp2+os+bs-sz;
		}
		template<class F>
		void setWaveform(const F* data) {
			FLOATTYPE* tmpbuf = allocate<FLOATTYPE>(os+bs);
			FFTW_PLAN tmpp1 = fftwf_plan_dft_r2c_1d(os+bs, tmpbuf, (FFTW_COMPLEX*) filt, FFTW_ESTIMATE);
			for(int i=0; i<os; i++)
				tmpbuf[i] = FLOATTYPE(data[i]);
			for(int i=os; i<bs+os; i++)
				tmpbuf[i] = 0;
			//tmpbuf[0]=1;
			//tmpbuf[1]=1;
			fftw_execute(tmpp1);
			fftw_destroy_plan(tmpp1);
			fftw_free(tmpbuf);
			//for(int i=0;i<(os+bs)/2+1;i++) if(filt[i][1]!=0) printf("%i %lf\n",i,filt[i][1]);
		}
	};
}
