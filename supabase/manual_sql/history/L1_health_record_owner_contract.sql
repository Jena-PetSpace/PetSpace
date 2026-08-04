-- PetSpace H1A: health_records must belong to the authenticated user's pet.
--
-- This file is repository-local preparation only. Before applying it to an
-- operational database, run the approved read-only mismatch inventory and
-- obtain explicit migration approval. It intentionally performs no data fix.

BEGIN;

DROP POLICY IF EXISTS "Users can view own pet health records"
    ON public.health_records;
CREATE POLICY "Users can view own pet health records"
    ON public.health_records
    FOR SELECT
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM public.pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert own pet health records"
    ON public.health_records;
CREATE POLICY "Users can insert own pet health records"
    ON public.health_records
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM public.pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update own pet health records"
    ON public.health_records;
CREATE POLICY "Users can update own pet health records"
    ON public.health_records
    FOR UPDATE
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM public.pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM public.pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete own pet health records"
    ON public.health_records;
CREATE POLICY "Users can delete own pet health records"
    ON public.health_records
    FOR DELETE
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM public.pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

COMMIT;
