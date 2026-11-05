// LOCAL MARS: signed Stripe webhook. Deploy with --no-verify-jwt; verify signatures and mode here.
const hex = (bytes: Uint8Array) => Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
async function verifyStripeSignature(payload: string, header: string, secret: string) {
  const parts = header.split(",").map((p) => p.split("=", 2));
  const timestamp = parts.find(([k]) => k === "t")?.[1];
  const signatures = parts.filter(([k]) => k === "v1").map(([, v]) => v);
  const timestampNumber = Number(timestamp);
  if (!timestamp || !Number.isFinite(timestampNumber) || !signatures.length ||
      Math.abs(Date.now() / 1000 - timestampNumber) > 300) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signed = new TextEncoder().encode(`${timestamp}.${payload}`);
  const digest = hex(new Uint8Array(await crypto.subtle.sign("HMAC", key, signed)));
  return signatures.some((sig) => {
    if (!/^[a-f0-9]{64}$/i.test(sig) || sig.length !== digest.length) return false;
    let diff = 0;
    for (let i = 0; i < sig.length; i++) diff |= sig.charCodeAt(i) ^ digest.charCodeAt(i);
    return diff === 0;
  });
}
const reply = (body: string, status = 200) =>
  new Response(body, { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply("Method not allowed", 405);
  try {
    const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
    const expectedMode = Deno.env.get("STRIPE_LIVEMODE");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!webhookSecret || !supabaseUrl || !serviceKey ||
        !["true", "false"].includes(expectedMode ?? "")) {
      console.error("Stripe webhook server configuration is incomplete");
      return reply("Webhook server configuration is incomplete", 503);
    }

    const raw = await req.text();
    const signature = req.headers.get("Stripe-Signature") ?? "";
    if (!await verifyStripeSignature(raw, signature, webhookSecret)) {
      return reply("Invalid Stripe signature", 400);
    }
    const event = JSON.parse(raw);
    if (typeof event.id !== "string" || typeof event.type !== "string" ||
        typeof event.livemode !== "boolean") return reply("Invalid Stripe event", 400);
    const expectedLive = expectedMode === "true";
    if (event.livemode !== expectedLive) {
      console.error("Stripe event mode mismatch", event.id, event.livemode, expectedLive);
      return reply("Stripe event mode mismatch", 400);
    }

    const session = event.data?.object;
    if (!session || session.object !== "checkout.session") {
      return reply(JSON.stringify({ received: true, ignored: true }));
    }

    // Record expired/failed USD sessions so the parcel reservation can be released cleanly.
    if (["checkout.session.expired", "checkout.session.async_payment_failed"].includes(event.type)) {
      const currency = String(session.currency ?? "").toLowerCase();
      const orderId = session.metadata?.order_id;
      if (currency !== "usd" || !orderId || !session.id) {
        return reply(JSON.stringify({ received: true, ignored: true }));
      }
      const status = event.type === "checkout.session.expired" ? "expired" : "failed";
      const result = await fetch(`${supabaseUrl}/rest/v1/rpc/mars_mark_usd_order_status`, {
        method: "POST",
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          p_event_id: event.id, p_event_type: event.type, p_order_id: orderId,
          p_session_id: session.id, p_status: status,
        }),
      });
      const body = await result.text();
      if (!result.ok) {
        console.error("Could not update USD order lifecycle", event.id, body);
        return reply("Order lifecycle update failed; Stripe will retry", 500);
      }
      return reply(JSON.stringify({ received: true, result: body }));
    }

    if (!["checkout.session.completed", "checkout.session.async_payment_succeeded"].includes(event.type)) {
      return reply(JSON.stringify({ received: true, ignored: true }));
    }
    if (session.payment_status !== "paid" || session.mode !== "payment") {
      return reply(JSON.stringify({ received: true, awaiting_payment: true }));
    }

    const orderId = session.metadata?.order_id;
    const ownerId = Deno.env.get("MARS_OWNER_USER_ID");
    if (!orderId || !ownerId || !session.id || !Number.isSafeInteger(session.amount_total) ||
        session.amount_total <= 0 || !session.currency) {
      console.error("Missing order metadata or owner configuration", event.id);
      return reply("Missing fulfillment metadata", 503);
    }
    const currency = String(session.currency).toLowerCase();
    const rpcName = currency === "usd"
      ? "mars_fulfill_paid_order_usd"
      : currency === "thb" ? "mars_fulfill_paid_order" : null;
    if (!rpcName) {
      console.error("Unsupported Checkout currency", event.id, currency);
      return reply("Unsupported Checkout currency", 400);
    }
    const paymentIntentId = typeof session.payment_intent === "string"
      ? session.payment_intent
      : session.payment_intent?.id ?? null;
    const fulfillmentPayload = {
      p_event_id: event.id,
      p_event_type: event.type,
      p_order_id: orderId,
      p_session_id: session.id,
      p_payment_intent_id: paymentIntentId,
      p_currency: currency,
      p_owner_id: ownerId,
      ...(currency === "usd"
        ? { p_amount_cents: session.amount_total }
        : { p_amount_satang: session.amount_total }),
    };
    const result = await fetch(`${supabaseUrl}/rest/v1/rpc/${rpcName}`, {
      method: "POST",
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(fulfillmentPayload),
    });
    const responseText = await result.text();
    if (!result.ok) {
      console.error("Fulfillment RPC failed", event.id, responseText);
      return reply("Fulfillment failed; Stripe will retry", 500);
    }
    return reply(JSON.stringify({ received: true, result: responseText }));
  } catch (error) {
    console.error("Stripe webhook processing error", error);
    return reply("Webhook processing error", 500);
  }
});
