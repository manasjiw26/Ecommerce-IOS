-- Price watchlist & stock alerts
create table if not exists watchlist (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  product_id int not null,
  threshold_price numeric,
  type text default 'price_alert', -- 'price_alert' | 'stock_alert'
  created_at timestamptz default now()
);

-- Flash deals
create table if not exists deals (
  id uuid primary key default gen_random_uuid(),
  product_id int not null,
  discount_pct int not null,
  expires_at timestamptz not null,
  is_active boolean default true
);

-- Promotions / promo codes
create table if not exists promotions (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  description text,
  discount_pct int,
  discount_fixed numeric,
  expires_at timestamptz,
  is_active boolean default true
);

-- Chatbot feedback (thumbs up/down)
create table if not exists chatbot_feedback (
  id uuid primary key default gen_random_uuid(),
  device_id text,
  message_text text,
  rating int check (rating in (1, -1)),
  created_at timestamptz default now()
);

-- Returns
create table if not exists returns (
  id uuid primary key default gen_random_uuid(),
  order_id text not null,
  payment_id text not null,
  reason text,
  status text default 'Pending',
  created_at timestamptz default now()
);

-- User loyalty points
create table if not exists user_points (
  user_id text primary key,
  points int default 0,
  updated_at timestamptz default now()
);

-- Product reviews
create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  product_id int not null,
  user_id text not null,
  rating int check (rating between 1 and 5),
  body text,
  created_at timestamptz default now()
);

-- Add gift fields to orders table safely using PL/pgSQL
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'gift_message') THEN
        ALTER TABLE orders ADD COLUMN gift_message text;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'gift_wrap') THEN
        ALTER TABLE orders ADD COLUMN gift_wrap boolean default false;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'recipient_address') THEN
        ALTER TABLE orders ADD COLUMN recipient_address text;
    END IF;
END $$;

-- --------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES
-- --------------------------------------------------------

-- Enable RLS on all new tables
alter table watchlist enable row level security;
alter table deals enable row level security;
alter table promotions enable row level security;
alter table chatbot_feedback enable row level security;
alter table returns enable row level security;
alter table user_points enable row level security;
alter table reviews enable row level security;

-- Watchlist: Since it uses device_id, we restrict direct anon access.
-- The backend uses the Service Role Key to bypass RLS and insert/read.
-- No public policies needed, meaning only backend can access.

-- Deals: Anyone can read active deals
create policy "Anyone can read active deals" on deals
  for select using (is_active = true);

-- Promotions: Anyone can read active promotions
create policy "Anyone can read active promotions" on promotions
  for select using (is_active = true);

-- Chatbot feedback: Anyone can insert
create policy "Anyone can insert chatbot feedback" on chatbot_feedback
  for insert with check (true);

-- Returns: Anyone can insert return requests
create policy "Anyone can insert returns" on returns
  for insert with check (true);

-- User points: Users can only see their own points
create policy "Users can view their own points" on user_points
  for select using (auth.uid()::text = user_id);

-- Reviews: Anyone can read, users can insert their own
create policy "Anyone can read reviews" on reviews
  for select using (true);

create policy "Users can insert their own reviews" on reviews
  for insert with check (auth.uid()::text = user_id);

