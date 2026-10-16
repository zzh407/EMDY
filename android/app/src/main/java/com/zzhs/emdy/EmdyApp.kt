package com.zzhs.emdy

import android.app.Application
import android.content.Context
import java.util.UUID

class EmdyApp : Application() {
    companion object {
        lateinit var instance: EmdyApp
            private set

        val deviceId: String by lazy {
            val prefs = instance.getSharedPreferences("emby_device", Context.MODE_PRIVATE)
            prefs.getString("device_id", null) ?: UUID.randomUUID().toString().also {
                prefs.edit().putString("device_id", it).apply()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}