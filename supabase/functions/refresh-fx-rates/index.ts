// LOCAL MARS: server-only daily FX reference refresh.
// Requires a paid/authorized ExchangeRate-API key and a private scheduler secret.
// Never expose this function publicly or treat daily indicative FX as a settlement quote.
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const schedulerSecret = Deno.env.get("FX_REFRESH_SECRET");
  const suppliedSecret = req.headers.get("x-fx-refresh-secret");
  if (!schedulerSecret || !suppliedSecret || suppliedSecret !== schedulerSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const apiKey = Deno.env.get("EXCHANGERATE_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!apiKey || !supabaseUrl || !serviceKey) {
      return json({ error: "Missing server configuration" }, 503);
    }

    const response = await fetch(
      `https://v6.exchangerate-api.com/v6/${encodeURIComponent(apiKey)}/latest/USD`,
      { headers: { "Accept": "application/json" } },
    );
    if (!response.ok) return json({ error: "FX provider unavailable", provider_status: response.status }, 502);
    const payload = await response.json();
    const thb = Number(payload?.conversion_rates?.THB);
    const updatedUnix = Number(payload?.time_last_update_unix);
    const nextUnix = Number(payload?.time_next_update_unix);
    if (payload?.result !== "success" || payload?.base_code !== "USD" ||
        !Number.isFinite(thb) || thb <= 0 ||
        !Number.isFinite(updatedUnix) || !Number.isFinite(nextUnix)) {
      return json({ error: "Invalid FX provider response" }, 502);
    }

    const updatedAt = new Date(updatedUnix * 1000);
    const nextAt = new Date(nextUnix * 1000);
    const now = Date.now();
    if (updatedAt.getTime() > now + 5 * 60_000 || now - updatedAt.getTime() > 72 * 60 * 60_000) {
      return json({ error: "FX provider quote is stale or future-dated" }, 502);
    }
    const payloadDate = updatedAt.toISOString().slice(0, 10);
    const row = {
      base_currency: "USD",
      quote_currency: "THB",
      rate: thb,
      source: "ExchangeRate-API (authorized keyed endpoint; indicative daily reference)",
      observed_at: payloadDate,
      provider_updated_at: updatedAt.toISOString(),
      provider_next_update_at: nextAt.toISOString(),
      provider_payload_date: payloadDate,
    };

    const saved = await fetch(
      `${supabaseUrl}/rest/v1/mars_fx_rates?on_conflict=base_currency,quote_currency,observed_at`,
      {
        method: "POST",
        headers: {
          "apikey": serviceKey,
          "Authorization": `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
          "Prefer": "resolution=merge-duplicates,return=representation",
        },
        body: JSON.stringify(row),
      },
    );
    if (!saved.ok) {
      console.error("FX upsert failed", await saved.text());
      return json({ error: "Could not persist FX reference" }, 500);
    }
    return json({
      ok: true,
      base: "USD",
      quote: "THB",
      rate: thb,
      source: row.source,
      provider_updated_at: row.provider_updated_at,
      provider_next_update_at: row.provider_next_update_at,
      disclaimer: "Indicative daily reference only; not a live executable or settlement rate.",
    });
  } catch (error) {
    console.error("FX refresh failed", error);
    return json({ error: "FX refresh failed" }, 500);
  }
});
