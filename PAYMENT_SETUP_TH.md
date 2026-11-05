> **ประกาศ:** การซื้อพื้นที่ใหม่ใช้ USD ผ่าน Stripe Checkout เท่านั้น; PromptPay THB เป็นระบบเดิมสำหรับประวัติรายการเก่าและปิดการซื้อพื้นที่ใหม่แล้ว ดูขั้นตอน USD ที่ [USD_MARKET_SETUP_TH.md](./USD_MARKET_SETUP_TH.md)

# LOCAL MARS — PromptPay setup (Thai)

สถานะ: เตรียมโค้ดแล้ว แต่ยังไม่เปิดรับเงินจริงจนกว่าจะ deploy functions, ตั้ง secrets, เปิด PromptPay และทดสอบครบ

## 1) Apply migration 004
หลังจากรัน `003_promptpay_parcel_payments.sql` แล้ว ให้รันไฟล์นี้ใน Supabase SQL Editor:
`supabase/migrations/004_promptpay_payment_rpcs.sql`

ไฟล์นี้เพิ่ม RPC ฝั่งเซิร์ฟเวอร์สำหรับสร้างคำสั่งซื้อ, ผูก Checkout Session และมอบสิทธิ์แปลงหลังตรวจ webhook เท่านั้น

## 2) Set up the store owner
ใน Supabase Dashboard → Authentication → Users ให้คัดลอก UUID ของบัญชีเจ้าของร้าน (ไม่ใช่อีเมล)
จากนั้นรัน SQL โดยแทน UUID จริง:
```sql
insert into public.mars_store_admins(user_id)
values ('YOUR_AUTH_USER_UUID')
on conflict (user_id) do nothing;
```

ใช้ UUID เดียวกันเป็นค่า `MARS_OWNER_USER_ID` ใน Edge Function secrets

## 3) Set actual THB parcel prices
ราคาที่แสดงในหน้าสำรวจเป็นมูลค่าอ้างอิง THB ของระบบจำลอง ส่วนยอดชำระเงินจริงต้องสร้างรายการผ่าน PromptPay และยืนยันจาก webhook เท่านั้น
ตั้งราคาจริงต่อแปลงหลังตัดสินใจราคาและได้รับการอนุมัติจาก Stripe:
```sql
update public.world_parcels
set sale_price_thb = 199, is_for_sale = true
where id = 'M-001';
```
ตัวอย่าง 199 บาทนี้เป็นเพียงตัวอย่างสำหรับตั้งค่า ห้ามเปิดขายจนกว่าจะกำหนดราคาและตรวจเงื่อนไขธุรกิจแล้ว
ปิดการขายได้ด้วย `update public.world_parcels set is_for_sale=false where id='M-001';`

## 4) Configure Supabase Edge Function secrets
ตั้งค่าผ่าน Supabase Dashboard → Edge Functions → Secrets:
- `SUPABASE_URL` — project URL
- `SUPABASE_ANON_KEY` — publishable/anon key
- `SUPABASE_SERVICE_ROLE_KEY` — service role secret (เก็บเฉพาะ Secrets ห้ามใส่ GitHub/frontend)
- `STRIPE_SECRET_KEY` — Stripe secret key ของโหมดที่ต้องการใช้
- `STRIPE_WEBHOOK_SECRET` — signing secret ของ webhook endpoint
- `MARS_OWNER_USER_ID` — UUID เจ้าของร้านจากข้อ 2
- `SITE_URL` — `https://tordtaris.github.io/mars-land-explorer`
- `SITE_ORIGIN` — `https://tordtaris.github.io`

อย่าใส่ key หรือ secret ลงใน source code, GitHub, หรือส่งในแชต

## 5) Deploy Edge Functions
Deploy:
- `create-promptpay-checkout` — ต้องตรวจ JWT ของสมาชิก
- `stripe-webhook` — ต้องปิด Supabase JWT verification เพราะ Stripe ไม่ส่ง Supabase JWT; ฟังก์ชันตรวจ `Stripe-Signature` ด้วย webhook signing secret เอง

ด้วย Supabase CLI:
```bash
supabase functions deploy create-promptpay-checkout --project-ref YOUR_PROJECT_REF
supabase functions deploy stripe-webhook --no-verify-jwt --project-ref YOUR_PROJECT_REF
```
หาก deploy ผ่าน Dashboard ให้คัดลอกไฟล์ `supabase/functions/<function-name>/index.ts` ไปยัง function ที่มีชื่อเดียวกัน และตั้งค่า verify JWT ตามข้างต้น

## 6) Register Stripe webhook
ใน Stripe Dashboard สร้าง webhook endpoint:
`https://YOUR_PROJECT_REF.supabase.co/functions/v1/stripe-webhook`
เลือก event:
- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`

คัดลอก signing secret ที่ขึ้นต้นด้วย `whsec_` ไปใส่ Supabase secret `STRIPE_WEBHOOK_SECRET`
PromptPay ต้องเปิดใช้งานบน Stripe account และต้องใช้ THB

## 7) Important operational rules
- เริ่มด้วย Stripe test mode และทดสอบ end-to-end ก่อนเท่านั้น
- ยังไม่ยืนยันว่าธุรกิจขาย virtual in-game parcels ได้จนกว่า Stripe จะตรวจและอนุมัติประเภทธุรกิจ
- แปลงเป็น virtual game access เท่านั้น ไม่ใช่กรรมสิทธิ์ที่ดินจริง
- Owner Wallet บันทึกยอดขายรวมที่ตรวจ webhook แล้ว; net/ยอดพร้อมถอนยังไม่คำนวณจนกว่าจะ reconcile ค่าธรรมเนียมและยอดคงเหลือจริงจาก Stripe
- เงินอยู่ใน Stripe balance ไม่ได้อยู่กับ ChatGPT หรือ Supabase; การถอนทำผ่าน Stripe Dashboard ตาม payout schedule/สิทธิ์บัญชี
- ห้ามเปิด live mode หรือเปิดขายจริงก่อนตรวจราคา, ภาษี/ข้อกำหนด, refund policy, webhook และทดสอบการจองซ้ำ/ชำระซ้ำ
