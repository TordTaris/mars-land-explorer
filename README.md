# MARS LAND 2.0

เว็บจำลองดาวอังคารแบบ 3D สำหรับเปิดผ่านเบราว์เซอร์บนคอมพิวเตอร์และ Android

- เว็บไซต์ที่ตั้งค่าไว้: https://tordtaris.github.io/mars-land-explorer/
- Repository: https://github.com/TordTaris/mars-land-explorer

## เผยแพร่เว็บไซต์ฟรี

โปรเจกต์นี้เป็น static site ใช้ GitHub Pages และ GitHub Actions โดยไม่ต้องใช้ Lovable, ไม่ต้องมี build server และไม่ต้องใส่เครดิตบริการเสียเงิน

เมื่อ push ไปที่ branch `main` workflow `.github/workflows/deploy-pages.yml` จะ:
1. ตรวจไฟล์ HTML, manifest, ไอคอน, เส้นทาง PWA และ import ของ Three.js
2. ตรวจ syntax ของ JavaScript ด้วย Node.js
3. คัดลอกไฟล์เว็บไปยังโฟลเดอร์ `_site`
4. เผยแพร่ด้วย GitHub Pages

## ใช้งานบน Android

1. เปิดเว็บไซต์ด้วย Chrome
2. อนุญาตให้โหลด JavaScript และเชื่อมต่ออินเทอร์เน็ตเพื่อโหลด Three.js และพื้นผิวดาวจาก CDN
3. ลากเพื่อหมุนดาว ใช้สองนิ้วเพื่อซูม และแตะจุดแปลงเพื่อดูรายละเอียด
4. หาก Chrome แสดงคำสั่งติดตั้ง สามารถเลือกเมนู **เพิ่มลงในหน้าจอหลัก** ได้

ไฟล์ manifest, service worker และไอคอนใช้ relative paths เพื่อรองรับ URL แบบ GitHub Pages project site ที่มีส่วนต่อท้าย `/mars-land-explorer/`

## ขอบเขตของโหมดทดลอง

- โปรไฟล์ การจองแปลง และอาคารเก็บไว้ใน `localStorage` ของอุปกรณ์/เบราว์เซอร์เครื่องนั้น
- ข้อมูลไม่ซิงก์ระหว่างสมาชิกหรืออุปกรณ์ และการจองไม่ใช่กรรมสิทธิ์ในที่ดินจริง
- ไม่มีการซื้อขาย การชำระเงินจริง หรือระบบสมาชิกออนไลน์ที่เปิดใช้งาน
- ไฟล์ `world-server.js` และ SQL ในโฟลเดอร์ `supabase/` เป็นส่วนเตรียมระบบเท่านั้น ยังไม่ได้เชื่อมเข้าหน้าเว็บที่เผยแพร่
- Service worker เก็บเฉพาะโครงหน้าเว็บและไฟล์พื้นฐานไว้ใช้งานซ้ำ; ไลบรารี Three.js และ OrbitControls มาจาก jsDelivr CDN จึงยังต้องใช้อินเทอร์เน็ตเพื่อเริ่มฉาก 3D; พื้นผิวดาวสร้างภายในเครื่อง
- เว็บไซต์นี้เป็นเว็บแอป ไม่ใช่ไฟล์ APK สำหรับติดตั้งแบบ native

## ตรวจสอบสถานะเผยแพร่

ดูผลล่าสุดได้ที่แท็บ Actions:
https://github.com/TordTaris/mars-land-explorer/actions

ต้องเห็น workflow **Deploy Mars Local to GitHub Pages** เป็น `success` ก่อนถือว่าการเผยแพร่ของ commit นั้นเสร็จสมบูรณ์
