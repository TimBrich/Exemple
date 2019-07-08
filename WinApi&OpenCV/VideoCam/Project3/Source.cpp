#include <Windows.h>
#include "MainWindow.h"

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
	LPSTR lpszCmdParam, int nCmdShow)
{
	MainWindow MainW(hInstance,hPrevInstance,lpszCmdParam,nCmdShow);
	MainW.run();
}