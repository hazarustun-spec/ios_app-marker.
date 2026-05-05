// generate-daily-news — bulletproof generation with structured output + fallback
// Deploy: supabase functions deploy generate-daily-news --no-verify-jwt --project-ref zxseytwpunjajypzrmmr
//
// Robustness layers:
//  1. Structured output (Claude tool_use) → guaranteed valid JSON
//  2. Two-pass strategy: news_search → if insufficient, evergreen_analysis
//  3. Final fallback: write a topic explainer using model knowledge (no web)

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

// ── Claude structured output via tool_use ────────────────────────────────────

const ARTICLE_TOOL = {
  name: "publish_article",
  description: "Final haberi bu araç ile yayınla. Tüm alanlar zorunludur.",
  input_schema: {
    type: "object",
    properties: {
      title:       { type: "string", description: "Başlık, max 85 karakter" },
      summary:     { type: "string", description: "2-3 cümlelik özet" },
      body:        { type: "string", description: "4-5 paragraf, paragraflar arasında \\n\\n" },
      source_urls: {
        type: "array",
        items: { type: "string" },
        description: "1-3 gerçek kaynak URL'si (web_search sonuçlarındaki)",
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

// Sleep helper for rate limit recovery
const sleep = (ms: number) => new Promise(res => setTimeout(res, ms));

async function callClaude(
  prompt: string,
  options: { useWebSearch: boolean; maxRetries: number }
): Promise<Article> {
  const tools: any[] = [ARTICLE_TOOL];
  if (options.useWebSearch) {
    tools.push({
      type: "web_search_20250305",
      name: "web_search",
      max_uses: 3,
    });
  }

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 180_000);

  let lastErr: Error | null = null;

  try {
    for (let attempt = 1; attempt <= options.maxRetries; attempt++) {
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
          tools,
          tool_choice: { type: "tool", name: "publish_article" },
          messages: [{ role: "user", content: prompt }],
        }),
      });

      // Rate limit handling — read retry-after header if available
      if (r.status === 429) {
        const retryAfter = r.headers.get("retry-after");
        const waitMs = retryAfter ? parseInt(retryAfter) * 1000 : 60_000 * attempt;
        console.log(`  ⏱  Anthropic 429, ${waitMs / 1000}s bekleniyor (attempt ${attempt}/${options.maxRetries})`);
        if (attempt < options.maxRetries) {
          await sleep(waitMs);
          continue;
        }
        throw new Error(`Anthropic 429 after ${options.maxRetries} retries`);
      }

      if (r.status >= 500) {
        // Server error → exponential backoff
        const waitMs = 5_000 * attempt;
        console.log(`  ⚠️  Anthropic ${r.status}, ${waitMs / 1000}s bekleniyor`);
        if (attempt < options.maxRetries) {
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
        // Sometimes model bails out without calling the tool
        const fallbackText = blocks.filter(b => b.type === "text").map(b => b.text).join("\n");
        lastErr = new Error(`Claude tool çağrısı yapmadı. Yanıt: "${fallbackText.slice(0, 200)}"`);
        if (attempt < options.maxRetries) continue;
        throw lastErr;
      }

      const article = toolUse.input as Article;
      // Validate
      if (!article.title || !article.summary || !article.body) {
        lastErr = new Error(`Eksik alan: title=${!!article.title} summary=${!!article.summary} body=${!!article.body}`);
        if (attempt < options.maxRetries) continue;
        throw lastErr;
      }
      const validUrls = (article.source_urls || []).filter(u => typeof u === "string" && u.startsWith("http"));
      return {
        title: String(article.title).slice(0, 200),
        summary: String(article.summary),
        body: String(article.body),
        source_urls: validUrls,
      };
    }
    throw lastErr ?? new Error("Tüm denemeler başarısız");
  } finally {
    clearTimeout(timer);
  }
}

// ── 3 katmanlı içerik üretim stratejisi ──────────────────────────────────────

async function generateArticle(name: string, desc: string, date: string): Promise<{ article: Article; mode: string }> {
  // Strateji 1: Web search ile gerçek haber
  try {
    const article = await callClaude(buildNewsSearchPrompt(name, desc, date), {
      useWebSearch: true,
      maxRetries: 2,
    });
    if (article.source_urls.length > 0) {
      return { article, mode: "news_search" };
    }
    console.log(`  ⚠️  ${name}: web_search bitti ama URL yok, evergreen mode'a geçiyor`);
  } catch (err) {
    console.log(`  ⚠️  ${name}: news_search başarısız (${err}), evergreen mode'a geçiyor`);
  }

  // Strateji 2: Web search ile evergreen analiz (haber yoksa "şu hafta sektör nasıl gidiyor")
  try {
    const article = await callClaude(buildEvergreenPrompt(name, desc, date), {
      useWebSearch: true,
      maxRetries: 2,
    });
    return { article, mode: "evergreen_search" };
  } catch (err) {
    console.log(`  ⚠️  ${name}: evergreen_search başarısız (${err}), knowledge mode'a geçiyor`);
  }

  // Strateji 3: Web olmadan model bilgisinden açıklayıcı yazı (last resort)
  const article = await callClaude(buildExplainerPrompt(name, desc, date), {
    useWebSearch: false,
    maxRetries: 2,
  });
  return { article, mode: "explainer_no_web" };
}

function buildNewsSearchPrompt(name: string, desc: string, date: string): string {
  return `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugünün tarihi: ${date}.

GÖREV: "${name}" alanında (${desc}) son 7 gün içinde yaşanan EN ÖNEMLİ ve DOĞRULANABİLİR gelişmeyi haber yaz.

SÜREÇ:
1. web_search ile 2-3 sorgu yap. Türkçe ve İngilizce ara.
2. Bulduğun en güvenilir haberi seç.
3. publish_article aracını çağır.

KESİN KURALLAR:
- Sadece arama sonuçlarındaki bilgileri yaz.
- Spekülatif ifadeler ("muhtemelen", "olabilir") YASAK.
- En az 1 GERÇEK kaynak URL'si zorunlu.

YAZIM:
- Akıcı, doğal Türkçe (makine çevirisi gibi durmasın)
- 4-5 paragraf, her biri 3-4 cümle
- Body'de paragraflar arası "\\n\\n"

publish_article ile JSON formatında yayınla.`;
}

function buildEvergreenPrompt(name: string, desc: string, date: string): string {
  return `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugünün tarihi: ${date}.

GÖREV: "${name}" alanında (${desc}) son haftaların öne çıkan TRENDİNİ veya BAĞLAM YAZISI'nı hazırla.

Bugün için spesifik gündem haberi olmasa bile okuyucuya değer sunacak bir analiz yaz:
- Bu alanda son 1-2 hafta içindeki birden fazla gelişmenin özeti
- Veya: bir önemli oyuncunun yol haritası
- Veya: sektörün şu anki durumu

SÜREÇ:
1. web_search ile 2 sorgu yap.
2. Bulduğun bilgileri sentezle.
3. publish_article aracıyla yayınla.

KURALLAR:
- En az 1 GERÇEK kaynak URL'si zorunlu.
- Spekülatif ifadeler yasak.
- Türkçe, akıcı, 4 paragraf.

publish_article ile yayınla.`;
}

function buildExplainerPrompt(name: string, desc: string, date: string): string {
  return `Sen deneyimli bir Türk teknoloji gazetecisisin. Bugünün tarihi: ${date}.

GÖREV: "${name}" alanı (${desc}) hakkında okuyucuya değer sunan bir AÇIKLAYICI yazı hazırla.

Web araması yapamadığın için kendi bilgine güvenerek:
- Bu alanın tanımı, neden önemli olduğu
- Ana oyuncular ve teknolojiler (eğitim verilerine kadar)
- Mevcut durumunu ve önümüzdeki yön
- 4 paragraf, her biri 3-4 cümle

ÖNEMLİ:
- Spesifik tarihler veya sayılar yazma (doğrulayamayız).
- "Son haftada", "şu anda gerçekleşen" gibi güncel ifadeler kullanma.
- source_urls listesini boş bırak ([]).

publish_article aracıyla yayınla.`;
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

  // 3 katmanlı strateji denenir; en az birisi mutlaka başarılı olur
  try {
    const { article, mode } = await generateArticle(topic.name, topic.description, today);

    const insertResult = await insertNews({
      topic_id:    topic.id,
      date:        today,
      title:       article.title,
      summary:     article.summary,
      body:        article.body,
      source_urls: article.source_urls,
    });

    console.log(`  ✓ ${insertResult} via ${mode} (${article.source_urls.length} kaynak)`);
    return new Response(
      JSON.stringify({
        date: today,
        topic_id: topic.id,
        status: insertResult,
        mode,
        sources: article.source_urls.length,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error(`  ✗ tüm stratejiler başarısız: ${err}`);
    return new Response(
      JSON.stringify({ date: today, topic_id: topic.id, status: "error", error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
