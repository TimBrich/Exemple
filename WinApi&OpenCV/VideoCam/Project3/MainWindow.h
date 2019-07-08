#pragma once

#include <Windows.h>
#include "video.h"

#define MAINRECT { 180, 16, 800 + 180, 660 + 16 }
video camera = video();
HHOOK hHook = NULL;
HWND HWnd;


string ParspProgBag(IPropertyBag *pPropBag, LPCOLESTR str) {
	VARIANT var;
	VariantInit(&var);
	string deviceInfo = "";
	pPropBag->Read(str, &var, 0);
	int wslen = SysStringLen(var.bstrVal);
	int len = WideCharToMultiByte(CP_ACP, 0, (wchar_t*)var.bstrVal, wslen, NULL, 0, NULL, NULL);
	string dblstr(len, '\0');
	len = WideCharToMultiByte(CP_ACP, 0, (wchar_t*)var.bstrVal, wslen, &dblstr[0], len, NULL, NULL);
	deviceInfo = dblstr;

	VariantClear(&var);
	return deviceInfo;
}
class MainWindow
{
public:
	HWND hWnd;
	WNDCLASS WndClass;
	MSG Msg;

	HINSTANCE hPrevInstance;
	LPSTR lpszCmdParam;
	int nCmdShow;

public:
	MainWindow(HINSTANCE hInstance, HINSTANCE _hPrevInstance,
		LPSTR _lpszCmdParam, int _nCmdShow)
	{
		WndClass.style = CS_HREDRAW | CS_VREDRAW;
		WndClass.lpfnWndProc = (WNDPROC)this->HelloWorldWndProc;
		WndClass.cbClsExtra = 0;
		WndClass.cbWndExtra = 0;
		WndClass.hInstance = hInstance;
		WndClass.hIcon = LoadIcon(NULL, IDI_APPLICATION);
		WndClass.hCursor = LoadCursor(NULL, IDC_ARROW);
		WndClass.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH);
		WndClass.lpszMenuName = NULL;
		WndClass.lpszClassName = "IIPU";

		hPrevInstance = _hPrevInstance;
		lpszCmdParam = _lpszCmdParam;
		nCmdShow = _nCmdShow;
	}
	bool run()
	{
		hHook = SetWindowsHookEx(WH_KEYBOARD_LL, HookKey, NULL, 0);

		if (!RegisterClass(&WndClass))
		{
			MessageBox(NULL, "Cannot register class", "Error", MB_OK);
			return 0;
		}
		hWnd = CreateWindow("IIPU", "lab_4",
			WS_OVERLAPPEDWINDOW,
			CW_USEDEFAULT, CW_USEDEFAULT,
			850, 550,
			NULL, NULL, WndClass.hInstance, NULL);
		HWnd = hWnd;

		if (!hWnd)
		{
			MessageBox(NULL, "Cannot create window", "Error", MB_OK);
			return 0;
		}

		ShowWindow(hWnd, nCmdShow);
		UpdateWindow(hWnd);

		while (GetMessage(&Msg, NULL, 0, 0))
		{
			TranslateMessage(&Msg);
			DispatchMessage(&Msg);
		}
		return 1;
	}
	static void PaintWebCam()
	{
		while (true)
		{
			HANDLE hBitmap;
			BITMAP Bitmap;
			HDC hdcMem;
			POINT ptSize, ptOrg;

			HWND hWnd = FindWindowA("IIPU", NULL);
			HDC hDC = GetDC(hWnd);
			camera.takeAFrame();
			hBitmap = LoadImage(NULL, "frame1.bmp", IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE);
			GetObject(hBitmap, sizeof(BITMAP), &Bitmap);

			hdcMem = CreateCompatibleDC(hDC);
			SelectObject(hdcMem, hBitmap);
			SetMapMode(hdcMem, GetMapMode(hDC));
			GetObject(hBitmap, sizeof(BITMAP), (LPVOID)&Bitmap);
			ptSize.x = Bitmap.bmWidth;
			ptSize.y = Bitmap.bmHeight;
			DPtoLP(hDC, &ptSize, 1);
			DPtoLP(hdcMem, &ptOrg, 1);
			BitBlt(
				hDC, 180, 16, ptSize.x, ptSize.y,
				hdcMem, 0, 0, SRCCOPY
			);
			DeleteDC(hdcMem);
		}
	}
	static LRESULT CALLBACK HelloWorldWndProc(HWND hWnd, UINT Message,  WPARAM wParam, LPARAM lParam)
	{
		HDC hDC, hCompatibleDC;
		PAINTSTRUCT PaintStruct;
		RECT rect;
		static HWND hwndButton[3];
		RECT Pos;
		HGDIOBJ hBrushOld;
		HBRUSH hBrush;
		//string res;
		ICreateDevEnum *pDevEnum;
		IMoniker *pMoniker = NULL;
		IPropertyBag *pPropBag;
		string str;
		HANDLE thread;

		switch (Message)
		{
		case WM_CREATE:
			HWnd = GetForegroundWindow();
			static int cxChar, cyChar;
			TEXTMETRIC tm;
			hDC = GetDC(hWnd);
			thread = CreateThread(NULL, NULL, (LPTHREAD_START_ROUTINE)PaintWebCam, (LPVOID)(&hWnd,&hDC), NULL, NULL);
			SelectObject(hDC, GetStockObject(SYSTEM_FIXED_FONT));
			GetTextMetrics(hDC, &tm);
			cxChar = tm.tmAveCharWidth;
			cyChar = tm.tmHeight + tm.tmExternalLeading;
			ReleaseDC(hWnd, hDC);
			hwndButton[0] = CreateWindow("button", "Сохранить картинку",
				WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
				cxChar, cyChar *(1 + 2 * 0),
				20 * cxChar, 7 * cyChar / 4,
				hWnd, (HMENU)0,
				((LPCREATESTRUCT)lParam)->hInstance, NULL);
			hwndButton[1] = CreateWindow("button", "Старт записи",
				WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
				cxChar, cyChar *(1 + 2 * 1),
				20 * cxChar, 7 * cyChar / 4,
				hWnd, (HMENU)1,
				((LPCREATESTRUCT)lParam)->hInstance, NULL);
			hwndButton[2] = CreateWindow("button", "Стоп запись",
				WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | WS_DISABLED,
				cxChar, cyChar *(1 + 2 * 2),
				20 * cxChar, 7 * cyChar / 4,
				hWnd, (HMENU)2,
				((LPCREATESTRUCT)lParam)->hInstance, NULL);
			hwndButton[3] = CreateWindow("button", "Вывести инфу",
				WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
				cxChar, cyChar *(1 + 2 * 3),
				20 * cxChar, 7 * cyChar / 4,
				hWnd, (HMENU)3,
				((LPCREATESTRUCT)lParam)->hInstance, NULL);
			return 0;

		case WM_PAINT:
			hDC = BeginPaint(hWnd, &PaintStruct);

			rect = { 8, 140,
					168, 155 };
			DrawText(hDC, "Click f1/f2 to start/stop re", -1, &rect,
				DT_SINGLELINE | DT_LEFT | DT_VCENTER);
			rect = { 8, 170,
					168, 185 };
			DrawText(hDC, "Click f3/f4 to hide/show", -1, &rect,
				DT_SINGLELINE | DT_LEFT | DT_VCENTER);
			rect = { 8, 200,
					168, 215 };
			DrawText(hDC, "Click ESC to exit", -1, &rect,
				DT_SINGLELINE | DT_LEFT | DT_VCENTER);
			

			EndPaint(hWnd, &PaintStruct);

			return 0;

		case WM_COMMAND:
			switch (wParam)
			{
			case 0:
				camera.takeAPhoto();
				return 0;

			case 1:
				EnableWindow(hwndButton[2], true);
				EnableWindow(hwndButton[1], false);
				camera.startRecord();
				return 0;

			case 2:
				EnableWindow(hwndButton[2], false);
				EnableWindow(hwndButton[1], true);
				camera.stopRecord();
				return 0;
			case 3:
				CoCreateInstance(CLSID_SystemDeviceEnum, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pDevEnum));
				IEnumMoniker *pEnum;
				pDevEnum->CreateClassEnumerator(CLSID_VideoInputDeviceCategory, &pEnum, 0);
				pDevEnum->Release();
				pEnum->Next(1, &pMoniker, NULL);
				pMoniker->BindToStorage(0, 0, IID_PPV_ARGS(&pPropBag));
				res += "Device name - " + ParspProgBag(pPropBag, L"FriendlyName") + "\n";
				str = ParspProgBag(pPropBag, L"DevicePath");
				res += "Connected to " + str.substr(str.find("\\") + 4, 3) + "\n";
				res += "VendorID - " + str.substr(str.find("vid_") + 4, 4) + "\n";
				res += "ProductID - " + str.substr(str.find("pid_") + 4, 4) + "\n";
				MessageBox(NULL, (LPCSTR)res.c_str(), "WebCamInfo", MB_OK);
				return 0;

			default:
				break;
			}
			return 0;

		case WM_DESTROY:
			exit(0);
			return 0;

		default:
			break;
		}
		return DefWindowProc(hWnd, Message, wParam, lParam);
	}
	static LRESULT CALLBACK HookKey(const int nCode, const WPARAM wParam, const LPARAM lParam)
	{
		switch (wParam)
		{
		case WM_KEYDOWN:
			KBDLLHOOKSTRUCT *k = (KBDLLHOOKSTRUCT*)lParam;
			if (k->vkCode == VK_F1)
				SendMessageA(FindWindowA("IIPU", NULL),WM_COMMAND,(WPARAM)1,NULL);
			if (k->vkCode == VK_F2)
				SendMessageA(FindWindowA("IIPU", NULL), WM_COMMAND, (WPARAM)2, NULL);
			if (k->vkCode == VK_F3)
				ShowWindow(FindWindowA("IIPU", NULL), SW_HIDE);
			if (k->vkCode == VK_F4)
				ShowWindow(FindWindowA("IIPU", NULL), SW_SHOW);
			if (k->vkCode == 13) // ENTER
				SendMessageA(FindWindowA("IIPU", NULL), WM_COMMAND, (WPARAM)0, NULL);
			if (k->vkCode == 27) // ESC
				exit(1);
			
			break;
		}
		return CallNextHookEx(hHook, nCode, wParam, lParam);
	}
};