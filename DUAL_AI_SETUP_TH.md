# LOCAL MARS Dual AI — setup (Thai)

หน้า Dual AI อยู่ที่ `/dual-ai.html` และเรียก Supabase Edge Function ชื่อ `dual-ai` โดยต้องเข้าสู่ระบบ LOCAL MARS ก่อนใช้งาน

## ตั้งค่า API keys

1. เปิด Supabase Dashboard ของโปรเจกต์ LOCAL MARS
2. ไปที่ **Project Settings → Edge Functions → Secrets** (ชื่อเมนูอาจเปลี่ยนตามหน้าตา Dashboard)
3. เพิ่ม secrets ต่อไปนี้ โดยใส่ค่า API key จริงจากผู้ให้บริการ:
   - `XAI_API_KEY` — xAI API key สำหรับ Grok
   - `OPENAI_API_KEY` — OpenAI API key สำหรับ GPT
4. (ไม่บังคับ) เพิ่ม `GROK_MODEL=grok-4.7` และ `GPT_MODEL=gpt-6.1-sol` เพื่อกำหนดโมเดลเอง
5. เปิด LOCAL MARS แล้วเข้าสู่ระบบ จากนั้นเลือก **More → GROK × GPT · DUAL AI**

**ความปลอดภัย:** ห้ามใส่ API keys ใน `index.html`, `dual-ai.html`, JavaScript ฝั่งเบราว์เซอร์, GitHub หรือแชตสาธารณะ ให้เก็บไว้ใน Supabase Edge Function Secrets เท่านั้น

## ขอบเขตการทำงาน

- `Grok only`: ส่ง prompt ไป xAI
- `GPT only`: ส่ง prompt ไป OpenAI
- `Grok + GPT`: เรียกทั้งสองผู้ให้บริการพร้อมกันและแสดงคำตอบแยกกันเพื่อเปรียบเทียบ
- ต้องมีสมาชิกที่เข้าสู่ระบบแล้ว (JWT verification เปิดใช้งาน)
- จำกัด prompt 5,000 ตัวอักษร และส่งประวัติสนทนาล่าสุดไม่เกิน 8 ข้อความ
- การเรียก API อาจมีค่าใช้จ่ายตามบัญชี xAI และ OpenAI ของเจ้าของ API keys

หากยังไม่ได้เพิ่ม secrets ระบบจะตอบกลับด้วยข้อความแจ้งว่า provider key ยังไม่ได้ตั้งค่า ไม่ได้หมายความว่า API เชื่อมต่อสำเร็จแล้ว
