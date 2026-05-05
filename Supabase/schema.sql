-- =============================================================
-- marker. uygulaması – Supabase Schema
-- Run this in the Supabase SQL editor (Dashboard → SQL Editor)
-- =============================================================

-- ---------------------------------------------------------------
-- 1. TOPICS (sabit liste, admin tarafından populate edilir)
-- ---------------------------------------------------------------
create table if not exists public.topics (
  id          text primary key,
  name        text not null,
  emoji       text not null,
  description text,
  sort_order  int  not null default 0
);

-- ---------------------------------------------------------------
-- 2. NEWS ITEMS (her gün AI tarafından üretilen haberler)
-- ---------------------------------------------------------------
create table if not exists public.news_items (
  id           uuid primary key default gen_random_uuid(),
  topic_id     text not null references public.topics(id),
  date         date not null,
  title        text not null,
  summary      text not null,
  body         text not null,
  source_urls  jsonb not null default '[]',
  image_prompt text,
  created_at   timestamptz not null default now(),
  -- Her başlığa günde 1 haber garantisi
  unique(topic_id, date)
);

create index if not exists news_items_date_idx     on public.news_items(date desc);
create index if not exists news_items_topic_idx    on public.news_items(topic_id, date desc);

-- ---------------------------------------------------------------
-- 3. PROFILES (kullanıcı profili — auth.users ile 1:1)
-- ---------------------------------------------------------------
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  apple_user_id  text,
  is_premium     boolean   not null default false,
  delivery_time  time      not null default '08:00',
  timezone       text      not null default 'Europe/Istanbul',
  apns_token     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Auto-create profile on new auth user signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, apple_user_id)
  values (
    new.id,
    new.raw_user_meta_data->>'apple_user_id'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Auto-update updated_at
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------
-- 4. USER TOPICS (kullanıcının seçtiği başlıklar)
-- ---------------------------------------------------------------
create table if not exists public.user_topics (
  user_id  uuid not null references public.profiles(id) on delete cascade,
  topic_id text not null references public.topics(id),
  added_at timestamptz not null default now(),
  primary key (user_id, topic_id)
);

-- ---------------------------------------------------------------
-- 5. SAVED NEWS (kullanıcının kaydettiği haberler)
-- ---------------------------------------------------------------
create table if not exists public.saved_news (
  user_id  uuid not null references public.profiles(id) on delete cascade,
  news_id  uuid not null references public.news_items(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, news_id)
);

create index if not exists saved_news_user_idx on public.saved_news(user_id, saved_at desc);

-- ---------------------------------------------------------------
-- 6. ROW LEVEL SECURITY
-- ---------------------------------------------------------------

-- topics: herkes okuyabilir
alter table public.topics enable row level security;
create policy "topics_read_all" on public.topics for select using (true);

-- news_items: herkes okuyabilir
alter table public.news_items enable row level security;
create policy "news_read_all" on public.news_items for select using (true);

-- Edge Function'ın insert/update yapabilmesi için service_role bypass yeterli (RLS atlar)

-- profiles: sadece kendi kaydını görebilir/güncelleyebilir
alter table public.profiles enable row level security;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- user_topics: sadece kendi kayıtları
alter table public.user_topics enable row level security;
create policy "user_topics_select_own" on public.user_topics
  for select using (auth.uid() = user_id);
create policy "user_topics_insert_own" on public.user_topics
  for insert with check (auth.uid() = user_id);
create policy "user_topics_delete_own" on public.user_topics
  for delete using (auth.uid() = user_id);

-- saved_news: sadece kendi kayıtları
alter table public.saved_news enable row level security;
create policy "saved_news_select_own" on public.saved_news
  for select using (auth.uid() = user_id);
create policy "saved_news_insert_own" on public.saved_news
  for insert with check (auth.uid() = user_id);
create policy "saved_news_delete_own" on public.saved_news
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- 7. SEED: 10 TOPICS
-- ---------------------------------------------------------------
insert into public.topics (id, name, emoji, description, sort_order) values
  ('llms',        'LLMs',            '🧠', 'Large language models, GPT, Claude, Gemini ve benzerleri',      1),
  ('robotics',    'Robotics',        '🤖', 'AI destekli robotlar ve otomasyon sistemleri',                  2),
  ('research',    'AI Research',     '🔬', 'Akademik makaleler ve bilimsel atılımlar',                      3),
  ('safety',      'AI Safety',       '🛡️', 'Hizalama, etik ve sorumlu AI geliştirme',                      4),
  ('vision',      'Computer Vision', '👁️', 'Görüntü tanıma, video anlama, multimodal modeller',            5),
  ('tools',       'AI Tools',        '⚡', 'Yeni AI ürünleri ve geliştirici araçları',                      6),
  ('business',    'AI Business',     '💼', 'Yatırımlar, satın almalar ve pazar haberleri',                  7),
  ('policy',      'AI Policy',       '⚖️', 'Düzenleme, mevzuat ve AI yönetişimi',                          8),
  ('generative',  'Generative AI',   '🎨', 'Görüntü, video ve ses üretimi (Sora, Midjourney vb.)',          9),
  ('healthcare',  'AI Healthcare',   '🏥', 'Tıbbi AI, ilaç keşfi ve tanı sistemleri',                      10)
on conflict (id) do update
  set name = excluded.name,
      emoji = excluded.emoji,
      description = excluded.description,
      sort_order = excluded.sort_order;
