// LOCAL MARS: create a one-time USD card Checkout Session.
const allowedOrigin = Deno.env.get("SITE_ORIGIN") ?? "https://tordtaris.github.io";
const cors = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const origin = req.headers.get("Origin");
  if (origin && origin !== allowedOrigin) return json({ error: "Origin not allowed" }, 403);
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    const stripeLivemode = Deno.env.get("STRIPE_LIVEMODE");
    const siteUrlRaw = Deno.env.get("SITE_URL");
    if (!supabaseUrl || !anonKey || !serviceKey || !stripeKey || !siteUrlRaw ||
        !["true", "false"].includes(stripeLivemode ?? "")) {
      return json({ error: "USD Checkout server configuration is incomplete" }, 503);
    }
    const expectedLive = stripeLivemode === "true";
    if ((expectedLive && !stripeKey.startsWith("sk_live_")) ||
        (!expectedLive && !stripeKey.startsWith("sk_test_"))) {
      return json({ error: "Stripe key mode does not match STRIPE_LIVEMODE" }, 503);
    }
    let siteUrl: URL;
    try { siteUrl = new URL(siteUrlRaw); } catch { return json({ error: "SITE_URL is invalid" }, 503); }
    if (siteUrl.protocol !== "https:") return json({ error: "SITE_URL must use HTTPS" }, 503);
    const siteBase = siteUrl.toString().replace(/\\/+$/, "");
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
    form.set("success_url", `${siteBase}/?payment=success&session_id={CHECKOUT_SESSION_ID}`);
    form.set("cancel_url", `${siteBase}/?payment=cancelled&order_id=${order.order_id}`);
    // Stripe requires at least 30 minutes remaining; migration 019 reserves 36 minutes in DB.
    form.set("expires_at", String(Math.floor(Date.now() / 1000) + 35 * 60));
    form.set("locale", "auto");
    form.set("client_reference_id", user.id);
    form.set("metadata[order_id]", order.order_id);
    form.set("metadata[parcel_id]", parcelId);
    form.set("metadata[buyer_id]", user.id);
    form.set("metadata[currency]", "usd");

    const stripeRes = await fetch("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
        "Idempotency-Key": `local-mars-usd-${order.order_id}`,
      },
      body: form,
    });
    const stripeText = await stripeRes.text();
    if (!stripeRes.ok) {
      console.error("Stripe USD Checkout create failed", stripeText);
      return json({ error: "Stripe ยังไม่สามารถสร้าง USD Checkout ได้ โปรดตรวจบัญชีและโหมดทดสอบ" }, 502);
    }
    const session = JSON.parse(stripeText);
    if (String(session.currency).toLowerCase() !== "usd" || !session.id || !session.url ||
        Boolean(session.livemode) !== expectedLive) {
      console.error("Stripe returned an unexpected Checkout Session", session.id, session.currency, session.livemode);
      return json({ error: "Stripe ส่งข้อมูลสกุลเงิน โหมด หรือ Checkout Session ไม่ถูกต้อง" }, 502);
    }
    const attachRes = await fetch(`${supabaseUrl}/rest/v1/rpc/mars_attach_usd_checkout_session`, {
      method: "POST", headers: rpcHeaders,
      body: JSON.stringify({ p_order_id: order.order_id, p_session_id: session.id, p_checkout_url: session.url }),
    });
    if (!attachRes.ok) {
      const attachError = await attachRes.text();
      console.error("Could not attach USD Checkout Session", attachError);
      // Best-effort cancellation prevents a buyer paying a session that is not linked to its order.
      const expireRes = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(session.id)}/expire`, {
        method: "POST", headers: { Authorization: `Bearer ${stripeKey}` },
      });
      if (!expireRes.ok) console.error("Could not expire unattached Stripe session", await expireRes.text());
      return json({ error: "บันทึกคำสั่งซื้อไม่สำเร็จ ระบบยกเลิกหน้าชำระที่สร้างไว้แล้ว โปรดลองอีกครั้ง" }, 503);
    }
    return json({ order_id: order.order_id, checkout_url: session.url, amount_cents: order.amount_cents, currency: "usd", expires_at: order.expires_at });
  } catch (error) {
    console.error(error);
    return json({ error: "เกิดข้อผิดพลาดในการสร้างคำสั่งซื้อ USD" }, 500);
  }
});
