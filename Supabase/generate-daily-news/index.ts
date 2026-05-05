// Supabase Edge Function: generate-daily-news
// Deploy: supabase functions deploy generate-daily-news
// Cron:   supabase functions deploy --schedule "0 3 * * *" generate-daily-news
//         (06:00 Istanbul = 03:00 UTC)
//
// Required secrets:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.27";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY")!,
});

interface NewsOutput {
  title: string;
  summary: string;
  body: string;
  source_urls: string[];
}

interface Topic {
  id: string;
  name: string;
  description: string;
}

async function generateNewsForTopic(topic: Topic, date: string): Promise<NewsOutput> {
  const prompt = `You are an AI news journalist. Today is ${date}.

Report on the single most important AI development in the "${topic.name}" category (${topic.description}) from the last 24 hours.

Requirements:
- Focus on real, verifiable events
- Be specific (name companies, models, papers, people)
- Avoid speculation or filler

Respond ONLY with valid JSON matching this exact schema:
{
  "title": "Concise, specific headline (max 90 chars)",
  "summary": "2-3 sentence TL;DR for busy readers",
  "body": "4-5 paragraph detailed article. Each paragraph separated by \\n\\n.",
  "source_urls": ["url1", "url2"]
}`;

  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1500,
    tools: [
      {
        type: "web_search_20250305",
        name: "web_search",
        max_uses: 3,
      } as never,
    ],
    messages: [{ role: "user", content: prompt }],
  });

  // Extract the final text block (after any tool use)
  const textBlock = response.content
    .filter((b) => b.type === "text")
    .pop();

  if (!textBlock || textBlock.type !== "text") {
    throw new Error(`No text response for topic ${topic.id}`);
  }

  // Strip markdown code fences if present
  const raw = textBlock.text.replace(/```(?:json)?\n?/g, "").trim();
  return JSON.parse(raw) as NewsOutput;
}

Deno.serve(async (req) => {
  // Allow manual POST trigger (e.g. for testing)
  // Cron trigger also uses POST
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  console.log(`Generating news for ${today}...`);

  // Fetch all topics
  const { data: topics, error: topicsErr } = await supabase
    .from("topics")
    .select("id, name, description")
    .order("sort_order");

  if (topicsErr || !topics) {
    console.error("Failed to fetch topics:", topicsErr);
    return new Response(JSON.stringify({ error: "Failed to fetch topics" }), {
      status: 500,
    });
  }

  const results: { topic_id: string; status: "ok" | "error"; error?: string }[] = [];

  // Generate news for each topic in parallel (with concurrency limit)
  const CONCURRENCY = 3;
  for (let i = 0; i < topics.length; i += CONCURRENCY) {
    const batch = topics.slice(i, i + CONCURRENCY);

    await Promise.all(
      batch.map(async (topic: Topic) => {
        try {
          const news = await generateNewsForTopic(topic, today);

          const { error: insertErr } = await supabase.from("news_items").insert({
            topic_id: topic.id,
            date: today,
            title: news.title,
            summary: news.summary,
            body: news.body,
            source_urls: news.source_urls,
          });

          if (insertErr) {
            // unique(topic_id, date) violation = already generated today, skip
            if (insertErr.code === "23505") {
              console.log(`Already generated for ${topic.id} on ${today}, skipping.`);
              results.push({ topic_id: topic.id, status: "ok" });
            } else {
              throw insertErr;
            }
          } else {
            console.log(`✓ ${topic.id}`);
            results.push({ topic_id: topic.id, status: "ok" });
          }
        } catch (err) {
          console.error(`✗ ${topic.id}:`, err);
          results.push({ topic_id: topic.id, status: "error", error: String(err) });
        }
      })
    );
  }

  const ok = results.filter((r) => r.status === "ok").length;
  const failed = results.filter((r) => r.status === "error").length;
  console.log(`Done: ${ok} ok, ${failed} failed`);

  return new Response(
    JSON.stringify({ date: today, results, ok, failed }),
    { headers: { "Content-Type": "application/json" } }
  );
});
