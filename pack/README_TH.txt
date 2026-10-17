BANNARAKX NETFORGE  -  ULTIMATE v2.0  (ใหม่: ใช้ BANNARAKX_ULTIMATE.exe)
==================================================

[ วิธีใช้แบบเต็ม (แนะนำ) ]
  *** v2.0: ใช้ BANNARAKX_ULTIMATE.exe (หรือ RUN_ULTIMATE.bat) ตัวเดียวทำครบ:
      DNS + Registry เน็ต + Gpedit + Game Mode/HAGS + High Performance + NVIDIA registry
      + เมาส์/คีย์บอร์ด + ปิด Service/Task + ลด process + Chrome Memory Saver Maximum
      + Disk Cleanup C: + รีสตาร์ทอัตโนมัติ  (เมนู 2 = ULTIMATE+ ปิด Windows Update ด้วย, R = คืนค่า)
      ส่วน NVIDIA Control Panel ต้องทำเองตาม NVIDIA_MANUAL_GUIDE.txt
  1) ดับเบิลคลิก BUILD_EXE.bat  (ทำครั้งเดียว) จะได้ BANNARAKX_NETFORGE.exe และ BANNARAKX_ULTIMATE.exe
  2) ดับเบิลคลิก BANNARAKX_NETFORGE.exe  -> กด Yes (UAC) -> กด ENTER
  3) รอจนจบ เครื่องจะนับถอยหลัง 20 วินาทีแล้วรีสตาร์ทเอง (กด C เพื่อยกเลิก)
  * ถ้าไม่อยากทำ exe ใช้ RUN_NETFORGE.bat แทนได้ ผลเหมือนกัน
  * ต้องเก็บไฟล์ทั้งโฟลเดอร์ไว้ด้วยกัน (exe เรียก BANNARAKX_NETFORGE.ps1 ในโฟลเดอร์เดียวกัน)

[ สิ่งที่ปรับ ]
  DNS       1.1.1.1 / 1.0.0.1 ทุกการ์ดเน็ตที่ใช้งานอยู่
  Registry  Nagle OFF, Network Throttling, TCP/IP, DNS cache, TCP stack
  GPEDIT    LLMNR, QoS 0%, Delivery Optimization, Update/Store, Peernet, Wi-Fi Sense
  ปลอดภัย   สร้าง Restore Point + Backup ค่าเดิมก่อนแก้ทุกครั้ง มีเมนู R = Restore

[ โฟลเดอร์ reg\  (ใช้แยกต่างหากได้ ดับเบิลคลิกแล้วรีสตาร์ท) ]
  01_NETWORK_TWEAKS.reg        + _UNDO
  02_GPEDIT_POLICIES.reg       + _UNDO
  03_INPUT_BOOST.reg           + _UNDO   (เมาส์ / คีย์บอร์ด)
  04_INPUT_SYSTEM_EXTREME.reg  + _UNDO   (ลดโอเวอร์เฮดระบบ ใช้ต่อจาก 03)
  05_GPEDIT_INTERNET_EXTREME.reg + _UNDO (QoS DSCP 46 สำหรับ FiveM/GTA + ตัดทราฟฟิกเบื้องหลัง)
  06_PROCESS_REDUCE.reg        + _UNDO   (รวม svchost / ปิด WER / ปิด Search เว็บ / ปิดแอปเบื้องหลัง)
  07_OPTIONAL_SECURITY_OFF.reg + _UNDO   (เสี่ยง: ปิด mitigation + VBS ใช้เฉพาะถ้าตั้งใจ)
  ไฟล์ UNDO คืนเฉพาะค่าที่ NETFORGE เพิ่มเอง ค่าที่ซ้ำกับชุด APEX เดิมจะไม่ถูกลบ

[ โฟลเดอร์ tools\ ]
  DNS_CLOUDFLARE_SET.bat   ตั้ง DNS 1.1.1.1 / 1.0.0.1
  DNS_AUTO_RESET.bat       คืน DNS เป็นอัตโนมัติ
  EMERGENCY_NET_RESET.bat  กู้เน็ตฉุกเฉิน (winsock / flushdns / DNS auto)
  LEAN_WINDOWS.bat         ลด Process/Service/Task เบื้องหลัง (เมนู 1=LEAN 2=LEAN+ R=Restore)
  INPUT_USB_NO_SLEEP.bat   ปิดโหมดประหยัดไฟเมาส์/คีย์บอร์ด/USB (-Restore คืนค่า)
  SAVE_ORIGINAL_VALUES.bat เซฟค่า registry ปัจจุบัน (ค่าต้นแบบ) ไว้ใน Documents ก่อนใช้ไฟล์ .reg

[ ไม่แตะไฟล์เดิม ]
  ชุดนี้ไม่แก้ไข ไม่อ่าน ไม่เขียนทับไฟล์ APEX เดิม
  Backup/Log เก็บแยกที่ C:\ProgramData\BannarakxNetForge

[ หมายเหตุ ]
  - exe ที่ build เองยังไม่ได้เซ็นดิจิทัล Windows SmartScreen / Antivirus อาจเตือน
    ถ้าจะขายจริงควรเซ็น exe ด้วย Code Signing Certificate
  - ผลลัพธ์จริงต่างกันไปตามเครื่องและเครือข่าย
