-- Đồ án chuyên ngành (T7.5.3): nhóm thói quen (M3) + gợi ý (M4) cho từng trẻ, do tác vụ ban đêm ghi.
-- Viết dạng chạy lại được (IF NOT EXISTS) giống migration 20261105000001.

-- CreateTable
CREATE TABLE IF NOT EXISTS "HabitInsight" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "habitSummary" TEXT,
    "clusterId" INTEGER,
    "clusterCount" INTEGER,
    "suggestions" JSONB NOT NULL,
    "modelVersion" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HabitInsight_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "HabitInsight_profileId_date_key" ON "HabitInsight"("profileId", "date");

-- AddForeignKey (Postgres không có ADD CONSTRAINT IF NOT EXISTS -> bỏ qua nếu đã có)
DO $$ BEGIN
    ALTER TABLE "HabitInsight" ADD CONSTRAINT "HabitInsight_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Chỉ backend (Prisma, role postgres) đọc/ghi. Bật RLS, không tạo policy (như UsagePrediction);
-- bảng không nằm trong subquery policy của bảng nào khác (xem bẫy RLS subquery, PR #291).
ALTER TABLE "HabitInsight" ENABLE ROW LEVEL SECURITY;
