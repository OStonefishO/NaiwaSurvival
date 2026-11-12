import ctypes, time, sys
from ctypes import wintypes
from PIL import ImageGrab

title_needle = sys.argv[1] if len(sys.argv) > 1 else "奶蛙生存"
out = sys.argv[2] if len(sys.argv) > 2 else "window.png"
user32 = ctypes.windll.user32
user32.SetProcessDPIAware()
EnumWindows = user32.EnumWindows
EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
GetWindowText = user32.GetWindowTextW
GetWindowTextLength = user32.GetWindowTextLengthW
IsWindowVisible = user32.IsWindowVisible
GetWindowRect = user32.GetWindowRect
found = []

def cb(hwnd, lparam):
    if IsWindowVisible(hwnd):
        n = GetWindowTextLength(hwnd)
        tt = ctypes.create_unicode_buffer(n + 1); GetWindowText(hwnd, tt, n + 1)
        if title_needle in tt.value:
            r = wintypes.RECT(); GetWindowRect(hwnd, ctypes.byref(r))
            found.append((hwnd, r.left, r.top, r.right, r.bottom, tt.value))
    return True

EnumWindows(EnumWindowsProc(cb), 0)
print(found)
if not found:
    raise SystemExit(1)
hwnd, left, top, right, bottom, title = found[0]
user32.ShowWindow(hwnd, 9)
user32.SetWindowPos(hwnd, -1, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040)
user32.SetForegroundWindow(hwnd)
user32.BringWindowToTop(hwnd)
time.sleep(1.2)
img = ImageGrab.grab(bbox=(left, top, right, bottom))
img.save(out)
print('saved', out, img.size)
user32.SetWindowPos(hwnd, -2, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040)
