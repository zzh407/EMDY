package com.zzhs.emdy

import android.app.Application
import java.util.UUID

class EmdyApp : Application() {

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        lateinit var instance: EmdyApp
            private set

        /** 设备 ID：首次生成后持久化（Emby 设备标识） */
        val deviceId: String by lazy {
            val prefs = instance.getSharedPreferences("emdy_device", MODE_PRIVATE)
            var id = prefs.getString("device_id", "") ?: ""
            if (id.isEmpty()) {
                id = "emdy-android-${UUID.randomUUID()}"
                prefs.edit().putString("device_id", id).apply()
            }
            id
        }
    }
}
