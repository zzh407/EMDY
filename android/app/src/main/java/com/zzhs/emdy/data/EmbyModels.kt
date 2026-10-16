package com.zzhs.emdy.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 播放模式：直播放 / 转码 HLS / 原盘流 */
enum class PlaybackMode { DIRECT, HLS, ORIGINAL }

data class EmbyVideo(
    val id: String = "",
    val name: String = "",
    val overview: String = "",
    val imageUrl: String = "",
    val streamUrl: String = "",
    val durationText: String = "",
    val authorName: String = "",
    val authorAvatar: String = "",
    val width: Int = 0,
    val height: Int = 0,
    val playbackModes: List<PlaybackMode> = listOf(PlaybackMode.DIRECT),
    val directStreamUrl: String = "",
    val hlsStreamUrl: String = "",
    val originalStreamUrl: String = "",
    val originalIndex: Int = 0,
    val tags: List<String> = emptyList(),
    val genres: List<String> = emptyList()
) {
    fun authorInitial(): String =
        if (authorName.isNotEmpty()) authorName.substring(0, 1) else "?"

    fun isPortrait(): Boolean = width > 0 && height > width

    fun urlOf(mode: PlaybackMode): String = when (mode) {
        PlaybackMode.HLS -> hlsStreamUrl
        PlaybackMode.ORIGINAL -> originalStreamUrl
        PlaybackMode.DIRECT -> directStreamUrl
    }

    /** 合并 Genres（nfo genre）与 Tags，去重，genres 在前 */
    fun tagLabels(): List<Pair<String, String>> {
        val labels = mutableListOf<Pair<String, String>>()
        genres.forEach { name -> if (labels.none { it.first == name }) labels.add(name to "genres") }
        tags.forEach { name -> if (labels.none { it.first == name }) labels.add(name to "tags") }
        return labels
    }
}

data class EmbyLibrary(
    val id: String = "",
    val name: String = "",
    val collectionType: String = ""
) {
    companion object {
        /** "全部媒体库" 占位项（用于下拉选择器的首项） */
        val ALL = EmbyLibrary(id = "all", name = "全部媒体库", collectionType = "")
    }
}

data class EmbySession(
    val serverUrl: String = "",
    val accessToken: String = "",
    val userId: String = "",
    val userName: String = ""
)

data class EmbyVideoPage(
    val items: List<EmbyVideo> = emptyList(),
    val totalRecordCount: Int = 0
)

data class EmbyVideoQuery(
    val libraryId: String = "",
    val hideCollections: Boolean = false,
    val random: Boolean = false,
    val tags: String = "",
    val genres: String = ""
)

// ---------- Emby API DTO ----------

@Serializable
data class EmbyAuthDto(
    val AccessToken: String? = null,
    val User: EmbyUserDto? = null
)

@Serializable
data class EmbyUserDto(
    val Id: String? = null,
    val Name: String? = null
)

@Serializable
data class EmbyPersonDto(
    val Id: String? = null,
    val Name: String? = null,
    val Type: String? = null
)

@Serializable
data class EmbyStudioDto(
    val Id: String? = null,
    val Name: String? = null
)

@Serializable
data class EmbyMediaStreamDto(
    val Type: String? = null,
    val Width: Int? = null,
    val Height: Int? = null
)

@Serializable
data class EmbyMediaSourceDto(
    val Container: String? = null
)

@Serializable
data class EmbyItemDto(
    val Id: String? = null,
    val Name: String? = null,
    val Type: String? = null,
    val Overview: String? = null,
    val PremiereDate: String? = null,
    val ProductionYear: Int? = null,
    val RuntimeTicks: Long? = null,
    val PrimaryImageItemId: String? = null,
    val CollectionType: String? = null,
    val Path: String? = null,
    val IsFolder: Boolean? = null,
    val Container: String? = null,
    val People: List<EmbyPersonDto>? = null,
    val Studios: List<EmbyStudioDto>? = null,
    val Tags: List<String>? = null,
    val Genres: List<String>? = null,
    val MediaSources: List<EmbyMediaSourceDto>? = null,
    val MediaStreams: List<EmbyMediaStreamDto>? = null
)

@Serializable
data class EmbyItemsDto(
    val Items: List<EmbyItemDto>? = null,
    val TotalRecordCount: Int? = null
)

@Serializable
data class EmbyViewsDto(
    val Items: List<EmbyItemDto>? = null,
    val TotalRecordCount: Int? = null
)
