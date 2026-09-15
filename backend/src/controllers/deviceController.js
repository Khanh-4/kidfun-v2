const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { isDeviceOffline, minutesSinceLastSeen } = require('../utils/deviceStatus');
const socketService = require('../services/socketService');

// Cửa sổ coi là "vừa liên kết xong" khi phải suy ra thiết bị thật từ hồ sơ
// (xem getPairingStatus). Rộng hơn thời gian một lần liên kết thật (child gọi
// /link rồi parent poll lại trong vài giây) nhưng vẫn đủ hẹp để không nhận nhầm
// một thiết bị đã online từ trước.
const RECENT_LINK_WINDOW_MS = 2 * 60 * 1000;

// Tạo mã device ngẫu nhiên
const generateDeviceCode = () => {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
};

// GET /api/devices
const getAllDevices = async (req, res) => {
  try {
    const devices = await prisma.device.findMany({
      where: {
        userId: req.user.userId,
        // Ẩn bản nháp của mã liên kết chưa ai dùng. generate-pairing-code
        // INSERT dòng này ngay lúc tạo mã (deviceName = 'Pending Device'), nên
        // nếu không lọc thì nó hiện trong danh sách thiết bị của phụ huynh
        // suốt từ lúc tạo mã tới lúc mã được dùng hoặc bị huỷ — đúng thứ phụ
        // huynh báo là "app tự ghi nhận thiết bị". cancel-pairing chỉ thu hẹp
        // cửa sổ đó chứ không đóng được về 0: mỗi request mất 1-4s nên vẫn kịp
        // có một lần GET /api/devices nhìn thấy bản nháp.
        //
        // linkDevice xoá pairingCode và set isOnline = true khi liên kết thật,
        // nên "còn pairingCode và chưa từng online" nhận diện đúng bản nháp mà
        // không giấu nhầm thiết bị thật đang offline.
        OR: [
          { pairingCode: null },
          { isOnline: true }
        ]
      },
      include: {
        profile: true,
        applications: true,
        _count: { select: { sessions: true } }
      }
    });
    sendSuccess(res, devices);
  } catch (error) {
    console.error('Get devices error:', error);
    sendError(res, 'Failed to get devices', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices
const registerDevice = async (req, res) => {
  try {
    const { deviceName, osVersion } = req.body;

    const device = await prisma.device.create({
      data: {
        userId: req.user.userId,
        deviceName,
        deviceCode: generateDeviceCode(),
        osVersion
      }
    });

    sendSuccess(res, { device }, 201);
  } catch (error) {
    console.error('Register device error:', error);
    sendError(res, 'Failed to register device', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/devices/:id
const getDeviceById = async (req, res) => {
  try {
    const device = await prisma.device.findFirst({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      include: {
        applications: true,
        sessions: {
          take: 10,
          orderBy: { startTime: 'desc' }
        }
      }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, device);
  } catch (error) {
    console.error('Get device error:', error);
    sendError(res, 'Failed to get device', 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/devices/:id
const updateDevice = async (req, res) => {
  try {
    const { deviceName, osVersion, isOnline, profileId } = req.body;

    const device = await prisma.device.updateMany({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      data: {
        deviceName,
        osVersion,
        isOnline,
        profileId: profileId !== undefined ? (profileId === null ? null : parseInt(profileId)) : undefined,
        lastSeen: isOnline ? new Date() : undefined
      }
    });

    if (device.count === 0) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, { message: 'Device updated successfully' });
  } catch (error) {
    console.error('Update device error:', error);
    sendError(res, 'Failed to update device', 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/devices/:id
const deleteDevice = async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    const device = await prisma.device.findFirst({
      where: { id, userId: req.user.userId }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    // App trẻ chỉ biết mình bị gỡ khi gọi được API (Realtime DELETE, heartbeat
    // 404, hoặc lúc mở lại app) — xoá trong lúc nó mất mạng nghĩa là nó còn
    // khoá máy/giám sát tiếp cho tới khi có mạng trở lại. Cảnh báo cho phụ
    // huynh biết điều đó; `?force=true` là lựa chọn "Vẫn gỡ" trên dialog, dành
    // cho trường hợp máy trẻ mất/hỏng và sẽ không bao giờ online lại nữa.
    //
    // lastSeen = null nghĩa là chưa từng có app trẻ nào chạy trên thiết bị này
    // (bản nháp mã liên kết, hoặc device đăng ký thủ công) — không có ai để
    // cảnh báo, cứ xoá.
    const force = req.query.force === 'true';
    if (!force && device.lastSeen && isDeviceOffline(device.lastSeen)) {
      return sendError(
        res,
        'Thiết bị của trẻ đang mất kết nối',
        409,
        'DEVICE_OFFLINE',
        {
          lastSeen: device.lastSeen,
          minutesSinceLastSeen: minutesSinceLastSeen(device.lastSeen)
        }
      );
    }

    // Session không khai onDelete: Cascade trong schema (khác các bảng con còn
    // lại) nên phải xoá tay trước, nếu không prisma.device.delete ném FK error.
    await prisma.session.deleteMany({ where: { deviceId: id } });
    await prisma.fCMToken.deleteMany({ where: { deviceId: id } });
    await prisma.device.delete({ where: { id } });

    // Log để đối chiếu với phía app trẻ: sau lệnh này mọi API child dùng
    // deviceCode đó sẽ trả 404 INVALID_DEVICE_CODE — chính là tín hiệu app trẻ
    // dựa vào để tự gỡ liên kết (xem mobile/lib/core/services/child_link_service.dart).
    console.log(`🗑️ [DEVICE] Deleted device #${id} (code=${device.deviceCode}) of userId ${req.user.userId}`);

    sendSuccess(res, { message: 'Device deleted successfully' });
  } catch (error) {
    console.error('Delete device error:', error);
    sendError(res, 'Failed to delete device', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices/generate-pairing-code
const generatePairingCode = async (req, res) => {
  try {
    const { profileId } = req.body;
    if (!profileId) {
      return sendError(res, 'profileId is required', 400, 'MISSING_FIELDS');
    }

    // Kiểm tra xem profile có thuộc về user hiện tại không
    const profile = await prisma.profile.findFirst({
      where: {
        id: parseInt(profileId),
        userId: req.user.userId
      }
    });

    if (!profile) {
      return sendError(res, 'Profile not found or unauthorized', 404, 'NOT_FOUND');
    }

    // Tạo mã code 6 số random
    const pairingCode = Math.floor(100000 + Math.random() * 900000).toString();
    // 15 phút — đủ thời gian để phụ huynh chuyển mã sang thiết bị con
    // (mở app, đăng nhập/đăng ký, vào màn nhập mã) trước khi mã hết hạn
    const pairingCodeExpiry = new Date(Date.now() + 15 * 60 * 1000);

    // Dọn các bản nháp CHƯA liên kết đã hết hạn của chính user này. Bình thường
    // app parent tự gọi cancel-pairing khi rời màn hình liên kết, nhưng đường đó
    // không chạy được nếu app bị kill hoặc mất mạng đúng lúc thoát — nếu không
    // dọn ở đây thì bản nháp "Pending Device" nằm lại vĩnh viễn trong danh sách.
    const staleDrafts = await prisma.device.deleteMany({
      where: {
        userId: req.user.userId,
        isOnline: false,
        pairingCode: { not: null },
        pairingCodeExpiry: { lt: new Date() }
      }
    });
    if (staleDrafts.count > 0) {
      console.log(`🧹 [DEVICE] Cleaned ${staleDrafts.count} bản nháp hết hạn của userId ${req.user.userId}`);
    }

    // Tạo device nháp
    const device = await prisma.device.create({
      data: {
        userId: req.user.userId,
        profileId: parseInt(profileId),
        deviceCode: crypto.randomUUID(), // Dùng UUID tạm trong lúc chờ link thật
        deviceName: 'Pending Device',
        pairingCode,
        pairingCodeExpiry
      }
    });

    sendSuccess(res, { pairingCode, deviceId: device.id, expiresAt: pairingCodeExpiry }, 201);
  } catch (error) {
    console.error('Generate pairing code error:', error);
    sendError(res, 'Failed to generate pairing code', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/devices/:id/pairing-status?profileId=N
// Màn hình liên kết của app parent hỏi: "mã tôi vừa tạo đã có thiết bị nào dùng
// chưa?". Không dùng GET /:id/status được, vì có một nhánh của linkDevice XOÁ
// mất dòng nháp mang id đó: khi máy trẻ đã từng liên kết (còn dòng Device cũ
// theo deviceCode phần cứng), server ghi đè lên dòng cũ để giữ lịch sử sử dụng
// rồi xoá dòng nháp. Lúc đó GET /:id/status trả 404 và app parent treo mãi ở
// "Đang chờ kết nối" dù liên kết ĐÃ thành công.
const getPairingStatus = async (req, res) => {
  try {
    const deviceId = parseInt(req.params.id);
    const draft = await prisma.device.findFirst({
      where: { id: deviceId, userId: req.user.userId }
    });

    // Nhánh thường: dòng nháp còn nguyên, linkDevice cập nhật đè lên chính nó.
    if (draft) {
      if (draft.isOnline && draft.pairingCode === null) {
        return sendSuccess(res, { status: 'LINKED', deviceId: draft.id });
      }
      const expired = draft.pairingCodeExpiry && draft.pairingCodeExpiry <= new Date();
      return sendSuccess(res, { status: expired ? 'EXPIRED' : 'PENDING', deviceId: draft.id });
    }

    // Dòng nháp biến mất. Xác nhận bằng thiết bị thật thay vì mặc định coi là
    // thành công: liên kết thật luôn set isOnline = true và lastSeen = now()
    // trên hồ sơ này, nên chỉ nhận khi có thiết bị vừa online trong ít phút gần
    // đây. Không có mốc thời gian thì một thiết bị cũ đang online của cùng hồ sơ
    // sẽ bị nhận nhầm là "vừa liên kết xong".
    const profileId = parseInt(req.query.profileId);
    if (!profileId) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    const linked = await prisma.device.findFirst({
      where: {
        userId: req.user.userId,
        profileId,
        isOnline: true,
        lastSeen: { gte: new Date(Date.now() - RECENT_LINK_WINDOW_MS) }
      },
      orderBy: { lastSeen: 'desc' }
    });

    if (!linked) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    console.log(`🔗 [DEVICE] Bản nháp #${deviceId} đã bị thay bằng thiết bị #${linked.id} (trùng deviceCode phần cứng)`);
    return sendSuccess(res, { status: 'LINKED', deviceId: linked.id });
  } catch (error) {
    console.error('Get pairing status error:', error);
    sendError(res, 'Failed to get pairing status', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices/cancel-pairing
// Phụ huynh rời màn hình liên kết sau khi đã tạo mã: xoá luôn bản nháp để mã
// chết ngay và thiết bị không bị ghi nhận vào danh sách dưới tên "Pending
// Device" (generate-pairing-code INSERT bản nháp NGAY lúc tạo mã, nên nó đã
// hiện trong GET /api/devices trước cả khi có thiết bị con nào dùng mã).
const cancelPairing = async (req, res) => {
  try {
    const deviceId = parseInt(req.body.deviceId);
    if (!deviceId) {
      return sendError(res, 'deviceId is required', 400, 'MISSING_FIELDS');
    }

    const device = await prisma.device.findFirst({
      where: { id: deviceId, userId: req.user.userId }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    // Race thật: trẻ có thể xác nhận mã đúng lúc phụ huynh thoát màn hình.
    // linkDevice() xoá pairingCode và set isOnline=true, nên hai điều kiện này
    // phân biệt được "bản nháp chưa ai dùng" với "thiết bị vừa liên kết thật".
    // Không có guard này thì thao tác thoát màn hình sẽ xoá mất thiết bị thật.
    if (device.pairingCode === null || device.isOnline) {
      console.log(`↩️ [DEVICE] Bỏ qua cancel-pairing #${deviceId}: thiết bị đã liên kết`);
      return sendSuccess(res, { cancelled: false, reason: 'ALREADY_LINKED' });
    }

    await prisma.device.delete({ where: { id: deviceId } });
    console.log(`🧹 [DEVICE] Huỷ mã liên kết, xoá bản nháp #${deviceId} của userId ${req.user.userId}`);

    sendSuccess(res, { cancelled: true });
  } catch (error) {
    console.error('Cancel pairing error:', error);
    sendError(res, 'Failed to cancel pairing', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices/link
const linkDevice = async (req, res) => {
  try {
    let { pairingCode, deviceCode, deviceName, platform, osVersion } = req.body;

    if (!pairingCode) {
      return sendError(res, 'pairingCode is required', 400, 'MISSING_FIELDS');
    }

    deviceCode = deviceCode || 'DEV-' + Math.random().toString(36).substr(2, 9);
    deviceName = deviceName || 'Thiết bị chưa rõ tên';

    // Tìm device nháp chưa hết hạn
    const pendingDevice = await prisma.device.findFirst({
      where: {
        pairingCode,
        pairingCodeExpiry: { gt: new Date() }
      }
    });

    if (!pendingDevice) {
      return sendError(res, 'Mã liên kết không hợp lệ hoặc đã hết hạn. Vui lòng xin phụ huynh tạo mã mới.', 400, 'INVALID_CODE');
    }

    // Kiểm tra nếu deviceCode phần cứng đã có trong DB thì lấy id cũ ghi đè, nếu không thì dùng record pending
    // Tránh duplicate deviceCode unique constraint
    const existingHardwareDevice = await prisma.device.findUnique({
      where: { deviceCode }
    });

    let linkedDevice;

    if (existingHardwareDevice) {
      // Cập nhật device cũ với thông tin profile mới, xóa pending device
      linkedDevice = await prisma.device.update({
        where: { id: existingHardwareDevice.id },
        data: {
          userId: pendingDevice.userId,
          profileId: pendingDevice.profileId,
          deviceName,
          osVersion: osVersion || existingHardwareDevice.osVersion,
          isOnline: true,
          lastSeen: new Date()
        }
      });
      await prisma.device.delete({ where: { id: pendingDevice.id } });
    } else {
      // Cập nhật đè lên device pending
      linkedDevice = await prisma.device.update({
        where: { id: pendingDevice.id },
        data: {
          deviceCode,
          deviceName,
          osVersion: osVersion || pendingDevice.osVersion,
          pairingCode: null,
          pairingCodeExpiry: null,
          isOnline: true,
          lastSeen: new Date()
        }
      });
    }

    // Generate long-lived JWT for the child device
    const token = jwt.sign(
      {
        deviceId: linkedDevice.id,
        role: 'child',
        profileId: linkedDevice.profileId,
        userId: linkedDevice.userId
      },
      process.env.JWT_SECRET,
      { expiresIn: '365d' }
    );

    // Fetch profile name for notification payload
    let profileName = null;
    if (linkedDevice.profileId) {
      try {
        const profile = await prisma.profile.findUnique({ where: { id: linkedDevice.profileId } });
        profileName = profile?.profileName || null;
      } catch (e) { /* non-critical */ }
    }

    // Notify Parent via Socket.IO — emit ONCE with full payload
    const linkedPayload = {
      deviceId: linkedDevice.id,
      deviceCode: linkedDevice.deviceCode,
      deviceName: linkedDevice.deviceName,
      profileId: linkedDevice.profileId,
      profileName,
    };
    socketService.notifyFamily(linkedDevice.userId, 'deviceLinked', linkedPayload);
    // Also emit device_linked_success as alias (matches Flutter task requirement)
    socketService.notifyFamily(linkedDevice.userId, 'device_linked_success', linkedPayload);
    console.log(`📱 Device "${linkedDevice.deviceName}" linked → notified family_${linkedDevice.userId}`);

    sendSuccess(res, { message: 'Device linked successfully', token, device: linkedDevice });
  } catch (error) {
    console.error('Link device error:', error);
    sendError(res, 'Failed to link device', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/devices/:id/status
const getDeviceStatus = async (req, res) => {
  try {
    const device = await prisma.device.findFirst({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, {
      device: {
        id: device.id,
        deviceName: device.deviceName,
        deviceCode: device.deviceCode,
        osVersion: device.osVersion,
        profileId: device.profileId
      },
      isOnline: device.isOnline,
      lastSeen: device.lastSeen
    });
  } catch (error) {
    console.error('Get device status error:', error);
    sendError(res, 'Failed to get device status', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getAllDevices,
  registerDevice,
  getDeviceById,
  updateDevice,
  deleteDevice,
  linkDevice,
  generatePairingCode,
  cancelPairing,
  getPairingStatus,
  getDeviceStatus
};
