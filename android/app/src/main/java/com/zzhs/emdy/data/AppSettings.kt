package com.zzhs.emdy.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.settingsStore by preferencesDataStore(name = "emdy_settings")

/** 播放设置与登录信息持久化 */
object AppSettings {

    private val KEY_REMEMBER = booleanPreferencesKey("remember_login")
    private val KEY_SERVER = stringPreferencesKey("login_server")
    private val KEY_USER = stringPreferencesKey("login_user")
    private val KEY_PASSWORD = stringPreferencesKey("login_password")
    private val KEY_HIDE_COLLECTIONS = booleanPreferencesKey("hide_collections")
    private val KEY_SHUFFLE = booleanPreferencesKey("shuffle_playback")
    private val KEY_FAST_SPEED = floatPreferencesKey("fast_speed")

    suspend fun loadHideCollections(context: Context): Boolean =
        context.settingsStore.data.first()[KEY_HIDE_COLLECTIONS] ?: false

    suspend fun saveHideCollections(context: Context, value: Boolean) {
        context.settingsStore.edit { it[KEY_HIDE_COLLECTIONS] = value }
    }

    suspend fun loadShuffle(context: Context): Boolean =
        context.settingsStore.data.first()[KEY_SHUFFLE] ?: false

    suspend fun saveShuffle(context: Context, value: Boolean) {
        context.settingsStore.edit { it[KEY_SHUFFLE] = value }
    }

    suspend fun loadFastSpeed(context: Context): Float =
        context.settingsStore.data.first()[KEY_FAST_SPEED] ?: 2.0f

    suspend fun saveFastSpeed(context: Context, value: Float) {
        context.settingsStore.edit { it[KEY_FAST_SPEED] = value }
    }

    /** 返回 [记住, 服务器, 用户名, 密码] */
    suspend fun loadLogin(context: Context): List<String> {
        val prefs = context.settingsStore.data.first()
        return listOf(
            if (prefs[KEY_REMEMBER] == true) "1" else "0",
            prefs[KEY_SERVER] ?: "",
            prefs[KEY_USER] ?: "",
            prefs[KEY_PASSWORD] ?: ""
        )
    }

    suspend fun saveLogin(context: Context, server: String, user: String, password: String) {
        context.settingsStore.edit {
            it[KEY_REMEMBER] = true
            it[KEY_SERVER] = server
            it[KEY_USER] = user
            it[KEY_PASSWORD] = password
        }
    }

    suspend fun clearLogin(context: Context) {
        context.settingsStore.edit {
            it[KEY_REMEMBER] = false
            it.remove(KEY_SERVER)
            it.remove(KEY_USER)
            it.remove(KEY_PASSWORD)
        }
    }
}
