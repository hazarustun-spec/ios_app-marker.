// generate-daily-news — web-search destekli, hallucination-guard'lı haber üretimi
// Deploy: supabase functions deploy generate-daily-news --no-verify-jwt --project-ref zxseytwpunjajypzrmmr
// Cron:   GitHub Actions her gün 06:00 İstanbul

const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

const sbHeaders = {
  "apikey": SUPABASE_KEY,
  "Authorization": `Bearer ${SUPABASE_KEY}`,
  "Content-Type": "application/json",
};

// ── Supabase REST ─────────────────────────────────────────────────────────────

async function getTopics() {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/topics?order=sort_order&select=id,name,description`,
    { headers: sbHeaders }
  );
  if (!r.ok) throw new Error(`Topics: ${r.status} ${await r.text()}`);
  return r.json() as Promise<{ id: string; name: string; description: string }[]>;
}

async function newsExists(topicId: string, date: string): Promise<boolean> {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/news_items?topic_id=eq.${topicId}&date=eq.${date}&select=id&limit=1`,
    { headers: sbHeaders }
  );
  if (!r.ok) return false;
  const rows = await r.json() as unknown[];
  return rows.length > 0;
}

async function insertNews(row: Record<string, unknown>): Promise<"inserted" | "duplicate"> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/news_items`, {
    method: "POST",
    headers: {
      ...sbHeaders,
      "Prefer": "resolution=ignore-duplicates,return=minimal",
    },
    body: JSON.stringify(row),
  });

  if (r.status === 201) return "inserted";
  if (r.status === 200 || r.status === 204 || r.status === 409) return "duplicate";
  throw new Error(`DB insert ${r.status}: ${await r.text()}`);
}

// ── JSON extractor ────────────────────────────────────────────────────────────

function extractJSON(text: string): Record<string, unknown> {
  let depth = 0, start = -1, end = -1;
  for (let i = 0; i < text.length; i++) {
    if (text[i] === "{") { if (depth++ === 0) start = i; }
    else if (text[i] === "}") { if (--depth === 0) { end = i; break; } }
  }
  if (start === -1 || end === -1) {
    throw new Error(`JSON bulunamadı. Model yanıtı: "${text.slice(0, 100)}"`);
  }
  return JSON.parse(text.slice(start, end + 1));
}

// ── Claude — web search + strict prompt ──────────────────────────────────────

type ClaudeResult =
  | { kind: "news"; title: string; summary: string; body: string; source_urls: string[] }
  | { kind: "no_news"; reason: string };

async function callClaude(name: string, desc: string, date: string): Promise<ClaudeResult> {
  const ctrl = new AbortController();
  // Web search çoklu sorgular yapabildiği için 180s timeout
  const timer = setTimeout(() => ctrl.abort(), 180_000);

  const prompt = `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugünün tarihi: ${date}.

GÖREV: "${name}" alanında (${desc}) son 48 saat içinde yaşanan EN ÖNEMLİ ve DOĞRULANABİLİR gelişmeyi haber yaz.

SÜREÇ:
1. web_search aracını kullanarak "${name}" konusunda son haberleri ara. 2-3 farklı sorgu yap (örn: "${name} announcement 2026", "${name} latest news").
2. Bulduğun gelişmelerden EN ÖNEMLİ ve EN GÜVENİLİR olanı seç (büyük yayın, primary source).
3. Sadece arama sonuçlarında DOĞRULAYABİLDİĞİN bilgileri kullanarak Türkçe haber yaz.

KESİN KURALLAR:
- ASLA bir gelişme uydurma. Sadece arama sonuçlarında gördüğünü yaz.
- "Muhtemelen", "olabilir", "tahminen" gibi spekülatif ifadeler YASAK.
- Tarih, sayı, isim, şirket adı kesin olmalı; emin değilsen ÇIKAR.
- Her haberde EN AZ 1, ideali 2-3 GERÇEK kaynak URL'si zorunlu (arama sonuçlarındaki linkler).
- Hiç gerçek/güncel haber bulamadıysan "no_news" döndür, uydurma haber yazma.

YAZIM:
- Akıcı, doğal Türkçe — makine çevirisi gibi durmasın
- İlk paragraf: ne oldu, kim yaptı, ne zaman, neden önemli
- "Bu gelişme dikkat çekiyor" gibi klişe dolgu yok
- 4-5 paragraf, her biri 3-4 cümle
- Olgusal, doğrudan, ilgi çekici ton

ÇIKTI: Sadece aşağıdaki JSON formatlarından BİRİNİ döndür. Markdown veya açıklama YAZMA.

Haber bulduysan:
{
  "title": "Başlık max 85 karakter",
  "summary": "2-3 cümlelik özet, okuyucu detay okumadan anlamalı",
  "body": "Paragraf 1\\n\\nParagraf 2\\n\\nParagraf 3\\n\\nParagraf 4",
  "source_urls": ["https://gerçek-url-1", "https://gerçek-url-2"]
}

Doğrulanabilir haber bulamadıysan:
{
  "no_news": true,
  "reason": "Son 48 saatte bu konuda doğrulanabilir gelişme bulunamadı"
}`;

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
        tools: [
          {
            type: "web_search_20250305",
            name: "web_search",
            // Anthropic tier-1 rate limit (30k input tokens/min) çoklu search
            // ile çabuk doluyor. 3 search yeterli (1 broad + 2 fokuslu) ve
            // tek çağrı başına input token kullanımını ~%40 düşürüyor.
            max_uses: 3,
          },
        ],
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!r.ok) {
      const errText = await r.text();
      throw new Error(`Anthropic ${r.status}: ${errText.slice(0, 300)}`);
    }

    const data = await r.json();

    // Web search kullandığında content array çoklu blok içerir.
    // Final text bloğu cevabımız.
    const blocks = (data?.content ?? []) as Array<{ type: string; text?: string }>;
    const textBlocks = blocks.filter((b) => b.type === "text" && b.text);
    if (textBlocks.length === 0) {
      throw new Error("Anthropic'ten metin yanıtı gelmedi");
    }
    const text = textBlocks.map((b) => b.text).join("\n").trim();

    const parsed = extractJSON(text);

    if (parsed.no_news === true) {
      return { kind: "no_news", reason: String(parsed.reason ?? "Bilinmeyen sebep") };
    }

    if (!parsed.title || !parsed.summary || !parsed.body) {
      throw new Error(`Eksik alan — title:${!!parsed.title} summary:${!!parsed.summary} body:${!!parsed.body}`);
    }

    const sourceUrls = Array.isArray(parsed.source_urls)
      ? parsed.source_urls.filter((u: unknown) => typeof u === "string" && u.startsWith("http"))
      : [];

    if (sourceUrls.length === 0) {
      throw new Error("Kaynak URL'si yok — haber reddedildi (hallucination guard)");
    }

    return {
      kind: "news",
      title: String(parsed.title),
      summary: String(parsed.summary),
      body: String(parsed.body),
      source_urls: sourceUrls,
    };
  } finally {
    clearTimeout(timer);
  }
}

// ── Ana handler ───────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return new Response(
      JSON.stringify({ status: "ok", anthropic_key_set: ANTHROPIC_KEY.length > 10 }),
      { headers: { "Content-Type": "application/json" } }
    );
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const today = new Date().toISOString().slice(0, 10);

  let body: { topic_id?: string } = {};
  try { body = await req.json(); } catch { /* boş body */ }

  let topic: { id: string; name: string; description: string } | undefined;

  try {
    const topics = await getTopics();

    if (body.topic_id) {
      topic = topics.find((t) => t.id === body.topic_id);
      if (!topic) {
        return new Response(
          JSON.stringify({ error: `'${body.topic_id}' bulunamadı` }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }
    } else {
      topic = topics[0];
    }
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Topics alınamadı: ${err}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  console.log(`[${today}] → ${topic.id} (${topic.name})`);

  if (await newsExists(topic.id, today)) {
    console.log(`  ⊘ zaten var, atlandı`);
    return new Response(
      JSON.stringify({ date: today, topic_id: topic.id, status: "duplicate" }),
      { headers: { "Content-Type": "application/json" } }
    );
  }

  // ── Üret ve kaydet ─────────────────────────────────────────────────────────
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const result = await callClaude(topic.name, topic.description, today);

      if (result.kind === "no_news") {
        console.log(`  ⊘ haber yok: ${result.reason}`);
        return new Response(
          JSON.stringify({ date: today, topic_id: topic.id, status: "no_news", reason: result.reason }),
          { headers: { "Content-Type": "application/json" } }
        );
      }

      const insertResult = await insertNews({
        topic_id:    topic.id,
        date:        today,
        title:       result.title.slice(0, 200),
        summary:     result.summary,
        body:        result.body,
        source_urls: result.source_urls,
      });

      console.log(`  ✓ ${insertResult} (deneme ${attempt}, ${result.source_urls.length} kaynak)`);
      return new Response(
        JSON.stringify({
          date: today,
          topic_id: topic.id,
          status: insertResult,
          sources: result.source_urls.length,
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    } catch (err) {
      console.error(`  ✗ deneme ${attempt}/2: ${err}`);
      if (attempt === 2) {
        return new Response(
          JSON.stringify({ date: today, topic_id: topic.id, status: "error", error: String(err) }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        );
      }
    }
  }

  return new Response("unreachable", { status: 500 });
});
