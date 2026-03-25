package com.kidfun.mobile

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.app.admin.DevicePolicyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.kidfun.mobile.helpers.UsageStatsHelper
import com.kidfun.mobile.services.AppBlockerService
import com.kidfun.mobile.services.KidFunService
import com.kidfun.mobile.receivers.KidFunDeviceAdminReceiver

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kidfun.native"
    private lateinit var usageHelper: UsageStatsHelper

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usageHelper = UsageStatsHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppUsage" -> result.success(usageHelper.getTodayUsage())

                    "getInstalledApps" -> result.success(usageHelper.getInstalledApps())

                    "startForegroundService" -> {
                        val serviceIntent = Intent(this, KidFunService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    }

                    "scheduleLockAt" -> {
                        val epochMillis = call.argument<Long>("epochMillis") ?: 0L
                        val serviceIntent = Intent(this, KidFunService::class.java).apply {
                            action = KidFunService.ACTION_SET_LOCK_TIME
                            putExtra(KidFunService.EXTRA_LOCK_AT, epochMillis)
                        }
                        startService(serviceIntent)
                        result.success(null)
                    }

                    "cancelScheduledLock" -> {
                        val serviceIntent = Intent(this, KidFunService::class.java).apply {
                            action = KidFunService.ACTION_SET_LOCK_TIME
                            putExtra(KidFunService.EXTRA_LOCK_AT, 0L)
                        }
                        startService(serviceIntent)
                        result.success(null)
                    }

                    "stopForegroundService" -> {
                        stopService(Intent(this, KidFunService::class.java))
                        result.success(null)
                    }

                    "setBlockedApps" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        AppBlockerService.blockedPackages.clear()
                        AppBlockerService.blockedPackages.addAll(packages)
                        result.success(null)
                    }

                    "lockScreen" -> {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = ComponentName(this, KidFunDeviceAdminReceiver::class.java)
                        if (dpm.isAdminActive(adminComponent)) {
                            dpm.lockNow()
                            result.success(true)
                        } else {
                            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                                putExtra(
                                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                    "KidFun cần quyền để khóa màn hình khi hết giờ"
                                )
                            }
                            startActivity(intent)
                            result.success(false)
                        }
                    }

                    "hasUsageStatsPermission" -> result.success(usageHelper.hasPermission())

                    "requestUsageStatsPermission" -> {
                        usageHelper.requestPermission()
                        result.success(null)
                    }

                    "isAccessibilityEnabled" -> result.success(AppBlockerService.isEnabled)

                    "requestAccessibilityPermission" -> {
                        val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
