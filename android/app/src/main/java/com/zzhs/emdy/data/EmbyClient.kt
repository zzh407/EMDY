package com.zzhs.emdy.data

import com.zzhs.emdy.EmdyApp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

/**
 * Emby 服务端接口封装（与 HarmonyOS 版行为对齐）：
 * 登录 / 媒体库 / 视频分页（Tags/Genres 服务端筛选）/ 删除 / 媒体库扫描
 */
class EmbyClient(
    private val serverUrl: String,
    private val accessToken: String = "",
    private val userId: String = ""
) {

    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    private val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private fun enc(value: String): String = URLEncoder.encode(value, "UTF-8")

    private fun authHeader(): String =
        "MediaBrowser Client=\"EMDY\", Device=\"Android\", " +
            "DeviceId=\"${EmdyApp.deviceId}\", Version=\"1.4.0\""

    private suspend fun request(
        path: String,
        method: String,
        body: String = "",
        includeToken: Boolean
    ): String = withContext(Dispatchers.IO) {
        val builder = Request.Builder()
            .url("$serverUrl$path")
            .header("Accept", "application/json")
            .header("X-Emby-Authorization", authHeader())
        if (includeToken) {
            builder.header("X-Emby-Token", accessToken)
        }
        when (method) {
            "POST" -> builder.method(method, body.toRequestBody("application/json".toMediaType()))
            "DELETE" -> builder.method(method, null)
            else -> builder.method(method, null)
        }
        http.newCall(builder.build()).execute().use { response ->
            val text = response.body?.string() ?: ""
            if (!response.isSuccessful) {
                when (response.code) {
                    401 -> throw IOException("用户名、密码或登录令牌无效")
                    403 -> throw IOException("没有删除权限，请确认账号拥有 Emby 删除媒体权限")
                    404 -> throw IOException("视频不存在或服务器不支持该操作")
                    else -> throw IOException("Emby 服务器返回错误：${response.code}")
                }
            }
            text
        }
    }

    suspend fun authenticate(userName: String, password: String): EmbySession {
        if (serverUrl.isBlank()) throw IOException("请输入 Emby 服务器地址")
        val body = json.encodeToString(
            kotlinx.serialization.json.JsonObject.serializer(),
            kotlinx.serialization.json.buildJsonObject {
                put("Username", kotlinx.serialization.json.JsonPrimitive(userName.trim()))
                put("Pw", kotlinx.serialization.json.JsonPrimitive(password))
            }
        )
        val text = request("/emby/Users/AuthenticateByName", "POST", body, includeToken = false)
        val auth = json.decodeFromString<EmbyAuthDto>(text)
        val token = auth.AccessToken ?: ""
        val userId = auth.User?.Id ?: ""
        val displayName = auth.User?.Name ?: userName.trim()
        if (token.isEmpty() || userId.isEmpty()) throw IOException("服务器返回的登录信息不完整")
        return EmbySession(serverUrl, token, userId, displayName)
    }

    suspend fun getLibraries(): List<EmbyLibrary> {
        requireAuth()
        val text = request("/emby/Users/${enc(userId)}/Views?IncludeExternalContent=false", "GET", "", true)
        val views = json.decodeFromString<EmbyViewsDto>(text)
        val libraries = mutableListOf(EmbyLibrary.ALL)
        views.Items?.forEach { item ->
            val id = item.Id ?: ""
            if (id.isEmpty()) return@forEach
            libraries.add(EmbyLibrary(id, item.Name ?: "未命名媒体库", item.CollectionType ?: "unknown"))
        }
        return libraries
    }

    suspend fun getVideos(
        startIndex: Int = 0,
        limit: Int = 20,
        query: EmbyVideoQuery = EmbyVideoQuery()
    ): EmbyVideoPage {
        requireAuth()
        val parentFilter = if (query.libraryId.isNotEmpty()) "&ParentId=${enc(query.libraryId)}" else ""
        val tagsFilter = if (query.tags.isNotEmpty()) "&Tags=${enc(query.tags)}" else ""
        val genresFilter = if (query.genres.isNotEmpty()) "&Genres=${enc(query.genres)}" else ""
        val baseQuery = "StartIndex=$startIndex&Limit=$limit&Recursive=true$parentFilter$tagsFilter$genresFilter" +
            "&Fields=Overview,MediaStreams,Container,MediaSources,People,Studios,Tags,Genres,PremiereDate,ProductionYear" +
            "&EnableImages=true&ImageTypeLimit=1"
        val sortClause = if (query.random) "SortBy=Random" else "SortBy=DateCreated&SortOrder=Descending"
        val variants = buildList {
            add("$baseQuery&$sortClause&IncludeItemTypes=Video")
            add("$baseQuery&IncludeItemTypes=Video")
            add("$baseQuery&IncludeItemTypes=Episode")
            add("$baseQuery&IncludeItemTypes=Movie")
            if (query.libraryId.isEmpty()) add("$baseQuery&$sortClause")
        }

        var firstError: String = ""
        for (variant in variants) {
            try {
                val text = request("/emby/Users/${enc(userId)}/Items?$variant", "GET", "", true)
                val response = json.decodeFromString<EmbyItemsDto>(text)
                val items = toVideos(response.Items ?: emptyList(), query.hideCollections, startIndex)
                if (items.isNotEmpty()) {
                    return EmbyVideoPage(items, response.TotalRecordCount ?: items.size)
                }
            } catch (error: Exception) {
                val message = error.message
                if (firstError.isEmpty()) {
                    firstError = if (!message.isNullOrEmpty()) message else "视频列表请求失败"
                }
            }
        }
        if (firstError.isNotEmpty()) throw IOException(firstError)
        return EmbyVideoPage(emptyList(), 0)
    }

    suspend fun deleteItem(itemId: String) {
        requireAuth()
        if (itemId.isEmpty()) throw IOException("视频 ID 为空，无法删除")
        request("/Items/${enc(itemId)}", "DELETE", "", true)
    }

    suspend fun refreshItem(itemId: String) {
        requireAuth()
        if (itemId.isEmpty()) throw IOException("媒体库 ID 为空，无法扫描")
        request(
            "/Items/${enc(itemId)}/Refresh?Recursive=true&MetadataRefreshMode=FullRefresh&ImageRefreshMode=FullRefresh",
            "POST", "", true
        )
    }

    private fun requireAuth() {
        if (accessToken.isEmpty() || userId.isEmpty()) {
            throw IOException("登录状态已失效，请重新连接")
        }
    }

    // ---------- 解析（对齐 HarmonyOS 版 toVideos） ----------

    private val unsupportedContainers = setOf(
        "avi", "wmv", "mpeg", "mpg", "rmvb", "rm", "flv", "asf", "vob", "divx", "mkv"
    )

    private val collectionTypes = setOf(
        "boxset", "manualplaylistsfolder", "playlist", "collectionfolder", "folder", "channel", "channelFolderItem"
    )

    private fun isCollection(item: EmbyItemDto): Boolean {
        if (item.IsFolder == true) return true
        val type = item.Type?.lowercase()
        if (type != null && collectionTypes.contains(type)) return true
        val ct = item.CollectionType?.lowercase()
        if (ct != null && collectionTypes.contains(ct)) return true
        return false
    }

    private fun toVideos(
        sourceItems: List<EmbyItemDto>,
        hideCollections: Boolean,
        startIndex: Int
    ): List<EmbyVideo> {
        val items = mutableListOf<EmbyVideo>()
        var index = 0
        sourceItems.forEach { item ->
            if (hideCollections && isCollection(item)) return@forEach
            items.add(toVideo(item, startIndex + index + 1))
            index++
        }
        return items
    }

    private fun toVideo(item: EmbyItemDto, originalIndex: Int): EmbyVideo {
        val id = item.Id ?: ""
        val name = item.Name ?: "未命名视频"
        val overview = item.Overview ?: ""
        val imageItemId = item.PrimaryImageItemId ?: id
        var width = 0
        var height = 0
        item.MediaStreams?.firstOrNull { it.Type == "Video" }?.let { stream ->
            width = stream.Width ?: 0
            height = stream.Height ?: 0
        }
        val modes = buildPlaybackModes(item)
        return EmbyVideo(
            id = id,
            name = name,
            overview = overview,
            imageUrl = buildImageUrl(imageItemId),
            streamUrl = buildUrl(id, modes.first()),
            durationText = formatDuration(item.RuntimeTicks ?: 0),
            authorName = buildAuthorName(item),
            authorAvatar = buildAuthorAvatar(item),
            width = width,
            height = height,
            playbackModes = modes,
            directStreamUrl = buildUrl(id, PlaybackMode.DIRECT),
            hlsStreamUrl = buildUrl(id, PlaybackMode.HLS),
            originalStreamUrl = buildUrl(id, PlaybackMode.ORIGINAL),
            originalIndex = originalIndex,
            tags = readTags(item),
            genres = readGenres(item)
        )
    }

    private fun pickAuthor(item: EmbyItemDto): EmbyPersonDto? {
        val people = item.People ?: emptyList()
        people.firstOrNull { it.Type == "Director" }?.let { return it }
        people.firstOrNull { it.Type == "Writer" }?.let { return it }
        return people.firstOrNull { !it.Name.isNullOrEmpty() }
    }

    private fun pickStudio(item: EmbyItemDto): EmbyStudioDto? =
        (item.Studios ?: emptyList()).firstOrNull { !it.Name.isNullOrEmpty() }

    private fun buildAuthorName(item: EmbyItemDto): String {
        pickAuthor(item)?.let { if (!it.Name.isNullOrEmpty()) return it.Name }
        pickStudio(item)?.let { if (!it.Name.isNullOrEmpty()) return it.Name }
        return ""
    }

    private fun buildAuthorAvatar(item: EmbyItemDto): String {
        pickAuthor(item)?.let { if (!it.Id.isNullOrEmpty()) return buildImageUrl(it.Id, 160) }
        pickStudio(item)?.let { if (!it.Id.isNullOrEmpty()) return buildImageUrl(it.Id, 160) }
        return ""
    }

    private fun readTags(item: EmbyItemDto): List<String> =
        (item.Tags ?: emptyList()).map { it.trim() }.filter { it.isNotEmpty() }

    private fun readGenres(item: EmbyItemDto): List<String> =
        (item.Genres ?: emptyList()).map { it.trim() }.filter { it.isNotEmpty() }

    private fun buildPlaybackModes(item: EmbyItemDto): List<PlaybackMode> {
        val container = readContainer(item)
        return if (container.isNotEmpty() && unsupportedContainers.contains(container)) {
            listOf(PlaybackMode.HLS, PlaybackMode.DIRECT, PlaybackMode.ORIGINAL)
        } else {
            listOf(PlaybackMode.DIRECT, PlaybackMode.HLS, PlaybackMode.ORIGINAL)
        }
    }

    private fun readContainer(item: EmbyItemDto): String {
        if (!item.Container.isNullOrEmpty()) return item.Container.lowercase()
        (item.MediaSources ?: emptyList()).firstOrNull { !it.Container.isNullOrEmpty() }?.let {
            return it.Container!!.lowercase()
        }
        val path = item.Path ?: ""
        val dot = path.lastIndexOf('.')
        if (dot > 0 && dot < path.length - 1) return path.substring(dot + 1).lowercase()
        return ""
    }

    private fun buildUrl(itemId: String, mode: PlaybackMode): String = when (mode) {
        PlaybackMode.HLS ->
            "$serverUrl/emby/Videos/${enc(itemId)}/master.m3u8" +
                "?VideoCodec=h264&AudioCodec=aac&SegmentContainer=ts&MaxWidth=1280&VideoBitrate=6000000" +
                "&AudioBitrate=192000&EnableAdaptiveBitrateStreaming=false&BreakOnNonKeyFrames=false" +
                "&api_key=${enc(accessToken)}&DeviceId=${enc(EmdyApp.deviceId)}"
        PlaybackMode.ORIGINAL ->
            "$serverUrl/emby/Videos/${enc(itemId)}/original" +
                "?api_key=${enc(accessToken)}&DeviceId=${enc(EmdyApp.deviceId)}"
        PlaybackMode.DIRECT ->
            "$serverUrl/emby/Videos/${enc(itemId)}/stream" +
                "?Static=true&api_key=${enc(accessToken)}&DeviceId=${enc(EmdyApp.deviceId)}"
    }

    private fun buildImageUrl(itemId: String, maxWidth: Int = 1080): String =
        "$serverUrl/emby/Items/${enc(itemId)}/Images/Primary" +
            "?maxWidth=$maxWidth&quality=85&api_key=${enc(accessToken)}"

    private fun formatDuration(runtimeTicks: Long): String {
        if (runtimeTicks <= 0) return ""
        val totalSeconds = (runtimeTicks / 10_000_000).toInt()
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }

    companion object {
        fun normalizeServerUrl(value: String): String {
            var normalized = value.trim()
            if (normalized.isEmpty()) return ""
            if (!normalized.lowercase().startsWith("http://") &&
                !normalized.lowercase().startsWith("https://")
            ) {
                normalized = "http://$normalized"
            }
            while (normalized.endsWith("/")) {
                normalized = normalized.substring(0, normalized.length - 1)
            }
            if (normalized.lowercase().endsWith("/emby")) {
                normalized = normalized.substring(0, normalized.length - 5)
            }
            return normalized
        }
    }
}
