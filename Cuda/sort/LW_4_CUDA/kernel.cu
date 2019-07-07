#include <iostream> 
#include <cuda_runtime.h> 
#include <stdio.h>
#include <time.h>
#include <ctime>

using namespace std;

//#define TEST_MODE

#ifdef TEST_MODE
#define MATRIX_SIZE 2048

#define MATRIX_SIZE_X MATRIX_SIZE // 512, 1024, 2048, 4096, 8192, 16384, 32768
#define MATRIX_SIZE_Y MATRIX_SIZE
#else
#define MATRIX_SIZE_X 32768 // 512, 1024, 2048, 4096, 8192, 16384, 32768
#define MATRIX_SIZE_Y 8192
#endif

#define BlockSize 32

void checkCUDAStatus(cudaError_t cudaStatus);

void matrixSortWithCuda(short int A[][MATRIX_SIZE_X], short int B[][MATRIX_SIZE_X * 2]);

//Compear matrixs
void compearMtx(short int A[][MATRIX_SIZE_X * 2], short int B[][MATRIX_SIZE_X * 2], string say, bool debugMode = false)
{
	printf("\nCompear array: %s : ", say);
	int buf = 0;
	for (int i = 0; i < MATRIX_SIZE_Y / 2; i++) {
		for (int j = 0; j < MATRIX_SIZE_X * 2; j++) {
			if (!(A[i][j] == B[i][j]))
			{
				printf("Matrix is not equal\n");
				printf("\t\t %d %d \t\t\n \t\t %d != %d \t\t\n", i, j, A[i][j], B[i][j]);
				system("pause");
			}
			else if(debugMode) printf("\n\n suc %d %d : i j %d %d\n", A[i][j], B[i][j], i, j);
		}
	}
	printf("Matrix equal");
}

//CPU sort
void sortcpumatx(short int A[][MATRIX_SIZE_X], short int B[][MATRIX_SIZE_X * 2])
{
	clock_t begin, end;
	begin = clock();

	for (int i = 0; i < MATRIX_SIZE_Y; i++)
	{
		for (int j = 0; j < MATRIX_SIZE_X; j++)
		{
			B[i / 2][j * 2 + i % 2] = A[i][j];
		}
	}
	end = clock();
	printf("CPU time: %lf seconds\n", (double)(end - begin) / CLOCKS_PER_SEC);
}

int main() {
	srand(time(0));

	int(*matrixA1)[MATRIX_SIZE_X] = new int[MATRIX_SIZE_Y][MATRIX_SIZE_X];
	int(*matrixB1)[MATRIX_SIZE_X * 2] = new int[MATRIX_SIZE_Y / 2][MATRIX_SIZE_X * 2];

	short int(*matrixA)[MATRIX_SIZE_X] = reinterpret_cast<short int(*)[MATRIX_SIZE_X]>(matrixA1);
	short int(*matrixB)[MATRIX_SIZE_X * 2] = reinterpret_cast<short int(*)[MATRIX_SIZE_X * 2]>(matrixB1);

	int(*matrixC1)[MATRIX_SIZE_X * 2] = new int[MATRIX_SIZE_Y / 2][MATRIX_SIZE_X * 2];
	short int(*matrixC)[MATRIX_SIZE_X * 2] = reinterpret_cast<short int(*)[MATRIX_SIZE_X * 2]>(matrixC1);

	for (int i = 0; i < MATRIX_SIZE_Y; i++) {
		for (int j = 0; j < MATRIX_SIZE_X; j++) {
			matrixA[i][j] = rand() % 1024;
		}
	}
	for (int i = 0; i < MATRIX_SIZE_Y / 2; i++) {
		for (int j = 0; j < MATRIX_SIZE_X * 2; j++) {
			matrixB[i][j] = 0;
			matrixC[i][j] = 0;
		}
	}

	matrixSortWithCuda(matrixA, matrixB);
	sortcpumatx(matrixA, matrixC);
	compearMtx(matrixB, matrixC, "myGPU and myCPU");

	printf("\n\n");
	system("pause");

	delete[] matrixA;
	delete[] matrixB;
	delete[] matrixC;
}

__global__ void mysort(short int *a, short int *b)
{
	int column = blockIdx.x * blockDim.x + threadIdx.x;
	int row = blockIdx.y * blockDim.y + threadIdx.y;

	if (column >= MATRIX_SIZE_X / 2 || row >= MATRIX_SIZE_Y / 2) {
		return;
	}

	int mat_i = threadIdx.x + blockIdx.x * blockDim.x + (threadIdx.y * 2 + blockIdx.y * blockDim.y * 2) * (blockDim.x * gridDim.x);
	int mat_i2 = threadIdx.x + blockIdx.x * blockDim.x + ((threadIdx.y * 2) + 1 + blockIdx.y * blockDim.y * 2) * (blockDim.x * gridDim.x);

	int str1 = *(int*)(&a[mat_i * 2]);
	int str2 = *(int*)(&a[mat_i2 * 2]);

	short int a1 = ((short int*)&str1)[0];
	short int a2 = ((short int*)&str1)[1];
	short int a3 = ((short int*)&str2)[0];
	short int a4 = ((short int*)&str2)[1];

	long long int res;
	((short int*)&res)[0] = a1;
	((short int*)&res)[1] = a3;
	((short int*)&res)[2] = a2;
	((short int*)&res)[3] = a4;

	int mat_i3 = threadIdx.x * 4 + blockIdx.x * blockDim.x * 4 + (threadIdx.y + blockIdx.y * blockDim.y) * (blockDim.x * gridDim.x * 4);
	*(long long*)(&b[mat_i3]) = res;
}

void matrixSortWithCuda(short int A[][MATRIX_SIZE_X], short int B[][MATRIX_SIZE_X * 2])
{
	short int *dev_a, *dev_b;
	clock_t begin, end;
	cudaError_t cudaStatus;
	cudaEvent_t start;
	cudaEvent_t stop;

	cudaEventCreate(&start);
	cudaEventCreate(&stop);


	cudaStatus = cudaMalloc((void**)&dev_a, ((MATRIX_SIZE_Y)*(MATRIX_SIZE_X)) * sizeof(short int));
	checkCUDAStatus(cudaStatus);
	cudaStatus = cudaMalloc((void**)&dev_b, ((MATRIX_SIZE_X * 2)*(MATRIX_SIZE_Y / 2)) * sizeof(short int));
	checkCUDAStatus(cudaStatus);

	cudaStatus = cudaMemcpy(dev_a, A, ((MATRIX_SIZE_X * MATRIX_SIZE_Y)) * sizeof(short int), cudaMemcpyHostToDevice);
	checkCUDAStatus(cudaStatus);

	dim3 dimBlock(BlockSize, BlockSize);
	dim3 dimGrid((MATRIX_SIZE_X / 2) / dimBlock.x, (MATRIX_SIZE_Y / 2) / dimBlock.y);

	cudaEventRecord(start);

	mysort << < dimGrid, dimBlock >> > (dev_a, dev_b);

	cudaEventRecord(stop);
	cudaEventSynchronize(stop);

	cudaStatus = cudaGetLastError();
	checkCUDAStatus(cudaStatus);

	cudaStatus = cudaMemcpy(B, dev_b, ((MATRIX_SIZE_X * 2 * MATRIX_SIZE_Y / 2)) * sizeof(short int), cudaMemcpyDeviceToHost);
	checkCUDAStatus(cudaStatus);

	float time;
	cudaEventElapsedTime(&time, start, stop);

	printf("CUDA time: %f seconds\n", time / 1000);

	cudaFree(dev_a);
	cudaFree(dev_b);
}

void checkCUDAStatus(cudaError_t cudaStatus) {
	if (cudaStatus != cudaSuccess) {
		printf("CUDA return error code: %d\n", cudaStatus);
		system("pause");
		exit(-1);
	}
}