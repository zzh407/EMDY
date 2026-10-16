package com.zzhs.emdy.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject

private val Context.favoriteStore by preferencesDataStore(name = "emdy_favorites")

/** 本地喜欢收藏持久化（与 HarmonyOS 版字段对齐） */
object FavoriteStore {

    private val KEY_FAVORITES = stringPreferencesKey("favorite_videos")

    suspend fun load(context: Context): List<EmbyVideo> {
        val prefs = context.favoriteStore.data.first()
        val raw = prefs[KEY_FAVORITES] ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            val videos = mutableListOf<EmbyVideo>()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                val id = obj.optString("id")
                if (id.isEmpty()) continue
                videos.add(
                    EmbyVideo(
                        id = id,
                        name = obj.optString("name"),
                        overview = obj.optString("overview"),
                        imageUrl = obj.optString("imageUrl"),
                        streamUrl = obj.optString("streamUrl"),
                        durationText = obj.optString("durationText"),
                        authorName = obj.optString("authorName"),
                        authorAvatar = obj.optString("authorAvatar"),
                        width = obj.optInt("width"),
                        height = obj.optInt("height"),
                        playbackModes = parseModes(obj.optJSONArray("playbackModes")),
                        directStreamUrl = obj.optString("directStreamUrl"),
                        hlsStreamUrl = obj.optString("hlsStreamUrl"),
                        originalStreamUrl = obj.optString("originalStreamUrl"),
                        originalIndex = obj.optInt("originalIndex"),
                        tags = parseStrings(obj.optJSONArray("tags")),
                        genres = parseStrings(obj.optJSONArray("genres"))
                    )
                )
            }
            videos
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun save(context: Context, videos: List<EmbyVideo>) {
        val array = JSONArray()
        videos.forEach { video ->
            val obj = JSONObject()
            obj.put("id", video.id)
            obj.put("name", video.name)
            obj.put("overview", video.overview)
            obj.put("imageUrl", video.imageUrl)
            obj.put("streamUrl", video.streamUrl)
            obj.put("durationText", video.durationText)
            obj.put("authorName", video.authorName)
            obj.put("authorAvatar", video.authorAvatar)
            obj.put("width", video.width)
            obj.put("height", video.height)
            obj.put("playbackModes", JSONArray(video.playbackModes.map { it.name.lowercase() }))
            obj.put("directStreamUrl", video.directStreamUrl)
            obj.put("hlsStreamUrl", video.hlsStreamUrl)
            obj.put("originalStreamUrl", video.originalStreamUrl)
            obj.put("originalIndex", video.originalIndex)
            obj.put("tags", JSONArray(video.tags))
            obj.put("genres", JSONArray(video.genres))
            array.put(obj)
        }
        context.favoriteStore.edit { it[KEY_FAVORITES] = array.toString() }
    }

    private fun parseModes(array: JSONArray?): List<PlaybackMode> {
        if (array == null || array.length() == 0) return listOf(PlaybackMode.DIRECT)
        val modes = mutableListOf<PlaybackMode>()
        for (i in 0 until array.length()) {
            when (array.optString(i)) {
                "direct" -> modes.add(PlaybackMode.DIRECT)
                "hls" -> modes.add(PlaybackMode.HLS)
                "original" -> modes.add(PlaybackMode.ORIGINAL)
            }
        }
        return if (modes.isEmpty()) listOf(PlaybackMode.DIRECT) else modes
    }

    private fun parseStrings(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        val result = mutableListOf<String>()
        for (i in 0 until array.length()) {
            val value = array.optString(i)
            if (value.isNotEmpty()) result.add(value)
        }
        return result
    }
}
