# LOCAL MARS — USD market rollout (Thai)

สถานะ: เพิ่ม migration 016 แล้ว แต่ยังไม่เปิดรับชำระ USD จริง

## 1) อัตราอ้างอิงที่ใช้แปลงค่า
Migration 016 ใช้อัตราอ้างอิงธนาคารแห่งประเทศไทยวันที่ 5 พฤศจิกายน 2026:
- USD 1 = THB 33.4310
- แหล่งข้อมูล: https://app.bot.or.th/BTWS_STAT/statistics/BOTWEBSTAT.aspx?language=eng&reportID=123

อัตรานี้เป็น snapshot ตามวันที่ ไม่ใช่ราคาซื้อขายแบบเรียลไทม์ และไม่ใช่อัตราที่ผู้ให้บริการชำระเงินรับประกัน

## 2) วิธีติดตั้ง
1. เปิด Supabase Dashboard → SQL Editor
2. ตรวจสอบว่า migration 003, 004 และ 014, 015 ที่จำเป็นได้ถูกรันแล้ว
3. สำรองฐานข้อมูลก่อน
4. เปิดไฟล์ `supabase/migrations/016_usd_market_standard.sql` ใน GitHub แล้วคัดลอก SQL ทั้งหมดไปวาง
5. กด Run และตรวจผลด้วย SQL:
```sql
select * from public.mars_fx_rates
where base_currency='USD' and quote_currency='THB'
order by observed_at desc;

select id, sale_price_thb, sale_price_usd
from public.world_parcels
order by id;
```

## 3) ขอบเขตการแปลง
- ราคาขายอ้างอิงของแปลง: เพิ่มคอลัมน์ `sale_price_usd` และคำนวณจาก THB ด้วยอัตรา snapshot
- `land_plots.price_usd` และ `marketplace_listings.asking_price_usd`: เพิ่ม/เติมค่าจากคอลัมน์ THB เดิมเมื่อมีตารางดังกล่าว
- คอลัมน์ THB เดิมและคำสั่งซื้อเก่าเก็บไว้ตรวจสอบย้อนหลัง ไม่ลบหรือเขียนทับ
- MLC, ยอด MLC, city credits, energy และวัสดุก่อสร้างไม่ถูกแปลง
- ราคาที่ดินดาวอังคารยังเป็นราคาอ้างอิงในระบบจำลอง ไม่ใช่มูลค่าทรัพย์สินจริง

## 4) ข้อจำกัดด้านการชำระเงินจริง
PromptPay รองรับ THB ไม่ใช่ USD ดังนั้นห้ามนำ checkout PromptPay เดิมมาใช้กับราคา USD
การรับชำระ USD ต้องเปลี่ยนเป็น Stripe card/วิธีชำระเงินที่รองรับ USD พร้อมสร้าง Edge Function และ webhook ที่ตรวจสอบจำนวนเงิน/สกุลเงิน USD และทดสอบใน test mode ก่อน
จนกว่าจะ deploy ส่วนนี้แล้ว ห้ามเปิดปุ่มซื้อด้วยเงินจริงใน USD

## 5) อัตราแลกเปลี่ยนที่อัปเดตอัตโนมัติ
Migration นี้บันทึกอัตราอ้างอิงตามวันที่เท่านั้น ยังไม่มีงาน scheduled updater
ก่อนเปิดใช้งานจริง ต้องเพิ่ม Edge Function ฝั่งเซิร์ฟเวอร์ที่ดึงอัตราจากแหล่งเชื่อถือได้, บันทึกเวลา/แหล่งที่มา, จัดการกรณี API ล่ม และกำหนดอายุข้อมูลสูงสุด ห้ามดึงอัตราจาก browser หรือ hardcode เป็นราคาปัจจุบัน

## 6) อัปเดตอัตรา USD/THB อัตโนมัติ (ต้องตั้งค่าก่อนใช้งาน)
มี Edge Function `refresh-fx-rates` และ GitHub Actions workflow `.github/workflows/refresh-fx.yml` แล้ว
- ใช้ ExchangeRate-API keyed endpoint ซึ่งเป็นอัตราอ้างอิงรายวัน ไม่ใช่ราคาซื้อขายแบบ tick-by-tick
- ต้องตรวจสอบแผน/สิทธิ์การใช้งานและการเผยแพร่ข้อมูลอัตราในแอปสาธารณะกับผู้ให้บริการก่อนเปิดใช้
- ตั้ง Supabase Edge Function Secrets: `EXCHANGERATE_API_KEY`, `FX_REFRESH_SECRET`
- ตั้ง GitHub repository Actions Secret ชื่อ `FX_REFRESH_SECRET` ให้เป็นค่าเดียวกัน
- Deploy: `supabase functions deploy refresh-fx-rates --no-verify-jwt --project-ref YOUR_PROJECT_REF`
- หลัง merge workflow เข้า default branch แล้ว Actions จะเรียกทุกวัน 02:17 UTC และสามารถกด Run workflow เองได้
- หาก secret/API key ไม่ครบ workflow จะ fail อย่างชัดเจน ไม่สร้างอัตราปลอม
- ระบบจะเก็บเวลาอัปเดตและเวลาที่ provider คาดว่าจะอัปเดตครั้งถัดไป พร้อมปฏิเสธข้อมูลเก่ากว่า 72 ชั่วโมง

## 7) สถานะส่วนติดต่อผู้ใช้
- หน้ารายละเอียดแปลงแยก "มูลค่าในระบบจำลอง (MLC)" ออกจาก "ราคาเสนอขาย (USD)" แล้ว
- หน้าจออ่าน `sale_price_usd` จาก `world_parcels` และแสดงเฉพาะแปลงที่เปิดขายและมีราคา USD เท่านั้น
- ปุ่มชำระเงินจริงถูกปิดไว้โดยตั้งใจ จนกว่าจะมี USD Checkout และ webhook ที่ตรวจสอบ currency/amount เป็น USD
- ฟังก์ชัน PromptPay เดิมถูกปิดใน world-server.js เพื่อป้องกันการส่งผู้ใช้ไปชำระ THB ระหว่างการย้ายระบบ
- MLC market ยังคงทำงานแยกจากราคา USD ตามเดิม
- เพิ่ม workflow `.github/workflows/validate-usd.yml` สำหรับตรวจ syntax JavaScript และไฟล์ migration ทุกครั้งที่ PR มีการเปลี่ยนแปลง

## 8) เปิดใช้งาน USD Checkout (ต้องทำครบก่อนเปิดขาย)
โค้ด USD Checkout และ webhook แยกจาก PromptPay เดิมแล้ว โดยใช้ Stripe card ในสกุล USD

1. สำรองฐานข้อมูล แล้วรัน SQL ตามลำดับ: migration 016 → 017 → 018
2. Deploy Edge Functions:
```bash
supabase functions deploy create-usd-checkout --project-ref YOUR_PROJECT_REF
supabase functions deploy stripe-webhook --no-verify-jwt --project-ref YOUR_PROJECT_REF
supabase functions deploy refresh-fx-rates --no-verify-jwt --project-ref YOUR_PROJECT_REF
```
3. ตั้ง Supabase secrets เดิมให้ครบ: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `MARS_OWNER_USER_ID`, `SITE_URL`, `SITE_ORIGIN`
4. ใช้ Stripe TEST secret key ก่อน และตั้ง webhook endpoint เดิมให้รับ `checkout.session.completed` กับ `checkout.session.async_payment_succeeded`
5. กำหนดราคา USD และเปิดขายเฉพาะแปลงที่ผ่านการตรวจแล้ว ตัวอย่างทดสอบ (ห้ามใช้เป็นราคาขายจริงโดยอัตโนมัติ):
```sql
update public.world_parcels
set sale_price_usd = 9.99, is_for_sale = true
where id = 'M-001';
``
6. ตรวจว่า UI แสดงราคา USD และปุ่มซื้อเปิดเฉพาะแปลงที่มีราคา USD และยังไม่มีเจ้าของ
7. ทดสอบจ่ายสำเร็จ, ยกเลิก, session หมดอายุ, webhook ซ้ำ, currency ผิด, amount ผิด และซื้อแปลงเดียวกันพร้อมกัน
8. ตรวจ `mars_usd_parcel_orders`, `world_claims`, `mars_owner_wallet_entries_usd` ว่ามีรายการเดียวและยอดตรงกัน

ข้อควรระวัง:
- migration 018 สร้างคำสั่งซื้อและ ledger USD แยกจากตาราง THB เดิม ไม่แก้ยอด THB เก่า
- Stripe Checkout รองรับ USD แต่การเปิดใช้จริงขึ้นกับการอนุมัติบัญชี/ประเภทธุรกิจและประเทศของบัญชี Stripe
- ปุ่มซื้อจะแสดงได้เมื่อแปลงมี `sale_price_usd` และ `is_for_sale=true`; การชำระจะสำเร็จได้ก็ต่อเมื่อ migrations/functions/secrets/webhook ถูก deploy ครบ
- รายได้สุทธิและการถอนยังไม่ถือว่าพร้อม เพราะต้อง reconcile ค่าธรรมเนียมและ payout จาก Stripe
- ราคาแปลงดาวอังคารเป็นราคาสินทรัพย์จำลอง/ราคาเสนอขายของแพลตฟอร์ม ไม่ใช่ราคาตลาดอสังหาริมทรัพย์จริงหรือกรรมสิทธิ์บนดาวอังคาร
