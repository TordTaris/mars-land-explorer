-- Add a dedicated data storage structure to M-001.
CREATE OR REPLACE FUNCTION public.build_world_structure(p_parcel_id text, p_type text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare u uuid := auth.uid(); new_id uuid;
begin
 if u is null then raise exception 'กรุณาเข้าสู่ระบบออนไลน์ก่อนก่อสร้าง'; end if;
 if not exists(select 1 from public.world_parcels where id=p_parcel_id) then raise exception 'ไม่พบแปลงพื้นที่'; end if;
 if p_type not in ('ฐานที่อยู่อาศัย','ห้องปฏิบัติการ','โรงเรือนปลูกพืช','แผงพลังงานแสงอาทิตย์','โรงไฟฟ้านิวเคลียร์ขนาดใหญ่','ศูนย์จัดเก็บข้อมูล') then raise exception 'ประเภทอาคารไม่ถูกต้อง'; end if;
 if p_type='โรงไฟฟ้านิวเคลียร์ขนาดใหญ่' and p_parcel_id<>'M-003' then raise exception 'โรงไฟฟ้านิวเคลียร์ขนาดใหญ่สร้างได้เฉพาะแปลง M-003'; end if;
 if not exists(select 1 from public.world_claims where parcel_id=p_parcel_id and owner_id=u) then raise exception 'ต้องเป็นเจ้าของแปลงนี้ก่อนก่อสร้าง'; end if;
 if p_type='โรงไฟฟ้านิวเคลียร์ขนาดใหญ่' and exists(select 1 from public.world_structures where parcel_id='M-003' and structure_type=p_type) then raise exception 'แปลง M-003 มีโรงไฟฟ้านิวเคลียร์อยู่แล้ว'; end if;
 insert into public.world_structures(parcel_id,owner_id,structure_type) values(p_parcel_id,u,p_type) returning id into new_id;
 insert into public.world_events(actor_id,event_type,parcel_id,payload) values(u,'structure_built',p_parcel_id,jsonb_build_object('structure_id',new_id,'type',p_type));
 return jsonb_build_object('ok',true,'structure_id',new_id,'parcel_id',p_parcel_id,'type',p_type,'owner_id',u);
end;
$function$;
