-- ============================================
-- 여행 일지 — Supabase 테이블 + RLS + Storage 설정
-- Supabase SQL Editor에서 실행하세요
-- ============================================

-- ① 테이블 생성
-- ────────────────────────────────────────────

CREATE TABLE trips (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  destination TEXT,
  dest_address TEXT,
  flag        TEXT DEFAULT '✈️',
  center_lat  DOUBLE PRECISION,
  center_lng  DOUBLE PRECISION,
  start_date  DATE,
  end_date    DATE,
  theme       JSONB DEFAULT '{}',
  days        INT DEFAULT 1,
  day_colors  JSONB DEFAULT '[]',
  thumbnail   TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE pins (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id         UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN ('wish','confirmed','done')),
  name            TEXT NOT NULL,
  address         TEXT,
  lat             DOUBLE PRECISION NOT NULL,
  lng             DOUBLE PRECISION NOT NULL,
  category        TEXT,
  rating          DOUBLE PRECISION,
  place_id        TEXT,
  sort_order      INT DEFAULT 0,
  day             INT DEFAULT 0,
  visit_time      TEXT,
  memo            TEXT,
  reservation_url TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE routes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  from_pin_id UUID REFERENCES pins(id) ON DELETE SET NULL,
  to_pin_id   UUID REFERENCES pins(id) ON DELETE SET NULL,
  transport   TEXT,
  duration    TEXT,
  distance    TEXT,
  memo        TEXT
);

CREATE TABLE journals (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id    UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  day_index  INT NOT NULL,
  text       TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(trip_id, day_index)
);

CREATE TABLE journal_photos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_id   UUID NOT NULL REFERENCES journals(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  url          TEXT NOT NULL,
  is_thumbnail BOOLEAN DEFAULT false,
  sort_order   INT DEFAULT 0
);

CREATE TABLE saved_bundles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  places     JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ② 인덱스
-- ────────────────────────────────────────────

CREATE INDEX idx_trips_user_id ON trips(user_id);
CREATE INDEX idx_pins_trip_id ON pins(trip_id);
CREATE INDEX idx_routes_trip_id ON routes(trip_id);
CREATE INDEX idx_journals_trip_id ON journals(trip_id);
CREATE INDEX idx_journal_photos_journal_id ON journal_photos(journal_id);
CREATE INDEX idx_saved_bundles_user_id ON saved_bundles(user_id);

-- ③ RLS 활성화 + 정책
-- ────────────────────────────────────────────

ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "trips_user_policy" ON trips FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE pins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pins_user_policy" ON pins FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

ALTER TABLE routes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "routes_user_policy" ON routes FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

ALTER TABLE journals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "journals_user_policy" ON journals FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()))
  WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

ALTER TABLE journal_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "journal_photos_user_policy" ON journal_photos FOR ALL
  USING (journal_id IN (
    SELECT j.id FROM journals j
    JOIN trips t ON j.trip_id = t.id
    WHERE t.user_id = auth.uid()
  ))
  WITH CHECK (journal_id IN (
    SELECT j.id FROM journals j
    JOIN trips t ON j.trip_id = t.id
    WHERE t.user_id = auth.uid()
  ));

ALTER TABLE saved_bundles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bundles_user_policy" ON saved_bundles FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ④ Storage 버킷 RLS (버킷은 Dashboard에서 수동 생성)
-- ────────────────────────────────────────────

CREATE POLICY "Users can upload own photos"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'journal-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view own photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'journal-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own photos"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'journal-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
