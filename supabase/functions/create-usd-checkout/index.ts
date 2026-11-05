// LOCAL MARS: create a one-time USD card Checkout Session.
const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("SITE_ORIGIN") ?? "https://tordtaris.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    const siteUrl = Deno.env.get("SITE_URL");
    if (!supabaseUrl || !anonKey || !serviceKey || !stripeKey || !siteUrl) {
      return json({ error: "USD Checkout server configuration is incomplete" }, 503);
    }
    const auth = req.headers.get("Authorization") ?? "";
    if (!auth.startsWith("Bearer ")) return json({ error: "กรุณาเข้าสู่ระบบก่อนซื้อพื้นที่" }, 401);
    const userRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: anonKey, Authorization: auth },
    });
    if (!userRes.ok) return json({ error: "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่" }, 401);
    const user = await userRes.json();
    const body = await req.json();
    const parcelId = String(body.parcel_id ?? "").trim();
    if (!/^[A-Za-z0-9-]{2,32}$/.test(parcelId)) return json({ error: "รหัสแปลงไม่ถูกต้อง" }, 400);

    const rpcHeaders = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" };
    const orderRes = await fetch(`${supabaseUrl}/rest/v1/rpc/mars_create_usd_parcel_order`, {
      method: "POST", headers: rpcHeaders,
      body: JSON.stringify({ p_buyer_id: user.id, p_parcel_id: parcelId }),
    });
    const orderText = await orderRes.text();
    if (!orderRes.ok) return json({ error: orderText || "ไม่สามารถสร้างคำสั่งซื้อ USD ได้" }, 409);
    const order = JSON.parse(orderText);
    if (String(order.currency).toLowerCase() !== "usd" || !Number.isSafeInteger(Number(order.amount_cents)) || Number(order.amount_cents) <= 0) {
      console.error("USD order RPC returned invalid amount/currency", order.order_id);
      return json({ error: "คำสั่งซื้อ USD มีจำนวนเงินหรือสกุลเงินไม่ถูกต้อง" }, 502);
    }
    const form = new URLSearchParams();
    form.set("mode", "payment");
    form.set("payment_method_types[0]", "card");
    form.set("line_items[0][quantity]", "1");
    form.set("line_items[0][price_data][currency]", "usd");
    form.set("line_items[0][price_data][unit_amount]", String(order.amount_cents));
    form.set("line_items[0][price_data][product_data][name]", `LOCAL MARS Virtual Parcel ${parcelId}`);
    form.set("line_items[0][price_data][product_data][description]", "Virtual simulation access only; not real-world land ownership.");
    form.set("success_url", `${siteUrl}/?payment=success&session_id={CHECKOUT_SESSION_ID}`);
    form.set("cancel_url", `${siteUrl}/?payment=cancelled&order_id=${order.order_id}`);
    form.set("expires_at", String(Math.floor(Date.now() / 1000) + 30 * 60));
    form.set("locale", "auto");
    form.set("client_reference_id", user.id);
    form.set("metadata[order_id]", order.order_id);
    form.set("metadata[parcel_id]", parcelId);
    form.set("metadata[buyer_id]", user.id);
    form.set("metadata[currency]", "usd");

    const stripeRes = await fetch("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: { Authorization: `Bearer ${stripeKey}`, "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    const stripeText = await stripeRes.text();
    if (!stripeRes.ok) {
      console.error("Stripe USD Checkout create failed", stripeText);
      return json({ error: "Stripe ยังไม่สามารถสร้าง USD Checkout ได้ โปรดตรวจบัญชีและโหมดทดสอบ" }, 502);
    }
    const session = JSON.parse(stripeText);
    if (String(session.currency).toLowerCase() !== "usd" || !session.id || !session.url) {
      console.error("Stripe returned an unexpected Checkout Session", session.id, session.currency);
      return json({ error: "Stripe ส่งข้อมูลสกุลเงินหรือ Checkout Session ไม่ถูกต้อง" }, 502);
    }
    const attachRes = await fetch(`${supabaseUrl}/rest/v1/rpc/mars_attach_usd_checkout_session`, {
      method: "POST", headers: rpcHeaders,
      body: JSON.stringify({ p_order_id: order.order_id, p_session_id: session.id, p_checkout_url: session.url }),
    });
    if (!attachRes.ok) {
      console.error("Could not attach USD Checkout Session", await attachRes.text());
      return json({ error: "สร้างหน้าชำระ USD แล้ว แต่บันทึกคำสั่งซื้อไม่สำเร็จ" }, 500);
    }
    return json({ order_id: order.order_id, checkout_url: session.url, amount_cents: order.amount_cents, currency: "usd", expires_at: order.expires_at });
  } catch (error) {
    console.error(error);
    return json({ error: "เกิดข้อผิดพลาดในการสร้างคำสั่งซื้อ USD" }, 500);
  }
});
