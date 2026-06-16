-- Admin and Feature Access Control Migration

-- 1. Update Profiles table with defaults and feature flags
ALTER TABLE public.profiles
  ALTER COLUMN role SET DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS deal_finder_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ai_assistant_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS valuation_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS lead_management_enabled BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS task_management_enabled BOOLEAN DEFAULT true;

-- Update existing profiles with emails from auth.users (if any)
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND p.email IS NULL;

-- Update the handle_new_user function to include email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_initials, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'display_name',
    NEW.raw_user_meta_data->>'avatar_initials',
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create helper function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update RLS Policies to allow Admin access

-- Profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR is_admin());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id OR is_admin());

-- Leads
DROP POLICY IF EXISTS "Users can view own leads" ON public.leads;
CREATE POLICY "Admin and owner can view leads" ON public.leads
  FOR SELECT USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can insert own leads" ON public.leads;
CREATE POLICY "Users can insert own leads" ON public.leads
  FOR INSERT WITH CHECK (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can update own leads" ON public.leads;
CREATE POLICY "Admin and owner can update leads" ON public.leads
  FOR UPDATE USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can delete own leads" ON public.leads;
CREATE POLICY "Admin and owner can delete leads" ON public.leads
  FOR DELETE USING (auth.uid() = user_id OR is_admin());

-- Tasks
DROP POLICY IF EXISTS "Users can view own tasks" ON public.tasks;
CREATE POLICY "Admin and owner can view tasks" ON public.tasks
  FOR SELECT USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can insert own tasks" ON public.tasks;
CREATE POLICY "Users can insert own tasks" ON public.tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can update own tasks" ON public.tasks;
CREATE POLICY "Admin and owner can update tasks" ON public.tasks
  FOR UPDATE USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can delete own tasks" ON public.tasks;
CREATE POLICY "Admin and owner can delete tasks" ON public.tasks
  FOR DELETE USING (auth.uid() = user_id OR is_admin());

-- Valuations
DROP POLICY IF EXISTS "Users can view own valuations" ON public.valuations;
CREATE POLICY "Admin and owner can view valuations" ON public.valuations
  FOR SELECT USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can insert own valuations" ON public.valuations;
CREATE POLICY "Users can insert own valuations" ON public.valuations
  FOR INSERT WITH CHECK (auth.uid() = user_id OR is_admin());

-- Conversations
DROP POLICY IF EXISTS "Users can view own conversations" ON public.conversations;
CREATE POLICY "Admin and owner can view conversations" ON public.conversations
  FOR SELECT USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "Users can insert own conversations" ON public.conversations;
CREATE POLICY "Users can insert own conversations" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id OR is_admin());


-- 4. Template to promote a user to admin by email
-- Usage: Replace 'your-email@example.com' with the actual email.
/*
UPDATE public.profiles
SET role = 'admin',
    deal_finder_enabled = true,
    ai_assistant_enabled = true,
    valuation_enabled = true
WHERE id IN (
    SELECT id FROM auth.users WHERE email = 'your-email@example.com'
);
*/
