-- ============================================
-- 여행 공유 기능 — DB 업데이트
-- Supabase SQL Editor에서 실행하세요
-- ============================================

-- ① trips 테이블 컬럼 추가
ALTER TABLE trips ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'personal'
  CHECK (visibility IN ('personal', 'public', 'invite'));
ALTER TABLE trips ADD COLUMN IF NOT EXISTS share_token UUID DEFAULT gen_random_uuid();
ALTER TABLE trips ADD COLUMN IF NOT EXISTS owner_name TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_trips_share_token ON trips(share_token);

-- ② trip_shares 테이블 생성
CREATE TABLE IF NOT EXISTS trip_shares (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id    UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,
  role       TEXT NOT NULL CHECK (role IN ('viewer', 'editor')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(trip_id, email)
);

ALTER TABLE trip_shares ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_trip_shares_user_id ON trip_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_shares_trip_id ON trip_shares(trip_id);

-- ③ saved_bundles 컬럼 추가
ALTER TABLE saved_bundles ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'personal'
  CHECK (visibility IN ('personal', 'public'));
ALTER TABLE saved_bundles ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE saved_bundles ADD COLUMN IF NOT EXISTS use_count INT DEFAULT 0;

-- ④ trips RLS 업데이트
DROP POLICY IF EXISTS "trips_user_policy" ON trips;
DROP POLICY IF EXISTS "trips_owner" ON trips;
DROP POLICY IF EXISTS "trips_public_read" ON trips;
DROP POLICY IF EXISTS "trips_invite_read" ON trips;

CREATE POLICY "trips_owner" ON trips FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "trips_public_read" ON trips FOR SELECT
  USING (visibility = 'public');

CREATE POLICY "trips_invite_read" ON trips FOR SELECT
  USING (
    visibility = 'invite'
    AND id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid())
  );

-- ⑤ pins RLS 업데이트
DROP POLICY IF EXISTS "pins_user_policy" ON pins;
DROP POLICY IF EXISTS "pins_owner" ON pins;
DROP POLICY IF EXISTS "pins_public_read" ON pins;
DROP POLICY IF EXISTS "pins_invite_read" ON pins;
DROP POLICY IF EXISTS "pins_invite_edit" ON pins;

CREATE POLICY "pins_owner" ON pins FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

CREATE POLICY "pins_public_read" ON pins FOR SELECT
  USING (trip_id IN (SELECT id FROM trips WHERE visibility = 'public'));

CREATE POLICY "pins_invite_read" ON pins FOR SELECT
  USING (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid()));

CREATE POLICY "pins_invite_edit" ON pins FOR ALL
  USING (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid() AND role = 'editor'))
  WITH CHECK (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid() AND role = 'editor'));

-- ⑥ routes RLS 업데이트
DROP POLICY IF EXISTS "routes_user_policy" ON routes;
DROP POLICY IF EXISTS "routes_owner" ON routes;
DROP POLICY IF EXISTS "routes_public_read" ON routes;
DROP POLICY IF EXISTS "routes_invite_read" ON routes;
DROP POLICY IF EXISTS "routes_invite_edit" ON routes;

CREATE POLICY "routes_owner" ON routes FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

CREATE POLICY "routes_public_read" ON routes FOR SELECT
  USING (trip_id IN (SELECT id FROM trips WHERE visibility = 'public'));

CREATE POLICY "routes_invite_read" ON routes FOR SELECT
  USING (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid()));

CREATE POLICY "routes_invite_edit" ON routes FOR ALL
  USING (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid() AND role = 'editor'))
  WITH CHECK (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid() AND role = 'editor'));

-- ⑦ journals RLS 업데이트
DROP POLICY IF EXISTS "journals_user_policy" ON journals;
DROP POLICY IF EXISTS "journals_owner" ON journals;
DROP POLICY IF EXISTS "journals_public_read" ON journals;
DROP POLICY IF EXISTS "journals_invite_read" ON journals;
DROP POLICY IF EXISTS "journals_invite_edit" ON journals;

CREATE POLICY "journals_owner" ON journals FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

CREATE POLICY "journals_public_read" ON journals FOR SELECT
  USING (trip_id IN (SELECT id FROM trips WHERE visibility = 'public'));

CREATE POLICY "journals_invite_read" ON journals FOR SELECT
  USING (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid()));

CREATE POLICY "journals_invite_edit" ON journals FOR ALL
  USING (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid() AND role = 'editor'))
  WITH CHECK (trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid() AND role = 'editor'));

-- ⑧ journal_photos RLS 업데이트
DROP POLICY IF EXISTS "journal_photos_user_policy" ON journal_photos;
DROP POLICY IF EXISTS "jp_owner" ON journal_photos;
DROP POLICY IF EXISTS "jp_public_read" ON journal_photos;
DROP POLICY IF EXISTS "jp_invite_read" ON journal_photos;

CREATE POLICY "jp_owner" ON journal_photos FOR ALL
  USING (journal_id IN (
    SELECT j.id FROM journals j JOIN trips t ON j.trip_id = t.id WHERE t.user_id = auth.uid()
  ))
  WITH CHECK (journal_id IN (
    SELECT j.id FROM journals j JOIN trips t ON j.trip_id = t.id WHERE t.user_id = auth.uid()
  ));

CREATE POLICY "jp_public_read" ON journal_photos FOR SELECT
  USING (journal_id IN (
    SELECT j.id FROM journals j JOIN trips t ON j.trip_id = t.id WHERE t.visibility = 'public'
  ));

CREATE POLICY "jp_invite_read" ON journal_photos FOR SELECT
  USING (journal_id IN (
    SELECT j.id FROM journals j
    WHERE j.trip_id IN (SELECT trip_id FROM trip_shares WHERE user_id = auth.uid())
  ));

-- ⑨ trip_shares RLS
DROP POLICY IF EXISTS "shares_owner" ON trip_shares;
DROP POLICY IF EXISTS "shares_self_read" ON trip_shares;

CREATE POLICY "shares_owner" ON trip_shares FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

CREATE POLICY "shares_self_read" ON trip_shares FOR SELECT
  USING (user_id = auth.uid());

-- ⑩ saved_bundles RLS 업데이트
DROP POLICY IF EXISTS "bundles_user_policy" ON saved_bundles;
DROP POLICY IF EXISTS "bundles_owner" ON saved_bundles;
DROP POLICY IF EXISTS "bundles_public_read" ON saved_bundles;

CREATE POLICY "bundles_owner" ON saved_bundles FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "bundles_public_read" ON saved_bundles FOR SELECT
  USING (visibility = 'public');

-- ⑪ Storage: public 여행 사진도 읽기 허용
DROP POLICY IF EXISTS "Users can view own photos" ON storage.objects;

CREATE POLICY "Users can view own photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'journal-photos'
    AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR (storage.foldername(name))[1] IN (
        SELECT user_id::text FROM trips WHERE visibility IN ('public','invite')
      )
    )
  );
