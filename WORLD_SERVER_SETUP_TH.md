# ตั้งค่า Mars Local World Server

ระบบ World Server ใช้ Supabase PostgreSQL + Auth + Realtime ให้ผู้เล่นหลายคนอ่านข้อมูลแปลงและสิ่งปลูกสร้างชุดเดียวกัน

## เปิดใช้งาน
1. สร้างโปรเจกต์ที่ https://supabase.com/ (เริ่มจาก Free plan ได้ มีโควตา/ข้อจำกัด และโปรเจกต์ฟรีอาจพักเมื่อไม่มีการใช้งาน)
2. เปิด SQL Editor แล้ววางไฟล์ `supabase/migrations/001_mars_world.sql` ทั้งหมด จากนั้นกด Run
3. ไปที่ Project Settings → API แล้วคัดลอก Project URL และ anon/public key เท่านั้น
4. เปิด `world-server.js` แล้วแทน:
   - `https://YOUR-PROJECT.supabase.co` ด้วย Project URL
   - `YOUR_SUPABASE_ANON_KEY` ด้วย anon/public key
5. Commit การเปลี่ยนแปลงและรอ GitHub Pages deploy
6. เปิด Mars Local แล้วใช้แผง WORLD SERVER สมัครสมาชิก/เข้าสู่ระบบออนไลน์

## ความปลอดภัย
- ห้ามใส่ service_role key หรือ database password ในเว็บไซต์
- เปิด RLS ตาม migration; การจองแปลงและสร้างอาคารทำผ่าน RPC ที่ตรวจสอบ auth.uid() ฝั่งฐานข้อมูล
- แปลงหนึ่งแปลงจองได้หนึ่งบัญชีในรุ่นแรก; ทุกคนอ่านสถานะและอาคารได้
- นี่คือระบบเกมจำลอง ไม่ใช่กรรมสิทธิ์ที่ดินหรือสินทรัพย์ซื้อขายเงินจริง

## ข้อจำกัดรุ่นแรก
- ยังไม่ออนไลน์จนกว่าจะตั้งค่า Supabase URL และ anon key
- บัญชีทดลองเดิมใน localStorage แยกจากสมาชิกออนไลน์
- เครดิต MLC เดิมยังไม่ย้ายเข้าฐานข้อมูล
- ระบบ realtime ส่งการเปลี่ยนแปลงแปลง/อาคาร/เหตุการณ์; ระบบตำแหน่ง avatar และแชตจะเป็นงานระยะถัดไป
