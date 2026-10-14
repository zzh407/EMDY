package com.zzhs.emdy.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.sessionStore by preferencesDataStore(name = "emdy_session")

/** 会话与媒体库选择持久化 */
object SessionStore {

    private val KEY_SESSION = stringPreferencesKey("session_json")
    private val KEY_LIBRARY_ID = stringPreferencesKey("library_id")

    suspend fun save(context: Context, session: EmbySession) {
        context.sessionStore.edit { prefs ->
            prefs[KEY_SESSION] = "${session.serverUrl}\n${session.accessToken}\n${session.userId}\n${session.userName}"
        }
    }

    suspend fun load(context: Context): EmbySession? {
        val prefs = context.sessionStore.data.first()
        val raw = prefs[KEY_SESSION] ?: return null
        val parts = raw.split("\n")
        if (parts.size < 3 || parts[1].isEmpty()) return null
        return EmbySession(
            serverUrl = parts[0],
            accessToken = parts[1],
            userId = parts[2],
            userName = parts.getOrElse(3) { "" }
        )
    }

    suspend fun clear(context: Context) {
        context.sessionStore.edit { it.remove(KEY_SESSION) }
    }

    suspend fun saveLibraryId(context: Context, libraryId: String) {
        context.sessionStore.edit { it[KEY_LIBRARY_ID] = libraryId }
    }

    suspend fun loadLibraryId(context: Context): String {
        val prefs = context.sessionStore.data.first()
        return prefs[KEY_LIBRARY_ID] ?: ""
    }
}
