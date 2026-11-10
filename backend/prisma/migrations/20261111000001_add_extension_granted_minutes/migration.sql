-- Số phút thật sự cộng vào hạn mức (gồm phần bù khi trẻ đã vượt hạn mức lúc được duyệt).
-- NULL với bản ghi cũ → code dùng responseMinutes.
ALTER TABLE "TimeExtensionRequest" ADD COLUMN "grantedMinutes" INTEGER;
