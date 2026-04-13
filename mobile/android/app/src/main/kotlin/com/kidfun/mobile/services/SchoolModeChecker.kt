package com.kidfun.mobile.services

/**
 * SchoolModeChecker — kiểm tra xem app có được phép dùng trong giờ học không.
 * State được sync từ server qua MethodChannel.
 */
object SchoolModeChecker {
    // Sync từ server
    var isActive: Boolean = false
    var allowedPackages: MutableSet<String> = mutableSetOf()
    var startTime: String? = null  // "07:00"
    var endTime: String? = null    // "11:30"

    private const val KIDFUN_PACKAGE = "com.kidfun.mobile"

    /**
     * Kiểm tra app có được phép dùng trong School Mode không
     */
    fun isAppAllowed(packageName: String): Boolean {
        if (!isActive) return true

        // Always allow KidFun itself
        if (packageName == KIDFUN_PACKAGE) return true

        // Always allow system UI
        if (packageName == "com.android.systemui" || packageName == "com.android.settings") {
            return true
        }

        return allowedPackages.contains(packageName)
    }
}
