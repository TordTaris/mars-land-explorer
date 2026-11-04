-- LOCAL MARS: private M-003 underground base directory.
-- Apply this migration in the same Supabase project used by world-server.js.
create table if not exists public.m003_private_base (
  floor_no integer primary key check (floor_no between 1 and 24),
  room_name text not null,
  description text not null,
  system_status text not null default 'ONLINE',
  updated_at timestamptz not null default now()
);
alter table public.m003_private_base enable row level security;
drop policy if exists m003_private_base_owner_read on public.m003_private_base;
create policy m003_private_base_owner_read on public.m003_private_base
  for select to authenticated
  using (exists (
    select 1 from public.world_claims c
    where c.parcel_id = 'M-003' and c.owner_id = auth.uid()
  ));
revoke all on public.m003_private_base from anon, public;
grant select on public.m003_private_base to authenticated;
insert into public.m003_private_base (floor_no, room_name, description, system_status) values
(1,'ศูนย์ควบคุมหลัก','ควบคุมการทำงานและติดตามสถานะของฐานใต้ดิน','ONLINE'),
(2,'ห้องบัญชาการ','วางแผนภารกิจและประสานงานทุกแผนก','ONLINE'),
(3,'ระบบรักษาความปลอดภัย','ตรวจสอบประตู เซนเซอร์ และเขตจำกัดการเข้าถึง','ONLINE'),
(4,'ศูนย์สื่อสาร','เครือข่ายสื่อสารภายในและการติดต่อภายนอก','ONLINE'),
(5,'ศูนย์พลังงาน','จัดการพลังงานจากโรงไฟฟ้าและระบบสำรอง','ONLINE'),
(6,'ห้องปฏิกรณ์และควบคุมพลังงาน','พื้นที่ควบคุมจำลองสำหรับระบบพลังงานของฐาน','SIMULATED'),
(7,'ระบบกักเก็บพลังงาน','แบตเตอรี่และระบบจ่ายไฟฉุกเฉิน','ONLINE'),
(8,'ระบบผลิตน้ำ','แปรรูปและหมุนเวียนน้ำใช้ภายในฐาน','ONLINE'),
(9,'ระบบอากาศและออกซิเจน','ตรวจสอบคุณภาพอากาศและการหมุนเวียนออกซิเจน','ONLINE'),
(10,'ห้องปลูกพืช','ผลิตอาหารและศึกษาการเพาะปลูกบนดาวอังคาร','ONLINE'),
(11,'คลังเสบียง','จัดเก็บอาหารและวัสดุจำเป็น','ONLINE'),
(12,'ห้องปฏิบัติการวิทยาศาสตร์','วิเคราะห์ตัวอย่างดิน หิน และทรัพยากร','ONLINE'),
(13,'ศูนย์การแพทย์','พื้นที่ดูแลสุขภาพและการแพทย์ฉุกเฉิน','ONLINE'),
(14,'ที่พักอาศัย A','ที่พักสำหรับทีมปฏิบัติการชุด A','ONLINE'),
(15,'ที่พักอาศัย B','ที่พักสำหรับทีมปฏิบัติการชุด B','ONLINE'),
(16,'โรงอาหาร','พื้นที่รับประทานอาหารและพักผ่อน','ONLINE'),
(17,'โรงซ่อมบำรุง','ซ่อมบำรุงยานพาหนะ หุ่นยนต์ และเครื่องมือ','ONLINE'),
(18,'คลังอะไหล่','จัดเก็บชิ้นส่วนและอุปกรณ์สำรอง','ONLINE'),
(19,'โรงเก็บยานสำรวจ','จอดและเตรียมยานสำรวจพื้นผิวดาว','ONLINE'),
(20,'ศูนย์ควบคุมหุ่นยนต์','ควบคุมหุ่นยนต์สำรวจและระบบอัตโนมัติ','ONLINE'),
(21,'คลังทรัพยากร','จัดเก็บแร่และวัสดุก่อสร้าง','ONLINE'),
(22,'ศูนย์วิจัยใต้ดิน','ศึกษาธรณีวิทยาและสภาพแวดล้อมใต้พื้นผิว','ONLINE'),
(23,'ศูนย์อพยพฉุกเฉิน','จุดรวมพลและระบบสนับสนุนเมื่อเกิดเหตุฉุกเฉิน','STANDBY'),
(24,'ศูนย์บัญชาการสำรอง','ระบบสำรองสำหรับควบคุมฐานเมื่อศูนย์หลักขัดข้อง','STANDBY')
on conflict (floor_no) do update set
 room_name=excluded.room_name, description=excluded.description,
 system_status=excluded.system_status, updated_at=now();
