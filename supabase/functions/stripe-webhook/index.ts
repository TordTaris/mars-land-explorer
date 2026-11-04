// LOCAL MARS: signed Stripe webhook. Deploy with --no-verify-jwt; Stripe signature is verified here.
const hex = (bytes: Uint8Array) => Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
async function verifyStripeSignature(payload: string, header: string, secret: string) {
  const parts = header.split(",").map((p) => p.split("=", 2));
  const timestamp = parts.find(([k]) => k === "t")?.[1];
  const signatures = parts.filter(([k]) => k === "v1").map(([, v]) => v);
  if (!timestamp || !signatures.length || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signed = new TextEncoder().encode(`${timestamp}.${payload}`);
  const digest = hex(new Uint8Array(await crypto.subtle.sign("HMAC", key, signed)));
  return signatures.some((sig) => {
    if (sig.length !== digest.length) return false;
    let diff = 0;
    for (let i = 0; i < sig.length; i++) diff |= sig.charCodeAt(i) ^ digest.charCodeAt(i);
    return diff === 0;
  });
}
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    const raw = await req.text();
    const signature = req.headers.get("Stripe-Signature") ?? "";
    const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
    if (!await verifyStripeSignature(raw, signature, webhookSecret)) {
      return new Response("Invalid Stripe signature", { status: 400 });
    }
    const event = JSON.parse(raw);
    if (!["checkout.session.completed", "checkout.session.async_payment_succeeded"].includes(event.type)) {
      return new Response(JSON.stringify({ received: true, ignored: true }), { status: 200 });
    }
    const session = event.data.object;
    if (session.payment_status !== "paid" || session.mode !== "payment") {
      return new Response(JSON.stringify({ received: true, awaiting_payment: true }), { status: 200 });
    }
    const orderId = session.metadata?.order_id;
    const ownerId = Deno.env.get("MARS_OWNER_USER_ID");
    if (!orderId || !ownerId || !session.id || !session.amount_total || !session.currency) {
      console.error("Missing order metadata or owner configuration", event.id);
      return new Response("Missing fulfillment metadata", { status: 400 });
    }
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const result = await fetch(`${supabaseUrl}/rest/v1/rpc/mars_fulfill_paid_order`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_event_id: event.id,
        p_event_type: event.type,
        p_order_id: orderId,
        p_session_id: session.id,
        p_payment_intent_id: typeof session.payment_intent === "string" ? session.payment_intent : null,
        p_amount_satang: session.amount_total,
        p_currency: session.currency,
        p_owner_id: ownerId,
      }),
    });
    const responseText = await result.text();
    if (!result.ok) {
      console.error("Fulfillment RPC failed", event.id, responseText);
      return new Response("Fulfillment failed; Stripe will retry", { status: 500 });
    }
    return new Response(JSON.stringify({ received: true, result: responseText }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(error);
    return new Response("Webhook processing error", { status: 500 });
  }
});
