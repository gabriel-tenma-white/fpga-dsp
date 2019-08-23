#pragma once
#include <complex>
#include <string>
#include <vector>
#include <assert.h>
//#include "arm_neon.h"
//#include <nmmintrin.h>

namespace OwOComm {
	typedef std::complex<float> complexf;
	static inline complexf complex_unpack(uint64_t x) {
		int32_t re = int32_t(x);
		int32_t im = int32_t(x>>32);
		return complexf(re, im);
	}

	// https://gist.github.com/voidqk/fc5a58b7d9fc020ecf7f2f5fc907dfa5
	static inline float fast_atan2(float y, float x){
		static const float c1 = M_PI / 4.0;
		static const float c2 = M_PI * 3.0 / 4.0;
		if (y == 0 && x == 0)
			return 0;
		float abs_y = fabsf(y);
		float angle;
		if (x >= 0)
			angle = c1 - c1 * ((x - abs_y) / (x + abs_y));
		else
			angle = c2 - c1 * ((x + abs_y) / (abs_y - x));
		if (y < 0)
			return -angle;
		return angle;
	}

	template<class SAMPLE>
	struct FMDecoderMultiBase {
		std::vector<std::basic_string<float> > outBuf;
		FMDecoderMultiBase(int channels) {
			outBuf.resize(channels);
		}
		virtual void putSamples(SAMPLE* buf, int len)=0;
	};

	template<class SAMPLE, int channels>
	struct FMDecoderMulti: public FMDecoderMultiBase<SAMPLE> {

		complexf prev[channels] = {};
		float iirF[channels] = {};
		float iirG[channels] = {};
		float iirH[channels] = {};
		uint32_t decimationPhase = 0;
		int decimation = 10;

		FMDecoderMulti(): FMDecoderMultiBase<SAMPLE>(channels) {}

		// processes the buffer and puts results in outBuf.
		// len is the number of aggregates (each aggregate contains all channels)
		void putSamples(SAMPLE* buf, int len) {
			SAMPLE* bufEnd = buf + len * channels;
			float* outPtr[channels];
			for(int ch=0; ch<channels; ch++) {
				FMDecoderMultiBase<SAMPLE>::outBuf[ch].resize(len/decimation);
				outPtr[ch] = &FMDecoderMultiBase<SAMPLE>::outBuf[ch][0];
			}

			// default to outputting the last element in each decimation period
			auto* nextOutput = buf + (decimation - 1)*channels;
			// if we have an offset, output it earlier
			nextOutput -= decimationPhase*channels;

			for(; buf != bufEnd; buf+=channels) {
				#pragma unroll
				for(int ch=0; ch<channels; ch++) {
					auto& prev = this->prev[ch];
					complexf x0 = complex_unpack(buf[ch]);
					float A0 = prev.real() * x0.imag();
					float B0 = prev.imag() * x0.real();
					float mag0 = (x0.real() * x0.real()) + (x0.imag() * x0.imag());
					float out0 = (A0 - B0) / mag0;
					prev = x0;

					// ignore outlier values; significantly reduces noise in low snr tests
					if(out0 < -2 || out0 > 2)
						continue;

					// de-emphasis filter
					float F0 = iirF[ch]*0.95f + out0*0.05f;
					
					// more iir filters
					constexpr float coe = 0.8f;
					constexpr float ccoe = 1.0f - coe;
					float G0 = iirG[ch]*coe + F0*ccoe;
					float H0 = iirH[ch]*coe + G0*ccoe;
					if(!__builtin_isnan(H0)) {
						iirF[ch] = F0;
						iirG[ch] = G0;
						iirH[ch] = H0;
					}
				}
				if(buf == nextOutput) {
					#pragma unroll
					for(int ch=0; ch<channels; ch++) {
						outPtr[ch][0] = iirH[ch];
						outPtr[ch]++;
					}
					nextOutput += decimation * channels;
				}
			}
			decimationPhase = (decimationPhase + len) % decimation;
		}
	};

	template<class SAMPLE>
	struct FMDecoder {
		std::basic_string<float> outBuf;

		/*static constexpr int histMax = 32;
		static constexpr int histMask = 31;
		SAMPLE histArray[32];
		int histIndex = 0;

		// returns sample i cycles ago
		SAMPLE past(int i) {
			i = (histIndex - i) + histMax;
			i = i % histMask;
			return histArray[i];
		}*/
		complexf prev = 0;
		float iirF = 0;
		float iirG = 0;
		float iirH = 0;
		uint32_t decimationPhase = 0;
		int decimation = 10; // must be 4 or greater

		// processes the buffer and puts results in outBuf.
		void putSamples(SAMPLE* buf, int len) {
			SAMPLE* bufEnd = buf + len;
			assert((len % 4) == 0);
			outBuf.resize(len/decimation);
			auto* outPtr = &outBuf[0];
			auto* nextOutputM3 = buf - decimationPhase;

			for(; buf != bufEnd; buf+=4) {
				complexf x0 = complex_unpack(buf[0]);
				complexf x1 = complex_unpack(buf[1]);
				complexf x2 = complex_unpack(buf[2]);
				complexf x3 = complex_unpack(buf[3]);

				float A0 = prev.real() * x0.imag();
				float A1 = x0.real() * x1.imag();
				float A2 = x1.real() * x2.imag();
				float A3 = x2.real() * x3.imag();

				float B0 = prev.imag() * x0.real();
				float B1 = x0.imag() * x1.real();
				float B2 = x1.imag() * x2.real();
				float B3 = x2.imag() * x3.real();

				float mag0 = (x0.real() * x0.real()) + (x0.imag() * x0.imag());
				float mag1 = (x1.real() * x1.real()) + (x1.imag() * x1.imag());
				float mag2 = (x2.real() * x2.real()) + (x2.imag() * x2.imag());
				float mag3 = (x3.real() * x3.real()) + (x3.imag() * x3.imag());
				float out0 = (A0 - B0) / mag0;
				float out1 = (A1 - B1) / mag1;
				float out2 = (A2 - B2) / mag2;
				float out3 = (A3 - B3) / mag3;
				
				// arcsin approximation
				/*out0 += (out0*out0*out0) * .23;
				out1 += (out1*out1*out1) * .23;
				out2 += (out2*out2*out2) * .23;
				out3 += (out3*out3*out3) * .23;*/
				
				// de-emphasis filter
				float F0 = iirF*0.95f + out0*0.05f;
				float F1 = F0*0.95f + out1*0.05f;
				float F2 = F1*0.95f + out2*0.05f;
				float F3 = F2*0.95f + out3*0.05f;
				
				// more iir filters
				constexpr float coe = 0.8f;
				constexpr float ccoe = 1.0f - coe;
				float G0 = iirG*coe + F0*ccoe;
				float G1 = G0*coe + F1*ccoe;
				float G2 = G1*coe + F2*ccoe;
				float G3 = G2*coe + F3*ccoe;
				
				float H0 = iirH*coe + G0*ccoe;
				float H1 = H0*coe + G1*ccoe;
				float H2 = H1*coe + G2*ccoe;
				float H3 = H2*coe + G3*ccoe;
				
				float outArr[4] = {H0, H1, H2, H3};
				
				if(buf >= nextOutputM3) {
					int index = (nextOutputM3 + 3 - buf);
					outPtr[0] = outArr[index];
					outPtr++;
					nextOutputM3 += decimation;
				}
				if(!isnanf(H3)) {
					iirF = F3;
					iirG = G3;
					iirH = H3;
				}
				prev = x3;
			}
			decimationPhase = (decimationPhase + len) % 4;
		}
		/*
		void putSamples8(SAMPLE* buf, int len) {
			SAMPLE* bufEnd = buf + len;
			outBuf.resize(len);
			assert((len % 8) == 0);
			auto* outPtr = &outBuf[0];
			for(; buf != bufEnd; buf+=8, outPtr+=8) {
				complexf x0 = complex_unpack(buf[0]);
				complexf x1 = complex_unpack(buf[1]);
				complexf x2 = complex_unpack(buf[2]);
				complexf x3 = complex_unpack(buf[3]);
				complexf x4 = complex_unpack(buf[4]);
				complexf x5 = complex_unpack(buf[5]);
				complexf x6 = complex_unpack(buf[6]);
				complexf x7 = complex_unpack(buf[7]);

				float A0 = prev.real() * x0.imag();
				float A1 = x0.real() * x1.imag();
				float A2 = x1.real() * x2.imag();
				float A3 = x2.real() * x3.imag();
				float A4 = x3.real() * x4.imag();
				float A5 = x4.real() * x5.imag();
				float A6 = x5.real() * x6.imag();
				float A7 = x6.real() * x7.imag();

				float B0 = prev.imag() * x0.real();
				float B1 = x0.imag() * x1.real();
				float B2 = x1.imag() * x2.real();
				float B3 = x2.imag() * x3.real();
				float B4 = x3.imag() * x4.real();
				float B5 = x4.imag() * x5.real();
				float B6 = x5.imag() * x6.real();
				float B7 = x6.imag() * x7.real();

				float mag0 = (x0.real() * x0.real()) + (x0.imag() * x0.imag());
				float mag1 = (x1.real() * x1.real()) + (x1.imag() * x1.imag());
				float mag2 = (x2.real() * x2.real()) + (x2.imag() * x2.imag());
				float mag3 = (x3.real() * x3.real()) + (x3.imag() * x3.imag());
				float mag4 = (x4.real() * x4.real()) + (x4.imag() * x4.imag());
				float mag5 = (x5.real() * x5.real()) + (x5.imag() * x5.imag());
				float mag6 = (x6.real() * x6.real()) + (x6.imag() * x6.imag());
				float mag7 = (x7.real() * x7.real()) + (x7.imag() * x7.imag());
				float out0 = (A0 - B0) / mag0;
				float out1 = (A1 - B1) / mag1;
				float out2 = (A2 - B2) / mag2;
				float out3 = (A3 - B3) / mag3;
				float out4 = (A4 - B4) / mag4;
				float out5 = (A5 - B5) / mag5;
				float out6 = (A6 - B6) / mag6;
				float out7 = (A7 - B7) / mag7;
				
				// de-emphasis filter
				float filt0 = iirF*0.95f + out0*0.05f;
				float filt1 = filt0*0.95f + out1*0.05f;
				float filt2 = filt1*0.95f + out2*0.05f;
				float filt3 = filt2*0.95f + out3*0.05f;
				float filt4 = filt3*0.95f + out4*0.05f;
				float filt5 = filt4*0.95f + out5*0.05f;
				float filt6 = filt5*0.95f + out6*0.05f;
				float filt7 = filt6*0.95f + out7*0.05f;
				outPtr[0] = filt0;
				outPtr[1] = filt1;
				outPtr[2] = filt2;
				outPtr[3] = filt3;
				outPtr[4] = filt4;
				outPtr[5] = filt5;
				outPtr[6] = filt6;
				outPtr[7] = filt7;

				iirF = filt7;
				prev = x7;
			}
		}
		*/
		/*void putSamplesV(SAMPLE* buf, int len) {
			SAMPLE* bufEnd = buf + len;
			outBuf.resize(len);
			assert((len % 4) == 0);
			auto* outPtr = &outBuf[0];
			for(; buf != bufEnd; buf+=4, outPtr+=4) {
				complexf x0 = complex_unpack(buf[0]);
				complexf x1 = complex_unpack(buf[1]);
				complexf x2 = complex_unpack(buf[2]);
				complexf x3 = complex_unpack(buf[3]);

				float32x4_t A = {prev.real(), x0.real(), x1.real(), x2.real()};
				float32x4_t imags = {x0.imag(), x1.imag(), x2.imag(), x3.imag()};
				A *= imags;
				
				float32x4_t B = {prev.imag(), x0.imag(), x1.imag(), x2.imag()};
				float32x4_t reals = {x0.real(), x1.real(), x2.real(), x3.real()};
				B *= reals;
				
				float32x4_t mags = reals*reals + imags*imags;
				float32x4_t out = (A - B) / mags;
				float out0 = out[0];
				float out1 = out[1];
				float out2 = out[2];
				float out3 = out[3];
				
				// de-emphasis filter
				float filt0 = prevOut*0.95f + out0*0.05f;
				float filt1 = filt0*0.95f + out1*0.05f;
				float filt2 = filt1*0.95f + out2*0.05f;
				float filt3 = filt2*0.95f + out3*0.05f;
				outPtr[0] = filt0;
				outPtr[1] = filt1;
				outPtr[2] = filt2;
				outPtr[3] = filt3;

				prevOut = filt3;
				prev = x3;
			}
		}*/
		/*
		void putSamplesOld(SAMPLE* buf, int len) {
			SAMPLE* bufEnd = buf + len;
			outBuf.resize(len);
			auto* outPtr = &outBuf[0];
			for(; buf != bufEnd; buf++, outPtr++) {
				complexf x = complex_unpack(*buf);
				
				// add sample to history
				//histArray[histIndex] = x;
				//histIndex = (histIndex+1) & histMask;
				
				
				
				float M1 = prev.real() * x.imag();
				float M2 = prev.imag() * x.real();
				float mag = (x.real() * x.real()) + (x.imag() * x.imag());
				float tmp = (M1 - M2) / mag;
				float argOut = tmp;
				
				// de-emphasis filter
				iirF = iirF*0.95 + argOut*0.05;
				*outPtr = iirF;
				
				prev = x;
			}
		}*/
	};
}
