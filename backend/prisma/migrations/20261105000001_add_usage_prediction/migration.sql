-- Đồ án chuyên ngành (M1, T7.2.2a): dự đoán số phút / xác suất vượt giới hạn cho từng ngày.
-- Viết dạng chạy lại được (IF NOT EXISTS) giống migration 20261020000001.

-- CreateTable
CREATE TABLE IF NOT EXISTS "UsagePrediction" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "predictedMinutes" DOUBLE PRECISION NOT NULL,
    "pOverLimit" DOUBLE PRECISION,
    "limitMinutes" INTEGER,
    "message" TEXT,
    "modelVersion" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UsagePrediction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "UsagePrediction_profileId_date_key" ON "UsagePrediction"("profileId", "date");

-- AddForeignKey (Postgres không có ADD CONSTRAINT IF NOT EXISTS -> bỏ qua nếu đã có)
DO $$ BEGIN
    ALTER TABLE "UsagePrediction" ADD CONSTRAINT "UsagePrediction_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Chỉ backend (Prisma, role postgres) đọc/ghi. Bật RLS, không tạo policy để client Supabase
-- (anon/authenticated) không truy cập trực tiếp. Bảng không nằm trong subquery policy của bảng
-- nào khác (xem bẫy RLS subquery, PR #291).
ALTER TABLE "UsagePrediction" ENABLE ROW LEVEL SECURITY;
