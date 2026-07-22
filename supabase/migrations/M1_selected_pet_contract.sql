-- M1: persist the representative pet without accepting a caller user id.
BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS selected_pet_id uuid;

DO $m1_constraint$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_selected_pet_id_fkey'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_selected_pet_id_fkey
      FOREIGN KEY (selected_pet_id)
      REFERENCES public.pets(id)
      ON DELETE SET NULL;
  END IF;
END;
$m1_constraint$;

CREATE OR REPLACE FUNCTION public.get_my_selected_pet_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.selected_pet_id
  FROM public.users AS u
  WHERE u.id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.set_my_selected_pet_id(p_pet_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_pet_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.pets AS p
    WHERE p.id = p_pet_id
      AND p.user_id = v_actor
  ) THEN
    RAISE EXCEPTION 'pet is not owned by caller' USING ERRCODE = '42501';
  END IF;

  UPDATE public.users
  SET selected_pet_id = p_pet_id,
      updated_at = now()
  WHERE id = v_actor;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN p_pet_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_selected_pet_id()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_my_selected_pet_id(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_selected_pet_id()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_selected_pet_id(uuid)
  TO authenticated;

COMMIT;
