import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://tordtaris.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function extractText(data: any): string {
  if (typeof data?.output_text === "string" && data.output_text.trim()) return data.output_text.trim();
  const parts: string[] = [];
  for (const item of data?.output ?? []) {
    if (item?.type !== "message") continue;
    for (const content of item?.content ?? []) {
      if ((content?.type === "output_text" || content?.type === "text") && typeof content?.text === "string") parts.push(content.text);
    }
  }
  return parts.join("\n").trim();
}

async function askProvider(provider: "grok" | "gpt", prompt: string, history: Array<{role:string;content:string}>) {
  const isGrok = provider === "grok";
  const key = Deno.env.get(isGrok ? "XAI_API_KEY" : "OPENAI_API_KEY");
  if (!key) return { ok: false, error: isGrok ? "XAI_API_KEY is not configured in Supabase secrets." : "OPENAI_API_KEY is not configured in Supabase secrets." };
  const model = Deno.env.get(isGrok ? "GROK_MODEL" : "GPT_MODEL") || (isGrok ? "grok-4.7" : "gpt-6.1-sol");
  const instructions = isGrok
    ? "You are Grok, one member of LOCAL MARS Dual AI. Give an independent, evidence-conscious answer. Clearly distinguish verified facts, assumptions, and simulation data. Never claim access to the user's device, account, files, or external systems unless supplied in this request."
    : "You are GPT, one member of LOCAL MARS Dual AI. Give an independent, careful answer. Clearly distinguish verified facts, assumptions, and simulation data. Never claim access to the user's device, account, files, or external systems unless supplied in this request.";
  const input = [
    { role: "system", content: instructions },
    ...history.slice(-8).map((m) => ({ role: m.role === "assistant" ? "assistant" : "user", content: String(m.content).slice(0, 4000) })),
    { role: "user", content: prompt },
  ];
  const response = await fetch(isGrok ? "https://api.x.ai/v1/responses" : "https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model, input, max_output_tokens: 1200 }),
    signal: AbortSignal.timeout(65000),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) return { ok: false, model, error: String(data?.error?.message || data?.message || `Provider request failed (${response.status})`).slice(0, 500) };
  const text = extractText(data);
  return text ? { ok: true, model, text } : { ok: false, model, error: "The provider returned no readable text." };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") || "";
  if (req.method === "OPTIONS") {
    if (origin !== "https://tordtaris.github.io") return new Response("Forbidden origin", { status: 403 });
    return new Response("ok", { headers: corsHeaders });
  }
  if (origin && origin !== "https://tordtaris.github.io") return json({ error: "Origin not allowed" }, 403);
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!req.headers.get("authorization")?.startsWith("Bearer ")) return json({ error: "Sign in to LOCAL MARS before using Dual AI." }, 401);
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body." }, 400); }
  const prompt = typeof body?.prompt === "string" ? body.prompt.trim() : "";
  const mode = body?.mode;
  if (!prompt || prompt.length > 5000) return json({ error: "Prompt must contain 1–5000 characters." }, 400);
  if (!["grok", "gpt", "both"].includes(mode)) return json({ error: "Mode must be grok, gpt, or both." }, 400);
  const history = Array.isArray(body?.history) ? body.history.filter((m: any) => m && ["user", "assistant"].includes(m.role) && typeof m.content === "string").slice(-8) : [];
  const providers = mode === "both" ? ["grok", "gpt"] : [mode];
  const settled = await Promise.all(providers.map(async (name) => {
    try { return [name, await askProvider(name, prompt, history)] as const; }
    catch (error) { return [name, { ok: false, error: error instanceof Error ? error.message : "Provider unavailable." }] as const; }
  }));
  const results = Object.fromEntries(settled);
  const successCount = Object.values(results).filter((r: any) => r.ok).length;
  return json({ results, partial: successCount > 0 && successCount < providers.length, success: successCount > 0 });
});
