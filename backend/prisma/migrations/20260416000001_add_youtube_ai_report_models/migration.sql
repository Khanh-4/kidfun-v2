-- CreateTable
CREATE TABLE "YouTubeLog" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "deviceId" INTEGER NOT NULL,
    "videoTitle" TEXT NOT NULL,
    "channelName" TEXT,
    "videoId" TEXT,
    "thumbnailUrl" TEXT,
    "watchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "durationSeconds" INTEGER NOT NULL DEFAULT 0,
    "isAnalyzed" BOOLEAN NOT NULL DEFAULT false,
    "dangerLevel" INTEGER,
    "category" TEXT,
    "aiSummary" TEXT,
    "isBlocked" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "YouTubeLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AIAlert" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "youtubeLogId" INTEGER NOT NULL,
    "dangerLevel" INTEGER NOT NULL,
    "category" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "notifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AIAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BlockedVideo" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "videoTitle" TEXT NOT NULL,
    "channelName" TEXT,
    "videoId" TEXT,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BlockedVideo_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReportSnapshot" (
    "id" SERIAL NOT NULL,
    "profileId" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "data" JSONB NOT NULL,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReportSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "YouTubeLog_profileId_watchedAt_idx" ON "YouTubeLog"("profileId", "watchedAt");

-- CreateIndex
CREATE INDEX "YouTubeLog_isAnalyzed_idx" ON "YouTubeLog"("isAnalyzed");

-- CreateIndex
CREATE INDEX "YouTubeLog_dangerLevel_idx" ON "YouTubeLog"("dangerLevel");

-- CreateIndex
CREATE INDEX "AIAlert_profileId_createdAt_idx" ON "AIAlert"("profileId", "createdAt");

-- CreateIndex
CREATE INDEX "AIAlert_isRead_idx" ON "AIAlert"("isRead");

-- CreateIndex
CREATE INDEX "BlockedVideo_profileId_idx" ON "BlockedVideo"("profileId");

-- CreateIndex
CREATE INDEX "ReportSnapshot_profileId_type_periodStart_idx" ON "ReportSnapshot"("profileId", "type", "periodStart");

-- CreateIndex
CREATE UNIQUE INDEX "ReportSnapshot_profileId_type_periodStart_key" ON "ReportSnapshot"("profileId", "type", "periodStart");

-- AddForeignKey
ALTER TABLE "YouTubeLog" ADD CONSTRAINT "YouTubeLog_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "YouTubeLog" ADD CONSTRAINT "YouTubeLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AIAlert" ADD CONSTRAINT "AIAlert_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AIAlert" ADD CONSTRAINT "AIAlert_youtubeLogId_fkey" FOREIGN KEY ("youtubeLogId") REFERENCES "YouTubeLog"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BlockedVideo" ADD CONSTRAINT "BlockedVideo_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReportSnapshot" ADD CONSTRAINT "ReportSnapshot_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
