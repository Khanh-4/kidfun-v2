-- CreateTable
CREATE TABLE "AppUsageHourly" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "deviceId" INTEGER NOT NULL,
    "packageName" TEXT NOT NULL,
    "appName" TEXT,
    "hourStart" TIMESTAMP(3) NOT NULL,
    "usageSeconds" INTEGER NOT NULL,
    "launchCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AppUsageHourly_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AppUsageHourly_deviceId_packageName_hourStart_key" ON "AppUsageHourly"("deviceId", "packageName", "hourStart");

-- CreateIndex
CREATE INDEX "AppUsageHourly_profileId_hourStart_idx" ON "AppUsageHourly"("profileId", "hourStart");

-- AddForeignKey
ALTER TABLE "AppUsageHourly" ADD CONSTRAINT "AppUsageHourly_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AppUsageHourly" ADD CONSTRAINT "AppUsageHourly_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Chỉ backend (Prisma, role postgres) đọc/ghi bảng này. Bật RLS và không tạo policy
-- nào để client Supabase (anon/authenticated) không truy cập trực tiếp được.
ALTER TABLE "AppUsageHourly" ENABLE ROW LEVEL SECURITY;
