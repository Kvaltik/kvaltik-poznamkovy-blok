-- Kvaltík Notepad 1.3: additive metadata + private revision history.
-- Does not delete or overwrite existing notes.
ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS folder_path text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS notes_owner_pinned_idx
  ON public.notes (owner_id, pinned DESC, updated_at DESC)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS public.note_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  note_id uuid NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  pinned boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  tags text[] NOT NULL DEFAULT '{}',
  folder_path text NOT NULL DEFAULT '',
  saved_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS note_versions_owner_note_idx
  ON public.note_versions (owner_id, note_id, id DESC);
ALTER TABLE public.note_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS note_versions_select_own ON public.note_versions;
CREATE POLICY note_versions_select_own ON public.note_versions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS note_versions_insert_own ON public.note_versions;
CREATE POLICY note_versions_insert_own ON public.note_versions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = owner_id
    AND EXISTS (SELECT 1 FROM public.notes
      WHERE notes.id = note_id AND notes.owner_id = (SELECT auth.uid())));

REVOKE ALL ON public.note_versions FROM anon;
REVOKE ALL ON public.note_versions FROM authenticated;
GRANT SELECT, INSERT ON public.note_versions TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.note_versions_id_seq TO authenticated;

-- SECURITY INVOKER: standard RLS rules apply to the automatically inserted revision.
CREATE OR REPLACE FUNCTION public.record_note_revision()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = '' AS $$
BEGIN
  IF ROW(OLD.title, OLD.body, OLD.pinned, OLD.archived, OLD.tags, OLD.folder_path)
     IS DISTINCT FROM
     ROW(NEW.title, NEW.body, NEW.pinned, NEW.archived, NEW.tags, NEW.folder_path)
  THEN
    INSERT INTO public.note_versions
      (note_id, owner_id, title, body, pinned, archived, tags, folder_path)
    VALUES
      (OLD.id, OLD.owner_id, OLD.title, OLD.body,
       OLD.pinned, OLD.archived, OLD.tags, OLD.folder_path);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS note_revision_on_update ON public.notes;
CREATE TRIGGER note_revision_on_update
  BEFORE UPDATE ON public.notes FOR EACH ROW
  EXECUTE FUNCTION public.record_note_revision();

-- Stream updates to logged-in devices. Table already has owner-only RLS.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notes')
  THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;
  END IF;
END;
$$;
