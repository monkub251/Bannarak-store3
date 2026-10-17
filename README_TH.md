# BANNARAKX · FIVE M FPS OPTIMIZER (GUI ใหม่)

หน้าต่างใหม่ขาว-ดำ-เงิน มีหลุมดำเรนเดอร์สดขนาดใหญ่ (ยิงรังสีแสงตามสมการ Schwarzschild — เลนส์ความโน้มถ่วง, จานเอียงลงซ้าย, ดาวถูกบิดโค้ง)

## รัน
- ทดลอง: ติดตั้ง Python 3.10+ แล้วดับเบิลคลิก `RUN.bat`
- ทำ .exe: ดับเบิลคลิก `BUILD_EXE.bat` → ได้ `dist\FiveM_FPS_Optimizer.exe` (ขอสิทธิ์ Admin ตอนเปิด)

## ปุ่มต่อกับอะไร (สคริปต์เดิมในโฟลเดอร์ `pack\` ไม่ถูกแก้)
| ปุ่ม | สคริปต์ |
|---|---|
| ULTIMATE V2 → OPTIMIZE | `BANNARAKX_ULTIMATE.ps1 -Auto -NoReboot` |
| PULSE V2 → OPTIMIZE | `BANNARAKX_ULTIMATE.ps1 -Plus -Auto -NoReboot` แล้ว import `reg\04`, `05`, `06` (EXTREME) — แรงกว่า ULTIMATE: หยุด Windows Update/Printing/RDP/File sharing, ลดโปรเซส, QoS FiveM; **ไม่รวม** `07_OPTIONAL_SECURITY_OFF` |
| GLOBAL RESET | เมนู Restore (R) ของ ULTIMATE.ps1 (+ `_UNDO.reg` ของ 06/05/04 ถ้าเป็น PULSE) — ทั้งสองโปรไฟล์ใช้ backup ร่วมกัน |

- ไม่รีสตาร์ทเครื่องให้เอง (ส่ง `-NoReboot`) — เสร็จแล้วรีสตาร์ทเอง
- ผลลัพธ์จากสคริปต์ดูได้ที่หน้า LOG; backup ของสคริปต์อยู่ที่ `C:\ProgramData\BannarakxNetForge`
- ABOUT → BLACK HOLE ANIMATION: FULL / LITE / STILL (ลดภาระเครื่อง)

## ทำ .exe ด้วย Nuitka (แปลง Python → C → exe)
- `BUILD_NUITKA.bat` → ไฟล์เดียว `dist_nuitka\FiveM_FPS_Optimizer.exe`
- `BUILD_NUITKA_FOLDER.bat` → แบบโฟลเดอร์ `dist_nuitka\main.dist\` (เปิดเร็วกว่า โดนแอนตี้ไวรัสน้อยกว่า)
- ต้องใช้ Python 3.11 หรือ 3.12 (64-bit) และ C compiler (Nuitka จะโหลด MinGW ให้เองถ้าไม่มี)
- ครั้งแรกคอมไพล์นานหลายนาที ครั้งต่อไปเร็วขึ้น
- หน้าตา ปุ่ม และการทำงานเหมือนเดิมทุกอย่าง (BUILD_EXE.bat แบบ PyInstaller ยังใช้ได้เหมือนเดิม)
- GitHub: Actions → "Build EXE (Nuitka)" → Run workflow
