-- SQL Migration for Realtywize

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Profiles Table
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text,
  role text,
  avatar_initials text,
  onboarding_completed boolean default false,
  updated_at timestamp with time zone default now()
);

-- Leads Table
create table public.leads (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  email text,
  phone text,
  status text default 'New',
  score integer default 0,
  score_reason text,
  source text,
  created_at timestamp with time zone default now()
);

-- Tasks Table
create table public.tasks (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  text text not null,
  completed boolean default false,
  due_time text,
  created_at timestamp with time zone default now()
);

-- Valuations Table (for Home Valuation feature)
create table public.valuations (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  address text not null,
  estimated_value numeric,
  details jsonb,
  created_at timestamp with time zone default now()
);

-- Conversations Table
create table public.conversations (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  lead_id uuid references public.leads on delete set null,
  transcript jsonb,
  summary text,
  created_at timestamp with time zone default now()
);

-- Row Level Security (RLS)

alter table public.profiles enable row level security;
alter table public.leads enable row level security;
alter table public.tasks enable row level security;
alter table public.valuations enable row level security;
alter table public.conversations enable row level security;

-- Policies

-- Profiles: Users can only view and update their own profile
create policy "Users can view own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- Leads: Users can only access their own leads
create policy "Users can view own leads" on public.leads for select using (auth.uid() = user_id);
create policy "Users can insert own leads" on public.leads for insert with check (auth.uid() = user_id);
create policy "Users can update own leads" on public.leads for update using (auth.uid() = user_id);
create policy "Users can delete own leads" on public.leads for delete using (auth.uid() = user_id);

-- Tasks: Users can only access their own tasks
create policy "Users can view own tasks" on public.tasks for select using (auth.uid() = user_id);
create policy "Users can insert own tasks" on public.tasks for insert with check (auth.uid() = user_id);
create policy "Users can update own tasks" on public.tasks for update using (auth.uid() = user_id);
create policy "Users can delete own tasks" on public.tasks for delete using (auth.uid() = user_id);

-- Valuations: Users can only access their own valuations
create policy "Users can view own valuations" on public.valuations for select using (auth.uid() = user_id);
create policy "Users can insert own valuations" on public.valuations for insert with check (auth.uid() = user_id);

-- Conversations: Users can only access their own conversations
create policy "Users can view own conversations" on public.conversations for select using (auth.uid() = user_id);
create policy "Users can insert own conversations" on public.conversations for insert with check (auth.uid() = user_id);

-- Handle profile creation on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_initials)
  values (new.id, new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'avatar_initials');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
