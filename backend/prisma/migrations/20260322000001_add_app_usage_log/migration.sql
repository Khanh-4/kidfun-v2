-- CreateTable
CREATE TABLE "AppUsageLog" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "deviceId" INTEGER NOT NULL,
    "packageName" TEXT NOT NULL,
    "appName" TEXT,
    "usageSeconds" INTEGER NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AppUsageLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AppUsageLog_profileId_deviceId_packageName_date_key" ON "AppUsageLog"("profileId", "deviceId", "packageName", "date");

-- AddForeignKey
ALTER TABLE "AppUsageLog" ADD CONSTRAINT "AppUsageLog_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AppUsageLog" ADD CONSTRAINT "AppUsageLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;
