// admin-news — admin dashboard için CRUD + generate trigger
// Auth: x-admin-password header (Supabase secret: ADMIN_PASSWORD)
// Deploy: supabase functions deploy admin-news --no-verify-jwt --project-ref zxseytwpunjajypzrmmr
// Secret ekle: supabase secrets set ADMIN_PASSWORD=senin_sifren --project-ref ...

const SUPABASE_URL    = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY     = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY   = Deno.env.get("ANTHROPIC_API_KEY")!;
const ADMIN_PASSWORD  = Deno.env.get("ADMIN_PASSWORD") ?? "";

const sbHeaders = {
  "apikey": SERVICE_KEY,
  "Authorization": `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
  "Access-Control-Max-Age": "86400",
};

const json = (data: unknown, status = 200): Response =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// ── Routes ────────────────────────────────────────────────────────────────────

async function listDays(limit: number) {
  // Distinct dates with counts
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/news_items?select=date,id&order=date.desc&limit=${limit * 10}`,
    { headers: sbHeaders }
  );
  const rows = await r.json() as Array<{ date: string }>;
  const counts = new Map<string, number>();
  for (const row of rows) counts.set(row.date, (counts.get(row.date) ?? 0) + 1);
  const days = Array.from(counts.entries())
    .map(([date, count]) => ({ date, count }))
    .sort((a, b) => a.date < b.date ? 1 : -1)
    .slice(0, limit);
  return days;
}

async function listNewsForDate(date: string) {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/news_items?date=eq.${date}&select=id,topic_id,date,title,summary,body,source_urls,created_at&order=topic_id`,
    { headers: sbHeaders }
  );
  return r.json();
}

async function listTopics() {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/topics?order=sort_order&select=id,name,emoji,description`,
    { headers: sbHeaders }
  );
  return r.json();
}

async function createNews(row: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/news_items`, {
    method: "POST",
    headers: { ...sbHeaders, "Prefer": "return=representation" },
    body: JSON.stringify(row),
  });
  if (!r.ok) throw new Error(`Insert ${r.status}: ${await r.text()}`);
  return r.json();
}

async function updateNews(id: string, patch: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/news_items?id=eq.${id}`, {
    method: "PATCH",
    headers: { ...sbHeaders, "Prefer": "return=representation" },
    body: JSON.stringify(patch),
  });
  if (!r.ok) throw new Error(`Update ${r.status}: ${await r.text()}`);
  return r.json();
}

async function deleteNews(id: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/news_items?id=eq.${id}`, {
    method: "DELETE",
    headers: sbHeaders,
  });
  if (!r.ok) throw new Error(`Delete ${r.status}: ${await r.text()}`);
  return { ok: true };
}

// Trigger Claude generation for specific topic+date (overwrites if exists)
async function generateForTopic(topicId: string, dateStr: string) {
  // 1) get topic info
  const topicResp = await fetch(
    `${SUPABASE_URL}/rest/v1/topics?id=eq.${topicId}&select=name,description`,
    { headers: sbHeaders }
  );
  const topics = await topicResp.json() as Array<{ name: string; description: string }>;
  if (topics.length === 0) throw new Error("Topic bulunamadı");
  const topic = topics[0];

  // 2) call Claude with web_search
  const prompt = `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugünün tarihi: ${dateStr}.

GÖREV: "${topic.name}" alanında (${topic.description}) son 48 saatte yaşanan EN ÖNEMLİ ve DOĞRULANABİLİR gelişmeyi haber yaz.

SÜREÇ: web_search ile 2-3 arama yap, doğrulanabilir bilgileri kullan.

KESİN KURALLAR:
- Uydurma yasak. Sadece arama sonuçlarındakini yaz.
- Tarih, sayı, isim kesin olmalı.
- En az 1 GERÇEK kaynak URL'si zorunlu.
- Bulamazsan "no_news" dön.

ÇIKTI: SADECE bu JSON'lardan biri:
{ "title":"...","summary":"...","body":"P1\\n\\nP2\\n\\nP3","source_urls":["https://..."] }
veya { "no_news": true, "reason":"..." }`;

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 180_000);
  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      signal: ctrl.signal,
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 3000,
        tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 5 }],
        messages: [{ role: "user", content: prompt }],
      }),
    });
    if (!r.ok) throw new Error(`Anthropic ${r.status}: ${(await r.text()).slice(0, 300)}`);
    const data = await r.json();
    const blocks = (data?.content ?? []) as Array<{ type: string; text?: string }>;
    const text = blocks.filter(b => b.type === "text" && b.text).map(b => b.text).join("\n").trim();

    let depth = 0, start = -1, end = -1;
    for (let i = 0; i < text.length; i++) {
      if (text[i] === "{") { if (depth++ === 0) start = i; }
      else if (text[i] === "}") { if (--depth === 0) { end = i; break; } }
    }
    if (start === -1) throw new Error("JSON bulunamadı: " + text.slice(0, 200));
    const parsed = JSON.parse(text.slice(start, end + 1));

    if (parsed.no_news) {
      return { status: "no_news", reason: parsed.reason };
    }

    const sourceUrls = Array.isArray(parsed.source_urls)
      ? parsed.source_urls.filter((u: unknown) => typeof u === "string" && u.startsWith("http"))
      : [];

    if (sourceUrls.length === 0) throw new Error("Kaynak URL'si yok");

    // Upsert
    const existing = await fetch(
      `${SUPABASE_URL}/rest/v1/news_items?topic_id=eq.${topicId}&date=eq.${dateStr}&select=id`,
      { headers: sbHeaders }
    );
    const existingRows = await existing.json() as Array<{ id: string }>;

    const row = {
      topic_id: topicId,
      date: dateStr,
      title: String(parsed.title).slice(0, 200),
      summary: String(parsed.summary),
      body: String(parsed.body),
      source_urls: sourceUrls,
    };

    if (existingRows.length > 0) {
      const updated = await updateNews(existingRows[0].id, row);
      return { status: "updated", news: updated };
    } else {
      const created = await createNews(row);
      return { status: "created", news: created };
    }
  } finally {
    clearTimeout(timer);
  }
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Health check (no auth)
  const url = new URL(req.url);
  if (req.method === "GET" && url.searchParams.get("action") === "ping") {
    return json({ ok: true, configured: ADMIN_PASSWORD.length > 0 });
  }

  // Auth
  const password = req.headers.get("x-admin-password") ?? "";
  if (!ADMIN_PASSWORD || password !== ADMIN_PASSWORD) {
    return json({ error: "Unauthorized" }, 401);
  }

  const action = url.searchParams.get("action") ?? "";

  try {
    switch (action) {
      case "topics": {
        const topics = await listTopics();
        return json({ topics });
      }
      case "days": {
        const limit = parseInt(url.searchParams.get("limit") ?? "30");
        const days = await listDays(limit);
        return json({ days });
      }
      case "list": {
        const date = url.searchParams.get("date");
        if (!date) return json({ error: "date param zorunlu" }, 400);
        const news = await listNewsForDate(date);
        return json({ news });
      }
      case "create": {
        if (req.method !== "POST") return json({ error: "POST gerekli" }, 405);
        const body = await req.json();
        const created = await createNews(body);
        return json({ news: created });
      }
      case "update": {
        if (req.method !== "PATCH") return json({ error: "PATCH gerekli" }, 405);
        const id = url.searchParams.get("id");
        if (!id) return json({ error: "id param zorunlu" }, 400);
        const body = await req.json();
        const updated = await updateNews(id, body);
        return json({ news: updated });
      }
      case "delete": {
        if (req.method !== "DELETE") return json({ error: "DELETE gerekli" }, 405);
        const id = url.searchParams.get("id");
        if (!id) return json({ error: "id param zorunlu" }, 400);
        await deleteNews(id);
        return json({ ok: true });
      }
      case "generate": {
        if (req.method !== "POST") return json({ error: "POST gerekli" }, 405);
        const topicId = url.searchParams.get("topic_id");
        const dateStr = url.searchParams.get("date") ?? new Date().toISOString().slice(0, 10);
        if (!topicId) return json({ error: "topic_id param zorunlu" }, 400);
        const result = await generateForTopic(topicId, dateStr);
        return json(result);
      }
      default:
        return json({ error: `bilinmeyen action: ${action}` }, 400);
    }
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
