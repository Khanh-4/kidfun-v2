-- Đồ án chuyên ngành (M2): cảnh báo hành vi + mức thường ngày cho luật tầng 1.
--
-- Viết dạng chạy lại được (IF NOT EXISTS) vì ngày 2026-10-20 hai bảng này đã lỡ được tạo trên
-- production bằng `prisma db push` (Prisma lấy DIRECT_URL từ backend/.env khi chỉ ghi đè
-- DATABASE_URL). Đã đối chiếu: production chỉ khác schema cũ đúng ở hai bảng này, và RLS đã được
-- bật tay ngay sau đó. `migrate deploy` trên production vì thế phải chạy qua mà không lỗi.

-- CreateTable
CREATE TABLE IF NOT EXISTS "BehaviorAlert" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "deviceId" INTEGER,
    "source" TEXT NOT NULL,
    "rule" TEXT NOT NULL,
    "category" TEXT NOT NULL DEFAULT 'all',
    "dayType" TEXT,
    "slotStart" TIMESTAMP(3) NOT NULL,
    "minutes" DOUBLE PRECISION,
    "usualMinutes" DOUBLE PRECISION,
    "message" TEXT NOT NULL,
    "feedback" TEXT,
    "feedbackAt" TIMESTAMP(3),
    "notifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BehaviorAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "BehaviorBaseline" (
    "profileId" INTEGER NOT NULL,
    "payload" JSONB NOT NULL,
    "validUntil" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BehaviorBaseline_pkey" PRIMARY KEY ("profileId")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "BehaviorAlert_profileId_createdAt_idx" ON "BehaviorAlert"("profileId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "BehaviorAlert_profileId_source_rule_category_slotStart_key" ON "BehaviorAlert"("profileId", "source", "rule", "category", "slotStart");

-- AddForeignKey (Postgres không có ADD CONSTRAINT IF NOT EXISTS -> bỏ qua nếu đã có)
DO $$ BEGIN
    ALTER TABLE "BehaviorAlert" ADD CONSTRAINT "BehaviorAlert_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "BehaviorAlert" ADD CONSTRAINT "BehaviorAlert_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "BehaviorBaseline" ADD CONSTRAINT "BehaviorBaseline_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Chỉ backend (Prisma, role postgres) đọc/ghi hai bảng này. Bật RLS và không tạo policy
-- nào để client Supabase (anon/authenticated) không truy cập trực tiếp được. Hai bảng
-- không nằm trong subquery policy của bảng nào khác (xem bẫy RLS subquery, PR #291).
ALTER TABLE "BehaviorAlert" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "BehaviorBaseline" ENABLE ROW LEVEL SECURITY;
