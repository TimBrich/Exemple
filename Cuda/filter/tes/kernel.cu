// test version 1 for 5 lab

#include <iostream> 
#include <cuda_runtime.h> 
#include <stdio.h>
#include <time.h>
#include <ctime>
#include <fstream>

using namespace std;

struct BitmapPGM
{
	char type[3];
	char coment[18] = "# Created by Tim\n";
	int max_size;
	int size_x;
	int size_y;
	unsigned char *bitmap;

	int chanel;

	BitmapPGM() {}
	BitmapPGM(BitmapPGM *clone, unsigned char *bmp)
	{
		strcpy(type, clone->type);
		max_size = clone->max_size;
		size_x = clone->size_x;
		size_y = clone->size_y;
		chanel = clone->chanel;
		bitmap = bmp;

	}
};

struct RGBBmp
{
	BitmapPGM r;
	BitmapPGM g;
	BitmapPGM b;
};
struct RGBCC
{
	unsigned char r;
	unsigned char g;
	unsigned char b;
};
void openPGM(const char* file, BitmapPGM *bmp) {
	FILE *fp = NULL;
	fopen_s(&fp, file, "rb");

	const unsigned int PGMHeaderSize = 255;
	char header[PGMHeaderSize];

	fgets(header, PGMHeaderSize, fp);

	if (header[0] == 'P' && header[1] == '5')
	{
		bmp->type[0] = 'P';
		bmp->type[1] = '5';
		bmp->type[2] = '\n';
		bmp->chanel = 1;
	}
	else
	{
		bmp->type[0] = 'P';
		bmp->type[1] = '6';
		bmp->type[2] = '\n';
		bmp->chanel = 3;
	}

	for (int i = 0; i < 3;)
	{
		fgets(header, PGMHeaderSize, fp);
		if (header[0] == '#') continue;
		if (header[0] == '\n') continue;
		if (i == 0) i += sscanf_s(header, "%u %u %u", &bmp->size_x, &bmp->size_y, &bmp->max_size);
		else if (i == 1) i += sscanf_s(header, "%u %u", &bmp->size_x, &bmp->size_y);
		else if (i == 2) i += sscanf_s(header, "%u", &bmp->max_size);
	}

	bmp->bitmap = (unsigned char *)malloc(sizeof(unsigned char) * bmp->size_x * bmp->size_y * bmp->chanel);
	fread(bmp->bitmap, sizeof(unsigned char), bmp->size_x * bmp->size_y * bmp->chanel, fp);

	fclose(fp);
}
bool savePGM(const char *file, BitmapPGM bmp) {

	std::fstream fh(file, std::fstream::out | std::fstream::binary);

	fh << bmp.type;
	fh << bmp.coment;


	fh << bmp.size_x << '\n' << bmp.size_y << "\n" << bmp.max_size << std::endl;

	for (unsigned int i = 0; (i < (bmp.size_x * bmp.size_y * bmp.chanel)) && fh.good(); ++i)
	{
		fh << bmp.bitmap[i];
	}

	fh.flush();

	if (fh.bad())
	{
		cout << "Writing data failed." << endl;
		return false;
	}

	fh.close();

	return true;
}
BitmapPGM filterCPU(BitmapPGM i_bmp)
{
	unsigned char *res = (unsigned char *)malloc(sizeof(unsigned char) * i_bmp.size_x * i_bmp.size_y);
	const unsigned long long start = clock();
	for (int y = 0; y < i_bmp.size_y; y++)
	{
		for (int x = 0; x < i_bmp.size_x; x++)
		{
			int pos = x + y * i_bmp.size_x;
			int sum = 0;
			for (int i = -1; i < 2; i++)
			{
				for (int j = -1; j < 2; j++)
				{
					if (i == 0 && j == 0)
					{
						sum += i_bmp.bitmap[pos] * (-8);
					}
					else if (x + j >= 0 && x + j < i_bmp.size_x && y + i >= 0 && y + i < i_bmp.size_y)
					{
						sum += i_bmp.bitmap[j + x + (y + i) * i_bmp.size_x];
					}
				}
			}
			if (sum >= 0 && sum <= 255) res[pos] = sum;
			else if (sum < 0) res[pos] = 0;
			else res[pos] = 255;
		}
	}

	const unsigned long long end = clock();
	cout << "CPU filter work: " << ((end - start) / (double)CLOCKS_PER_SEC) << " sec" << endl;

	return BitmapPGM(&i_bmp, res);
}
void checkCUDAStatus(cudaError_t cudaStatus) {
	if (cudaStatus != cudaSuccess) {
		printf("CUDA return error code: %d\n", cudaStatus);
		system("pause");
		exit(-1);
	}
}

RGBBmp raspilRGB(BitmapPGM bmp)
{
	RGBBmp cBmp;
	unsigned char *R = (unsigned char *)malloc(sizeof(unsigned char) * bmp.size_x * bmp.size_y);
	unsigned char *G = (unsigned char *)malloc(sizeof(unsigned char) * bmp.size_x * bmp.size_y);
	unsigned char *B = (unsigned char *)malloc(sizeof(unsigned char) * bmp.size_x * bmp.size_y);

	for (int i = 0; i < bmp.size_x * bmp.size_y; i++)
	{
		R[i] = bmp.bitmap[i * 3];
		G[i] = bmp.bitmap[i * 3 + 1];
		B[i] = bmp.bitmap[i * 3 + 2];
	}

	cBmp.r = BitmapPGM(&bmp, R);
	cBmp.g = BitmapPGM(&bmp, G);
	cBmp.b = BitmapPGM(&bmp, B);

	cBmp.r.chanel = 1;
	cBmp.g.chanel = 1;
	cBmp.b.chanel = 1;

	return cBmp;
}

BitmapPGM mergingRGB(RGBBmp cBmp)
{
	unsigned char *arr = (unsigned char *)malloc(sizeof(unsigned char) * cBmp.r.size_x * cBmp.r.size_y * 3);

	for (int i = 0; i < cBmp.r.size_x * cBmp.r.size_y; i++)
	{
		arr[i * 3] = cBmp.r.bitmap[i];
		arr[i * 3 + 1] = cBmp.g.bitmap[i];
		arr[i * 3 + 2] = cBmp.b.bitmap[i];
	}

	BitmapPGM bmp(&cBmp.r, arr);
	bmp.chanel = 3;
	return bmp;
}

// threadds = x1024 y0 block = x: w / 1024 + 1 y: 4

__global__ void filterGPU4(const int h, const int w, const RGBCC *in, RGBCC *out, int res_pitch, int out_pitch)
{
	int idx = threadIdx.x + blockIdx.x * blockDim.x + 1;
	int idy = threadIdx.y + blockIdx.y * blockDim.y + 1;

	//if (idx == w - 1 && idy < h) out[idy * out_pitch + w - 1] = 255;

	int idx2 = idx - 1;

	if (blockIdx.y == 0)
	{
		if (idx2 == 0)
		{
			int sum = in[0].r * (-8) + in[1].r + in[0 + res_pitch].r + in[1 + res_pitch].r;
			int sum1 = in[0].g * (-8) + in[1].g + in[0 + res_pitch].g + in[1 + res_pitch].g;
			int sum2 = in[0].b * (-8) + in[1].b + in[0 + res_pitch].b + in[1 + res_pitch].b;

			//printf("\n0 0: %d + %d + %d + %d = %d", in[0] * (-8), in[1], in[0 + res_pitch], in[1 + res_pitch], sum);

			if ((sum) >= 0 && (sum) <= 255) out[0].r = (unsigned char)(sum);
			else if ((sum) < 0) out[0].r = (unsigned char)0;
			else if ((sum) > 255) out[0].r = (unsigned char)255;

			if ((sum) >= 0 && (sum) <= 255) out[0].g = (unsigned char)(sum1);
			else if ((sum) < 0) out[0].g = (unsigned char)0;
			else if ((sum) > 255) out[0].g = (unsigned char)255;
			
			if ((sum) >= 0 && (sum) <= 255) out[0].b = (unsigned char)(sum2);
			else if ((sum) < 0) out[0].b = (unsigned char)0;
			else if ((sum) > 255) out[0].b = (unsigned char)255;

		}
		else if (idx2 == w - 1)
		{
			int sum = in[w - 1].r * (-8) + in[w - 2].r + in[w - 2 + res_pitch].r + in[w - 1 + res_pitch].r;
			//printf("\n0 w: %d + %d + %d + %d = %d\n", in[w - 1] * (-8), in[w - 2], in[w - 2 + res_pitch], in[w - 1 + res_pitch], sum);
			if ((sum) >= 0 && (sum) <= 255) out[w - 1].r = (unsigned char)(sum);
			else if ((sum) < 0) out[w - 1].r = (unsigned char)0;
			else if ((sum) > 255) out[w - 1].r = (unsigned char)255;

			sum = in[w - 1].g * (-8) + in[w - 2].g + in[w - 2 + res_pitch].g + in[w - 1 + res_pitch].g;
			//printf("\n0 w: %d + %d + %d + %d = %d\n", in[w - 1] * (-8), in[w - 2], in[w - 2 + res_pitch], in[w - 1 + res_pitch], sum);
			if ((sum) >= 0 && (sum) <= 255) out[w - 1].g = (unsigned char)(sum);
			else if ((sum) < 0) out[w - 1].g = (unsigned char)0;
			else if ((sum) > 255) out[w - 1].g = (unsigned char)255;

			sum = in[w - 1].b * (-8) + in[w - 2].b + in[w - 2 + res_pitch].b + in[w - 1 + res_pitch].b;
			//printf("\n0 w: %d + %d + %d + %d = %d\n", in[w - 1] * (-8), in[w - 2], in[w - 2 + res_pitch], in[w - 1 + res_pitch], sum);
			if ((sum) >= 0 && (sum) <= 255) out[w - 1].b = (unsigned char)(sum);
			else if ((sum) < 0) out[w - 1].b = (unsigned char)0;
			else if ((sum) > 255) out[w - 1].b = (unsigned char)255;
		}else
		if (idx2 < w)
		{
			int sum = in[idx2].r * (-8) + in[idx2 - 1].r + in[idx2 + 1].r + in[idx2 + res_pitch - 1].r + in[idx2 + res_pitch + 1].r + in[idx2 + res_pitch].r;
			if ((sum) >= 0 && (sum) <= 255) out[idx2].r = (unsigned char)(sum);
			else if ((sum) < 0) out[idx2].r = (unsigned char)0;
			else if ((sum) > 255) out[idx2].r = (unsigned char)255;

			sum = in[idx2].g * (-8) + in[idx2 - 1].g + in[idx2 + 1].g + in[idx2 + res_pitch - 1].g + in[idx2 + res_pitch + 1].g + in[idx2 + res_pitch].g;
			if ((sum) >= 0 && (sum) <= 255) out[idx2].g = (unsigned char)(sum);
			else if ((sum) < 0) out[idx2].g = (unsigned char)0;
			else if ((sum) > 255) out[idx2].g = (unsigned char)255;

			sum = in[idx2].b * (-8) + in[idx2 - 1].b + in[idx2 + 1].b + in[idx2 + res_pitch - 1].b + in[idx2 + res_pitch + 1].b + in[idx2 + res_pitch].b;
			if ((sum) >= 0 && (sum) <= 255) out[idx2].b = (unsigned char)(sum);
			else if ((sum) < 0) out[idx2].b = (unsigned char)0;
			else if ((sum) > 255) out[idx2].b = (unsigned char)255;
		}
	}
	if (blockIdx.y == 1)
	{
		if (idx2 == 0)
		{
			return;
		}else
		if (idx2 == h - 1)
		{
			int sum = in[(h - 1)*res_pitch].r * (-8) + in[(h - 1)*res_pitch + 1].r + in[(h - 2)*res_pitch].r + in[(h - 2)*res_pitch + 1].r;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1)*out_pitch].r = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1)*out_pitch].r = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1)*out_pitch].r = (unsigned char)255;

			sum = in[(h - 1)*res_pitch].g * (-8) + in[(h - 1)*res_pitch + 1].g + in[(h - 2)*res_pitch].g + in[(h - 2)*res_pitch + 1].g;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1)*out_pitch].g = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1)*out_pitch].g = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1)*out_pitch].g = (unsigned char)255;

			sum = in[(h - 1)*res_pitch].b * (-8) + in[(h - 1)*res_pitch + 1].b + in[(h - 2)*res_pitch].b + in[(h - 2)*res_pitch + 1].b;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1)*out_pitch].b = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1)*out_pitch].b = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1)*out_pitch].b = (unsigned char)255;
		} else 
			if (idx2 >= h)
			{
				int sum = in[idx2 * res_pitch].r * (-8) + in[idx2 * res_pitch + 1].r + in[(idx2 - 1) * res_pitch].r + in[(idx2 - 1) * res_pitch + 1].r + in[(idx + 1) * res_pitch].r + in[(idx + 1) * res_pitch + 1].r;
				if ((sum) >= 0 && (sum) <= 255) out[idx2 * res_pitch].r = (unsigned char)(sum);
				else if ((sum) < 0) out[idx2 * res_pitch].r = (unsigned char)0;
				else if ((sum) > 255) out[idx2 * res_pitch].r = (unsigned char)255;

				sum = in[idx2 * res_pitch].g * (-8) + in[idx2 * res_pitch + 1].g + in[(idx2 - 1) * res_pitch].g + in[(idx2 - 1) * res_pitch + 1].g + in[(idx + 1) * res_pitch].g + in[(idx + 1) * res_pitch + 1].g;
				if ((sum) >= 0 && (sum) <= 255) out[idx2 * res_pitch].g = (unsigned char)(sum);
				else if ((sum) < 0) out[idx2 * res_pitch].g = (unsigned char)0;
				else if ((sum) > 255) out[idx2 * res_pitch].g = (unsigned char)255;

				sum = in[idx2 * res_pitch].b * (-8) + in[idx2 * res_pitch + 1].b + in[(idx2 - 1) * res_pitch].b + in[(idx2 - 1) * res_pitch + 1].b + in[(idx + 1) * res_pitch].b + in[(idx + 1) * res_pitch + 1].b;
				if ((sum) >= 0 && (sum) <= 255) out[idx2 * res_pitch].b = (unsigned char)(sum);
				else if ((sum) < 0) out[idx2 * res_pitch].b = (unsigned char)0;
				else if ((sum) > 255) out[idx2 * res_pitch].b = (unsigned char)255;
			}
	}
	if (blockIdx.y == 2)
	{
		if (idx2 >= h) return;
		if (idx2 == 0)
		{
			return;
		}
		else if (idx2 == h - 1)
		{
			int sum = in[(h - 1) * res_pitch + w - 1].r * (-8) + in[(h - 2) * res_pitch + w - 1].r + in[(h - 2) * res_pitch + w - 1 - 1].r + in[(h - 1) * res_pitch + w - 1 - 1].r;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1) * out_pitch + w - 1].r = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1) * out_pitch + w - 1].r = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1) * out_pitch + w - 1].r = (unsigned char)255;

			sum = in[(h - 1) * res_pitch + w - 1].g * (-8) + in[(h - 2) * res_pitch + w - 1].g + in[(h - 2) * res_pitch + w - 1 - 1].g + in[(h - 1) * res_pitch + w - 1 - 1].g;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1) * out_pitch + w - 1].g = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1) * out_pitch + w - 1].g = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1) * out_pitch + w - 1].g = (unsigned char)255;

			sum = in[(h - 1) * res_pitch + w - 1].b * (-8) + in[(h - 2) * res_pitch + w - 1].b + in[(h - 2) * res_pitch + w - 1 - 1].b + in[(h - 1) * res_pitch + w - 1 - 1].b;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1) * out_pitch + w - 1].b = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1) * out_pitch + w - 1].b = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1) * out_pitch + w - 1].b = (unsigned char)255;
		}
		else
		{
			int sum = in[idx2 * res_pitch + w - 1].r * (-8) + in[idx2 * res_pitch + w - 1 - 1].r + in[(idx2 - 1) * res_pitch + w - 1].r + in[(idx2 - 1) * res_pitch + w - 1 - 1].r
				+ in[(idx2 + 1) * res_pitch + w - 1].r + in[(idx2 + 1) * res_pitch + w - 1 - 1].r;
			if ((sum) >= 0 && (sum) <= 255) out[idx2 * res_pitch + w - 1].r = (unsigned char)(sum);
			else if ((sum) < 0) out[idx2 * res_pitch + w - 1].r = (unsigned char)0;
			else if ((sum) > 255) out[idx2 * res_pitch + w - 1].r = (unsigned char)255;

			sum = in[idx2 * res_pitch + w - 1].g * (-8) + in[idx2 * res_pitch + w - 1 - 1].g + in[(idx2 - 1) * res_pitch + w - 1].g + in[(idx2 - 1) * res_pitch + w - 1 - 1].g
				+ in[(idx2 + 1) * res_pitch + w - 1].g + in[(idx2 + 1) * res_pitch + w - 1 - 1].g;
			if ((sum) >= 0 && (sum) <= 255) out[idx2 * res_pitch + w - 1].g = (unsigned char)(sum);
			else if ((sum) < 0) out[idx2 * res_pitch + w - 1].g = (unsigned char)0;
			else if ((sum) > 255) out[idx2 * res_pitch + w - 1].g = (unsigned char)255;

			sum = in[idx2 * res_pitch + w - 1].b * (-8) + in[idx2 * res_pitch + w - 1 - 1].b + in[(idx2 - 1) * res_pitch + w - 1].b + in[(idx2 - 1) * res_pitch + w - 1 - 1].b
				+ in[(idx2 + 1) * res_pitch + w - 1].b + in[(idx2 + 1) * res_pitch + w - 1 - 1].b;
			if ((sum) >= 0 && (sum) <= 255) out[idx2 * res_pitch + w - 1].b = (unsigned char)(sum);
			else if ((sum) < 0) out[idx2 * res_pitch + w - 1].b = (unsigned char)0;
			else if ((sum) > 255) out[idx2 * res_pitch + w - 1].b = (unsigned char)255;
		}
	}
	if (blockIdx.y == 3)
	{
		if (idx2 >= w) return;
		if (idx2 == 0)
		{
			return;
		}
		else if (idx2 == w - 1)
		{
			return;
		}
		else
		{
			int sum = in[(h - 1) * res_pitch + idx2].r * (-8) + in[(h - 1) * res_pitch + idx2 - 1].r + in[(h - 1) * res_pitch + idx2 + 1].r
				+ in[(h - 1) * res_pitch + idx2 - res_pitch - 1].r + in[(h - 1) * res_pitch + idx2 - res_pitch].r + in[(h - 1) * res_pitch + idx2 - res_pitch + 1].r;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1) * res_pitch + idx2].r = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1) * res_pitch + idx2].r = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1) * res_pitch + idx2].r = (unsigned char)255;

			sum = in[(h - 1) * res_pitch + idx2].g * (-8) + in[(h - 1) * res_pitch + idx2 - 1].g + in[(h - 1) * res_pitch + idx2 + 1].g
				+ in[(h - 1) * res_pitch + idx2 - res_pitch - 1].g + in[(h - 1) * res_pitch + idx2 - res_pitch].g + in[(h - 1) * res_pitch + idx2 - res_pitch + 1].g;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1) * res_pitch + idx2].g = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1) * res_pitch + idx2].g = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1) * res_pitch + idx2].g = (unsigned char)255;

			sum = in[(h - 1) * res_pitch + idx2].b * (-8) + in[(h - 1) * res_pitch + idx2 - 1].b + in[(h - 1) * res_pitch + idx2 + 1].b
				+ in[(h - 1) * res_pitch + idx2 - res_pitch - 1].b + in[(h - 1) * res_pitch + idx2 - res_pitch].b + in[(h - 1) * res_pitch + idx2 - res_pitch + 1].b;
			if ((sum) >= 0 && (sum) <= 255) out[(h - 1) * res_pitch + idx2].b = (unsigned char)(sum);
			else if ((sum) < 0) out[(h - 1) * res_pitch + idx2].b = (unsigned char)0;
			else if ((sum) > 255) out[(h - 1) * res_pitch + idx2].b = (unsigned char)255;
		}
	}

	if (idy < h - 1 && idx < w - 1)
	{
		int a[9] = {};
		for (int z2 = 0; z2 < 3; ++z2)
		{
			for (int z1 = 0; z1 < 3; ++z1)
			{
				a[3 * z2 + z1] = in[idx + idy * res_pitch + (z2 - 1) * res_pitch + (z1 - 1)].r;// idx + idy * w + z2 * w + z1
			}
		}

		int sum = a[0] + a[1] + a[2] + a[3] + (a[4] * (-8)) + a[5] + a[6] + a[7] + a[8];

		if ((sum) >= 0 && (sum) <= 255) out[idy * out_pitch + idx].r = (unsigned char)(sum);
		else if ((sum) < 0) out[idy * out_pitch + idx].r = (unsigned char)0;
		else if ((sum) > 255) out[idy * out_pitch + idx].r = (unsigned char)255;

		for (int z2 = 0; z2 < 3; ++z2)
		{
			for (int z1 = 0; z1 < 3; ++z1)
			{
				a[3 * z2 + z1] = in[idx + idy * res_pitch + (z2 - 1) * res_pitch + (z1 - 1)].g;// idx + idy * w + z2 * w + z1
			}
		}

		sum = a[0] + a[1] + a[2] + a[3] + (a[4] * (-8)) + a[5] + a[6] + a[7] + a[8];

		if ((sum) >= 0 && (sum) <= 255) out[idy * out_pitch + idx].g = (unsigned char)(sum);
		else if ((sum) < 0) out[idy * out_pitch + idx].g = (unsigned char)0;
		else if ((sum) > 255) out[idy * out_pitch + idx].g = (unsigned char)255;

		for (int z2 = 0; z2 < 3; ++z2)
		{
			for (int z1 = 0; z1 < 3; ++z1)
			{
				a[3 * z2 + z1] = in[idx + idy * res_pitch + (z2 - 1) * res_pitch + (z1 - 1)].b;// idx + idy * w + z2 * w + z1
			}
		}

		sum = a[0] + a[1] + a[2] + a[3] + (a[4] * (-8)) + a[5] + a[6] + a[7] + a[8];

		if ((sum) >= 0 && (sum) <= 255) out[idy * out_pitch + idx].b = (unsigned char)(sum);
		else if ((sum) < 0) out[idy * out_pitch + idx].b = (unsigned char)0;
		else if ((sum) > 255) out[idy * out_pitch + idx].b = (unsigned char)255;
	}
}

BitmapPGM filterOnCuda2(BitmapPGM i_bmp)
{
	unsigned char *res = (unsigned char *)malloc(sizeof(unsigned char) * i_bmp.size_x * i_bmp.size_y * i_bmp.chanel);

	unsigned char* inputCuda;
	unsigned char* resCuda;
	size_t inputPitch;
	size_t resPitch;

	checkCUDAStatus(cudaMallocPitch(&inputCuda, &inputPitch, i_bmp.size_x * 3, i_bmp.size_y));
	checkCUDAStatus(cudaMallocPitch(&resCuda, &resPitch, i_bmp.size_x * 3, i_bmp.size_y));

	cudaEvent_t begin, end;
	cudaEventCreate(&begin);
	cudaEventCreate(&end);

	cudaEventRecord(begin);
	checkCUDAStatus(cudaMemcpy2D(inputCuda, inputPitch, i_bmp.bitmap, i_bmp.size_x * 3, i_bmp.size_x * 3 * sizeof(unsigned char), i_bmp.size_y, cudaMemcpyHostToDevice));

	int dimGrid_x = 0;
	int dimGrid_y = 0;

	if (i_bmp.size_x % 32 == 0) dimGrid_x = i_bmp.size_x / 32;
	else dimGrid_x = i_bmp.size_x / 32 + 1;
	if (i_bmp.size_y % 32 == 0) dimGrid_y = i_bmp.size_y / 16;
	else dimGrid_y = i_bmp.size_y / 32 + 1;

	dim3 dimBlock(32, 32);
	dim3 dimGrid(dimGrid_x, dimGrid_y);

	filterGPU4 << < dimGrid, dimBlock >> > (i_bmp.size_y, i_bmp.size_x, (RGBCC*)inputCuda, (RGBCC*)resCuda, (int)inputPitch / 3, (int)resPitch / 3);

	checkCUDAStatus(cudaMemcpy2D(res, i_bmp.size_x * 3, resCuda, resPitch, i_bmp.size_x * 3 * sizeof(unsigned char), i_bmp.size_y, cudaMemcpyDeviceToHost));

	cudaEventRecord(end);
	cudaDeviceSynchronize();

	float resTime = 0;
	cudaEventElapsedTime(&resTime, begin, end);

	printf("CUDA time: %f seconds\n", resTime / 1000);

	return BitmapPGM(&i_bmp, res);
}

void compearBitmap(BitmapPGM bmp1, BitmapPGM bmp2)
{
	cout << "Compear bitmap: ";
	for (int j = 0; j < bmp1.size_y; j++)
	{
		for (int i = 0; i < bmp1.size_x * bmp1.chanel; i++)
		{
			if (bmp1.bitmap[i + j * bmp1.size_x] != bmp2.bitmap[i + j * bmp1.size_x])
			{
				if (bmp1.bitmap[i + j * bmp1.size_x] - bmp2.bitmap[i + j * bmp1.size_x] > 2
					|| bmp2.bitmap[i + j * bmp1.size_x] - bmp1.bitmap[i + j * bmp1.size_x] > 2)
				{
					cout << "Error in pos: " << j << " " << i << "\tbmp1: " << (int)bmp1.bitmap[i + j * bmp1.size_x] << " bmp2: " << (int)bmp2.bitmap[i + j * bmp1.size_x] << endl;
					system("pause");
				}
			}
		}
	}
	cout << "Matrix equal" << endl;
}

void main()
{
	BitmapPGM bmp;
	openPGM("test5.ppm", &bmp);

	if (bmp.chanel == 3)
	{
		RGBBmp cBmp = raspilRGB(bmp);

		RGBBmp cAns;
		cAns.r = filterCPU(cBmp.r);
		cAns.g = filterCPU(cBmp.g);
		cAns.b = filterCPU(cBmp.b);

		BitmapPGM ans = mergingRGB(cAns);

		BitmapPGM ans2 = filterOnCuda2(bmp);

		compearBitmap(ans, ans2);

		savePGM("result.ppm", ans2);
	}
	else
	{
		BitmapPGM ans = filterCPU(bmp);
		BitmapPGM ans2 = filterOnCuda2(bmp);

		compearBitmap(ans, ans2);

		savePGM("save1.pgm", ans);
	}
	system("pause");
}