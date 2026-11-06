alter table public.world_structures drop constraint if exists world_structures_structure_type_check;
alter table public.world_structures add constraint world_structures_structure_type_check check (structure_type = any (array['ฐานที่อยู่อาศัย'::text,'ห้องปฏิบัติการ'::text,'โรงเรือนปลูกพืช'::text,'แผงพลังงานแสงอาทิตย์'::text,'โรงไฟฟ้านิวเคลียร์ขนาดใหญ่'::text,'ศูนย์จัดเก็บข้อมูล'::text]));
