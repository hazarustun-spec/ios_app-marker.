// generate-daily-news — REAL news only via Claude + web_search.
// No placeholder/explainer fallbacks; if real verifiable news cannot be found
// after broad and narrow searches, the function fails (so reconciliation cron
// will retry later). Each insert has at least 1 real source URL.
//
// Deploy: supabase functions deploy generate-daily-news --no-verify-jwt --project-ref zxseytwpunjajypzrmmr

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
    headers: { ...sbHeaders, "Prefer": "resolution=ignore-duplicates,return=minimal" },
    body: JSON.stringify(row),
  });
  if (r.status === 201) return "inserted";
  if (r.status === 200 || r.status === 204 || r.status === 409) return "duplicate";
  throw new Error(`DB insert ${r.status}: ${await r.text()}`);
}

// Force=true durumunda mevcut row'u sil (yeni gerçek haber üzerine yazılsın)
async function deleteNewsForTopic(topicId: string, date: string): Promise<void> {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/news_items?topic_id=eq.${topicId}&date=eq.${date}`,
    { method: "DELETE", headers: sbHeaders }
  );
  if (!r.ok) throw new Error(`Delete ${r.status}: ${await r.text()}`);
}

// ── Claude structured output via tool_use ────────────────────────────────────

const ARTICLE_TOOL = {
  name: "publish_article",
  description: "Final haberi bu araç ile yayınla. Tüm alanlar zorunludur ve kaynak URL'leri gerçek olmalı.",
  input_schema: {
    type: "object",
    properties: {
      title:       { type: "string", description: "Başlık, max 85 karakter" },
      summary:     { type: "string", description: "2-3 cümlelik özet" },
      body:        { type: "string", description: "4-5 paragraf, paragraflar arasında \\n\\n" },
      source_urls: {
        type: "array",
        items: { type: "string" },
        description: "1-3 GERÇEK kaynak URL'si — sadece web_search sonuçlarındaki linkler",
        minItems: 1,
      },
    },
    required: ["title", "summary", "body", "source_urls"],
  },
};

type Article = {
  title: string;
  summary: string;
  body: string;
  source_urls: string[];
};

const sleep = (ms: number) => new Promise(res => setTimeout(res, ms));

async function callClaude(prompt: string, maxRetries = 2): Promise<Article> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 180_000);

  try {
    let lastErr: Error | null = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
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
            ARTICLE_TOOL,
            { type: "web_search_20250305", name: "web_search", max_uses: 4 },
          ],
          // NOT FORCED: Eğer Claude gerçek haber bulamazsa publish_article'ı
          // çağırmaması gerekir. Forced tool_choice dummy ("placeholder")
          // içerikle çağırmasına yol açıyordu.
          messages: [{ role: "user", content: prompt }],
        }),
      });

      // 429 — rate limit
      if (r.status === 429) {
        const retryAfter = r.headers.get("retry-after");
        const waitMs = retryAfter ? parseInt(retryAfter) * 1000 : 60_000 * attempt;
        console.log(`  ⏱  Anthropic 429, ${waitMs / 1000}s bekleniyor (${attempt}/${maxRetries})`);
        if (attempt < maxRetries) {
          await sleep(waitMs);
          continue;
        }
        throw new Error(`Anthropic 429 after ${maxRetries} retries`);
      }

      // 5xx — server error
      if (r.status >= 500) {
        const waitMs = 5_000 * attempt;
        console.log(`  ⚠️  Anthropic ${r.status}, ${waitMs / 1000}s bekleniyor`);
        if (attempt < maxRetries) {
          await sleep(waitMs);
          continue;
        }
      }

      if (!r.ok) {
        lastErr = new Error(`Anthropic ${r.status}: ${(await r.text()).slice(0, 300)}`);
        throw lastErr;
      }

      const data = await r.json();
      const blocks = (data?.content ?? []) as Array<{ type: string; name?: string; input?: any; text?: string }>;
      const toolUse = blocks.find(b => b.type === "tool_use" && b.name === "publish_article");

      if (!toolUse?.input) {
        const fallbackText = blocks.filter(b => b.type === "text").map(b => b.text).join("\n");
        lastErr = new Error(`Claude tool çağırmadı. Yanıt: "${fallbackText.slice(0, 200)}"`);
        if (attempt < maxRetries) continue;
        throw lastErr;
      }

      const article = toolUse.input as Article;
      if (!article.title || !article.summary || !article.body) {
        lastErr = new Error(`Eksik alan: title=${!!article.title} summary=${!!article.summary} body=${!!article.body}`);
        if (attempt < maxRetries) continue;
        throw lastErr;
      }

      // STRICT: gerçek URL zorunlu (placeholder/example/test domain'leri reddedilir)
      const FAKE_DOMAINS = ["example.com", "example.org", "placeholder.com", "test.com", "localhost"];
      const SENTINEL_WORDS = ["placeholder", "lorem ipsum", "test article", "dummy"];

      const validUrls = (article.source_urls || []).filter(u => {
        if (typeof u !== "string") return false;
        if (!(u.startsWith("http://") || u.startsWith("https://"))) return false;
        const lower = u.toLowerCase();
        return !FAKE_DOMAINS.some(fake => lower.includes(fake));
      });
      if (validUrls.length === 0) {
        lastErr = new Error("Hiç gerçek kaynak URL'si yok — reddedildi");
        if (attempt < maxRetries) continue;
        throw lastErr;
      }

      // Sentinel kelime kontrolü — Claude bazen dummy content üretebiliyor
      const combinedText = `${article.title} ${article.summary} ${article.body}`.toLowerCase();
      const hasSentinel = SENTINEL_WORDS.some(s => combinedText.includes(s));
      if (hasSentinel) {
        lastErr = new Error(`Dummy content tespit edildi (${SENTINEL_WORDS.find(s => combinedText.includes(s))}) — reddedildi`);
        if (attempt < maxRetries) continue;
        throw lastErr;
      }

      // Minimum length sanity check
      if (article.title.length < 15 || article.body.length < 200) {
        lastErr = new Error(`İçerik çok kısa (title=${article.title.length}, body=${article.body.length}) — reddedildi`);
        if (attempt < maxRetries) continue;
        throw lastErr;
      }

      return {
        title: String(article.title).slice(0, 200),
        summary: String(article.summary),
        body: String(article.body),
        source_urls: validUrls,
      };
    }
    throw lastErr ?? new Error("All retries failed");
  } finally {
    clearTimeout(timer);
  }
}

// ── 2-tier strategy: SPECIFIC topic news → BROADER topic news ────────────────
// Both tiers do web search. If both fail, we return error (reconciliation cron
// will retry next hour). We never insert without a real source URL.

async function generateRealArticle(name: string, desc: string, date: string): Promise<{ article: Article; tier: string }> {
  // Tier 1: topic'e spesifik gerçek haber, son 7 gün
  try {
    const article = await callClaude(buildSpecificPrompt(name, desc, date));
    return { article, tier: "specific" };
  } catch (err) {
    console.log(`  ⚠️  ${name}: tier-1 (specific) başarısız: ${err}. Tier-2'ye geçiliyor`);
  }

  // Tier 2: topic ile ilgili daha geniş gerçek haber, son 14 gün
  // (hâlâ web_search ile gerçek kaynak URL'si zorunlu)
  const article = await callClaude(buildBroaderPrompt(name, desc, date));
  return { article, tier: "broader" };
}

function buildSpecificPrompt(name: string, desc: string, date: string): string {
  return `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugün: ${date}.

GÖREV: "${name}" alanında (${desc}) son 7 gün içinde yaşanan ÖNEMLİ ve DOĞRULANABİLİR bir gelişmeyi haber olarak yaz.

SÜREÇ:
1. web_search ile 2-3 farklı sorgu yap. Türkçe + İngilizce.
   Örnek sorgular:
   - "${name} latest news 2026"
   - "${name} announcement this week"
   - "${name} ${date.substring(0, 7)}"
2. Bulduğun haberlerden EN ÖNEMLİ ve EN GÜVENİLİR olanı seç (büyük yayın, primary source).
3. publish_article aracını çağır.

KESİN KURALLAR:
- ASLA bilgi uydurma. Sadece arama sonuçlarındaki bilgileri yaz.
- Spekülatif ifadeler ("muhtemelen", "olabilir") YASAK.
- Tarihler, sayılar, isimler kesin olmalı.
- En az 1 gerçek kaynak URL'si zorunlu.
- Türkçe yaz, akıcı ve doğal (makine çevirisi gibi durmasın).
- 4-5 paragraf, her biri 3-4 cümle.

publish_article ile yayınla.`;
}

function buildBroaderPrompt(name: string, desc: string, date: string): string {
  return `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugün: ${date}.

GÖREV: "${name}" alanı (${desc}) ile ilgili son 14 gün içinde yaşanan herhangi bir ÖNEMLİ teknoloji haberini yaz.

ARAMA STRATEJİSİ:
- web_search ile 3-4 sorgu yap, GENİŞ tut.
- "${name}" yerine bu alana yakın yan konuları da ara (ör. healthcare için "AI medical", policy için "AI regulation").
- En son 14 gündeki herhangi bir önemli gelişme yeterli.

KURALLAR:
- Sadece arama sonuçlarındaki gerçek bilgileri yaz.
- En az 1 gerçek kaynak URL'si zorunlu.
- Spekülasyon yok.
- Türkçe, akıcı, 4 paragraf.

publish_article ile yayınla.`;
}

// ── Handler ───────────────────────────────────────────────────────────────────

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

  // "today" İstanbul timezone'a göre hesaplanır.
  // Bu, cron'un UTC 21:00'de (İstanbul 00:00) başlayıp ertesi günü doldurmasını sağlar.
  // GitHub Actions cron delay'leri için peak-time öncesi başlayabiliyoruz.
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Istanbul",
    year: "numeric", month: "2-digit", day: "2-digit"
  }).format(new Date());  // YYYY-MM-DD format (Canadian locale = ISO)

  let body: { topic_id?: string; force?: boolean } = {};
  try { body = await req.json(); } catch { /* boş body */ }

  // Query param desteği (?force=true)
  const url = new URL(req.url);
  const forceFlag = body.force === true || url.searchParams.get("force") === "true";

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

  console.log(`[${today}] → ${topic.id} (${topic.name})${forceFlag ? " [FORCE]" : ""}`);

  if (await newsExists(topic.id, today)) {
    if (forceFlag) {
      console.log(`  🔄 force=true, mevcut satır siliniyor`);
      await deleteNewsForTopic(topic.id, today);
    } else {
      console.log(`  ⊘ zaten var, atlandı`);
      return new Response(
        JSON.stringify({ date: today, topic_id: topic.id, status: "duplicate" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }
  }

  try {
    const { article, tier } = await generateRealArticle(topic.name, topic.description, today);

    const insertResult = await insertNews({
      topic_id:    topic.id,
      date:        today,
      title:       article.title,
      summary:     article.summary,
      body:        article.body,
      source_urls: article.source_urls,
    });

    console.log(`  ✓ ${insertResult} via ${tier} (${article.source_urls.length} kaynak)`);
    return new Response(
      JSON.stringify({
        date: today,
        topic_id: topic.id,
        status: insertResult,
        tier,
        sources: article.source_urls.length,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    // Real news bulunamadı — insert ATILMAZ. Reconciliation cron tekrar deneyecek.
    console.error(`  ✗ gerçek haber bulunamadı: ${err}`);
    return new Response(
      JSON.stringify({
        date: today,
        topic_id: topic.id,
        status: "error",
        error: String(err),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
