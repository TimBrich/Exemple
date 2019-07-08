#include <Windows.h>
#include <iostream>
#include <vector>
#include <conio.h>

using namespace std;

vector<int> test;
bool removeMod = false;

void RemoveDisk(HANDLE hDevice) {
	DWORD dwBytesReturned;
	if (!DeviceIoControl(hDevice, FSCTL_LOCK_VOLUME, NULL, 0, NULL, 0, &dwBytesReturned, NULL)) {
		cout << "Накопитель не извлечён: FSCTL_LOCK_VOLUME" << endl;
		system("pause");
		return;
	}
	if (!DeviceIoControl(hDevice, FSCTL_DISMOUNT_VOLUME, NULL, 0, NULL, 0, &dwBytesReturned, NULL)) {
		cout << "Накопитель не извлечён: FSCTL_DISMOUNT_VOLUME" << endl;
		system("pause");
		return;
	}
	PREVENT_MEDIA_REMOVAL mediaRemoval;
	mediaRemoval.PreventMediaRemoval = FALSE;
	if (!DeviceIoControl(hDevice, IOCTL_STORAGE_MEDIA_REMOVAL, &mediaRemoval, sizeof(PREVENT_MEDIA_REMOVAL), NULL, 0, &dwBytesReturned, NULL)) {
		cout << "Накопитель не извлечён: IOCTL_STORAGE_MEDIA_REMOVAL" << endl;
		system("pause");
		return;
	}
	if (!DeviceIoControl(hDevice, IOCTL_STORAGE_EJECT_MEDIA, NULL, 0, NULL, 0, &dwBytesReturned, NULL)) {
		cout << ("Накопитель не извлечён: IOCTL_STORAGE_EJECT_MEDIA") << endl;
		system("pause");
		return;
	}
	cout << "USB device removed!";
	system("pause");
}
vector<int> GetUSBDevice()
{
	DWORD logicalDrivesBitmask = GetLogicalDrives();
	vector<int> vector;
	if (logicalDrivesBitmask) {
		for (int i = 0; i < 26; i++) {
			if (logicalDrivesBitmask & (1 << i)) {
				wstring drivePathPrefix = L"\\\\.\\";
				WCHAR driveLetter = 'A' + i;
				wstring driveName = drivePathPrefix + driveLetter + L":\\";
				if (GetDriveTypeW(driveName.c_str()) == DRIVE_REMOVABLE) {
					vector.push_back(i);
				}
			}
		}
	}
	return vector;
}
void printUSBbyNum(int deviceNum) {
	WCHAR driveLetter = 'A' + deviceNum;
	wstring drivePathPrefix = L"\\\\.\\";
	wstring drivePath = drivePathPrefix + driveLetter + L":";
	HANDLE hDevice = CreateFileW(drivePath.c_str(), 0, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);

	STORAGE_PROPERTY_QUERY storagePropertyQuery;
	ZeroMemory(&storagePropertyQuery, sizeof(STORAGE_PROPERTY_QUERY));
	storagePropertyQuery.PropertyId = StorageDeviceProperty;
	storagePropertyQuery.QueryType = PropertyStandardQuery;
	STORAGE_DESCRIPTOR_HEADER storageDescriptorHeader = { 0 };
	DWORD dwBytesReturned = 0;

	DeviceIoControl(hDevice, IOCTL_STORAGE_QUERY_PROPERTY, &storagePropertyQuery, sizeof(STORAGE_PROPERTY_QUERY),
		&storageDescriptorHeader, sizeof(STORAGE_DESCRIPTOR_HEADER), &dwBytesReturned, NULL);
	const DWORD dwOutBufferSize = storageDescriptorHeader.Size;
	BYTE* pOutBuffer = new BYTE[dwOutBufferSize];
	ZeroMemory(pOutBuffer, dwOutBufferSize);
	DeviceIoControl(hDevice, IOCTL_STORAGE_QUERY_PROPERTY, &storagePropertyQuery, sizeof(STORAGE_PROPERTY_QUERY),
		pOutBuffer, dwOutBufferSize, &dwBytesReturned, NULL);

	STORAGE_DEVICE_DESCRIPTOR* pDeviceDescriptor = (STORAGE_DEVICE_DESCRIPTOR*)pOutBuffer;
	const DWORD dwSerialNumberOffset = pDeviceDescriptor->SerialNumberOffset;
	if (dwSerialNumberOffset != 0) {
		char name[30];
		char vers[30];
		memcpy(&name, pOutBuffer + pDeviceDescriptor->VendorIdOffset, 30 * sizeof(BYTE));
		memcpy(&vers, pOutBuffer + pDeviceDescriptor->ProductIdOffset, 30 * sizeof(BYTE));
		cout << (CHAR)('A' + deviceNum) << ": " << name << " " << vers << endl;
		ZeroMemory(name, 30);
		ZeroMemory(vers, 30);
	}
	delete pOutBuffer;
}

void main()
{
	int c = 0;
	MSG  msg;
	setlocale(LC_ALL, "Russian");
	while (true)
	{

			system("cls");
			cout << "Нажмите 1 для извлечения диска, 2 для выхода" << endl;
			vector<int> test = GetUSBDevice();
			HANDLE hDevice;
			for (int i = 0; i < test.size(); i++)
			{
				cout << i << ". ";
				printUSBbyNum(test.at(i));
			}
			Sleep(500);
		c = _getch();
		if (c == '1')
		{
			int ans;
			cout << "Введите номер диска: ";
			cin >> ans;
			
			WCHAR driveLetter = 'A' + test.at(ans);
			wstring drivePathPrefix = L"\\\\.\\";
			wstring drivePath = drivePathPrefix + driveLetter + L":";
			HANDLE hDevice = CreateFileW(drivePath.c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING,
											FILE_ATTRIBUTE_NORMAL, NULL);
			RemoveDisk(hDevice);
		}
		if (c == '2')
		{
			exit(0);
		}
	}
}