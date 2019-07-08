#pragma once

#include <iostream>
#include <opencv2/opencv.hpp>
#include <string>
#include <stdio.h>
#include <time.h>
#include <Windows.h>
#include <Vfw.h>
#include <dshow.h>
#include <thread>
#pragma comment(lib, "vfw32")
#pragma comment(lib, "strmiids")

/*

using namespace cv;
using namespace std;

class video
{
public:
	VideoCapture vcap;
	Mat frame;
	char fname[30];
	bool record;

	VideoWriter vd;
	HANDLE MyThread;

public:
	video()
	{
		vcap = VideoCapture(0);
		vcap >> frame;
		record = false;
	}
	void takeAPhoto()
	{
		char photoName[30];
		sprintf_s(photoName, "Photo%ld.jpg", time(NULL));
		imwrite(photoName, frame);
	}
	Mat GetFrame()
	{
		vcap >> frame;
		return frame;
	}
	void takeAFrame()
	{
		vcap >> frame;
		imwrite("frame1.bmp", frame);
	}
	static void ThreadRecord(video *vd)
	{
		while (vd->record)
		{
			vd->vd.write(vd->GetFrame());
			Sleep(20);
		}
	}
	void startRecord()
	{
		record = true;
		MyThread = CreateThread(NULL, NULL, (LPTHREAD_START_ROUTINE)ThreadRecord, (LPVOID)(this), NULL, NULL);
		sprintf_s(fname, "WebCam%ld.avi", time(NULL));
		vd = VideoWriter(fname, CV_FOURCC('M', 'J', 'P', 'G'), 10,
			Size(vcap.get(CV_CAP_PROP_FRAME_WIDTH), vcap.get(CV_CAP_PROP_FRAME_HEIGHT)), true);
	}
	void stopRecord()
	{
		record = false;
		WaitForSingleObject(MyThread, 100);
		CloseHandle(MyThread);
		vd.release();
	}
};

*/