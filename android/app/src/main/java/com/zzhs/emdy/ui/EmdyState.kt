package com.zzhs.emdy.ui

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zzhs.emdy.data.AppSettings
import com.zzhs.emdy.data.EmbyClient
import com.zzhs.emdy.data.EmbyLibrary
import com.zzhs.emdy.data.EmbySession
import com.zzhs.emdy.data.EmbyVideo
import com.zzhs.emdy.data.EmbyVideoPage
import com.zzhs.emdy.data.EmbyVideoQuery
import com.zzhs.emdy.data.FavoriteStore
import com.zzhs.emdy.data.SessionStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 全局状态与业务逻辑（对齐 HarmonyOS 版 Index 结构体）
 */
class EmdyState(private val context: Context, private val scope: CoroutineScope) {

    // ---------- 会话与连接 ----------
    var session by mutableStateOf<EmbySession?>(null)
        private set
    var client by mutableStateOf<EmbyClient?>(null)
        private set
    var isConnecting by mutableStateOf(false)
        private set

    // ---------- 登录表单 ----------
    var serverUrl by mutableStateOf("")
    var userName by mutableStateOf("")
    var password by mutableStateOf("")
    var rememberLogin by mutableStateOf(false)
    var loginError by mutableStateOf("")

    // ---------- 信息流 ----------
    var videos by mutableStateOf<List<EmbyVideo>>(emptyList())
        private set
    var currentIndex by mutableStateOf(0)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf("")
    var hasMore by mutableStateOf(true)
        private set
    private var feedSourceCount = 0
    var totalRecordCount by mutableStateOf(0)
        private set

    // ---------- 筛选 ----------
    var filterAuthorName by mutableStateOf("")
        private set
    var filterTagName by mutableStateOf("")
        private set
    var filterTagKind by mutableStateOf("")
        private set
    var selectedLibraryId by mutableStateOf("")
        private set
    var selectedLibraryName by mutableStateOf("全部媒体库")
        private set
    private var resumeLibraryId = ""
    private var resumeLibraryName = ""
    private var resumeShuffle = false

    // ---------- 媒体库 ----------
    var libraries by mutableStateOf<List<EmbyLibrary>>(emptyList())
        private set
    var libraryPickerVisible by mutableStateOf(false)

    // ---------- 收藏 ----------
    var favorites by mutableStateOf<List<EmbyVideo>>(emptyList())
        private set

    // ---------- 设置 ----------
    var shufflePlayback by mutableStateOf(false)
        private set
    var hideCollections by mutableStateOf(false)
        private set
    var fastSpeed by mutableStateOf(2.0f)
        private set
    var optionsVisible by mutableStateOf(false)

    // ---------- 播放 ----------
    var muted by mutableStateOf(true)
    var showControls by mutableStateOf(true)

    // ---------- 媒体网格 ----------
    var mediaListVisible by mutableStateOf(false)
    var mediaListItems by mutableStateOf<List<EmbyVideo>>(emptyList())
        private set
    var mediaListTotal by mutableStateOf(0)
        private set
    var mediaListHasMore by mutableStateOf(true)
        private set
    var mediaListLoading by mutableStateOf(false)
        private set
    var multiSelectMode by mutableStateOf(false)
        private set
    var selectedIds by mutableStateOf<List<String>>(emptyList())
        private set

    // ---------- 删除 ----------
    var deletePending by mutableStateOf(false)
        private set
    var batchDeletePending by mutableStateOf(false)
        private set
    var deleteConfirmVisible by mutableStateOf(false)
        private set
    var deleteConfirmItem by mutableStateOf<EmbyVideo?>(null)
        private set
    var deleteConfirmMode by mutableStateOf("single")
        private set

    // ---------- 提示 ----------
    var hintText by mutableStateOf("")
        private set
    private var hintJob: kotlinx.coroutines.Job? = null

    fun isFiltered(): Boolean = filterAuthorName.isNotEmpty() || filterTagName.isNotEmpty()

    fun libraryButtonLabel(): String = when {
        filterTagName.isNotEmpty() -> {
            val tag = if (filterTagName.length > 5) filterTagName.substring(0, 5) + "…" else filterTagName
            "#$tag"
        }
        filterAuthorName.isNotEmpty() -> {
            val name = if (filterAuthorName.length > 5) filterAuthorName.substring(0, 5) + "…" else filterAuthorName
            "@$name"
        }
        else -> {
            val name = if (selectedLibraryName.length > 6) selectedLibraryName.substring(0, 6) + "…" else selectedLibraryName
            "库：$name"
        }
    }

    fun feedCounter(): String {
        if (filterAuthorName.isNotEmpty()) return "${currentIndex + 1}/${videos.size}"
        return "${currentIndex + 1}/$totalRecordCount"
    }

    fun showHint(message: String) {
        hintJob?.cancel()
        hintText = message
        hintJob = scope.launch {
            kotlinx.coroutines.delay(1600)
            hintText = ""
        }
    }

    fun cancelHint() {
        hintJob?.cancel()
        hintText = ""
    }

    // ---------- 初始化 ----------

    fun init() {
        scope.launch {
            hideCollections = AppSettings.loadHideCollections(context)
            shufflePlayback = AppSettings.loadShuffle(context)
            fastSpeed = AppSettings.loadFastSpeed(context)
            favorites = FavoriteStore.load(context)
            val savedLogin = AppSettings.loadLogin(context)
            rememberLogin = savedLogin[0] == "1"
            val savedSession = SessionStore.load(context)
            if (savedSession != null) {
                session = savedSession
                client = EmbyClient(savedSession.serverUrl, savedSession.accessToken, savedSession.userId)
                selectedLibraryId = SessionStore.loadLibraryId(context)
                loadLibraries()
                loadVideos(true)
            } else if (rememberLogin) {
                serverUrl = savedLogin[1]
                userName = savedLogin[2]
                password = savedLogin[3]
            }
        }
    }

    // ---------- 登录 ----------

    fun login() {
        if (serverUrl.isBlank() || userName.isBlank()) {
            loginError = "请填写服务器地址和用户名"
            return
        }
        scope.launch {
            isConnecting = true
            loginError = ""
            try {
                val normalized = EmbyClient.normalizeServerUrl(serverUrl)
                val loginClient = EmbyClient(normalized)
                val newSession = loginClient.authenticate(userName.trim(), password)
                SessionStore.save(context, newSession)
                if (rememberLogin) {
                    AppSettings.saveLogin(context, newSession.serverUrl, newSession.userName, password)
                } else {
                    AppSettings.clearLogin(context)
                }
                session = newSession
                serverUrl = newSession.serverUrl
                userName = newSession.userName
                password = ""
                client = EmbyClient(newSession.serverUrl, newSession.accessToken, newSession.userId)
                selectedLibraryId = SessionStore.loadLibraryId(context)
                loadLibraries()
                loadVideos(true)
            } catch (error: Exception) {
                loginError = error.message ?: "登录失败，请检查服务器地址和网络"
            } finally {
                isConnecting = false
            }
        }
    }

    fun changeServer() {
        scope.launch {
            SessionStore.clear(context)
            session = null
            client = null
            videos = emptyList()
            currentIndex = 0
            totalRecordCount = 0
            errorMessage = ""
            optionsVisible = false
        }
    }

    // ---------- 媒体库 ----------

    fun openLibraryPicker() {
        libraryPickerVisible = true
        loadLibraries()
    }

    fun loadLibraries() {
        val current = client ?: return
        scope.launch {
            try {
                libraries = current.getLibraries()
            } catch (_: Exception) {
            }
        }
    }

    fun selectLibrary(library: EmbyLibrary) {
        if (isFiltered()) {
            filterAuthorName = ""
            filterTagName = ""
            filterTagKind = ""
        }
        selectedLibraryId = library.id
        selectedLibraryName = library.name
        libraryPickerVisible = false
        scope.launch { SessionStore.saveLibraryId(context, library.id) }
        loadVideos(true)
    }

    // ---------- 视频加载 ----------

    fun loadVideos(reset: Boolean) {
        val current = client ?: return
        if (isLoading) return
        if (selectedLibraryId == "favorites") {
            if (reset) {
                videos = favorites
                totalRecordCount = favorites.size
                hasMore = false
                currentIndex = 0
            }
            return
        }
        isLoading = true
        errorMessage = ""
        if (reset) {
            currentIndex = 0
            videos = emptyList()
            totalRecordCount = 0
            hasMore = true
            feedSourceCount = 0
        }
        scope.launch {
            try {
                if (filterAuthorName.isNotEmpty()) {
                    // 作者筛选：全库拉取 + 客户端过滤（作者名来自 People，服务端无稳定过滤参数）
                    val query = EmbyVideoQuery(libraryId = "", hideCollections = hideCollections)
                    val collected = mutableListOf<EmbyVideo>()
                    var start = 0
                    var guard = 0
                    while (guard < 100) {
                        val page = current.getVideos(start, PAGE_SIZE, query)
                        collected.addAll(page.items.filter { it.authorName == filterAuthorName })
                        if (page.items.isEmpty() || start + page.items.size >= page.totalRecordCount) break
                        start += page.items.size
                        guard++
                    }
                    videos = collected
                    totalRecordCount = collected.size
                    hasMore = false
                    feedSourceCount = collected.size
                    if (collected.isEmpty()) showHint("未找到该作者的其他视频")
                } else {
                    val query = EmbyVideoQuery(
                        libraryId = selectedLibraryId,
                        hideCollections = hideCollections,
                        random = shufflePlayback && reset,
                        tags = filterTagName.takeIf { filterTagKind == "tags" } ?: "",
                        genres = filterTagName.takeIf { filterTagKind == "genres" } ?: ""
                    )
                    if (shufflePlayback && reset) {
                        // 随机播放：全量拉取后洗牌
                        val all = mutableListOf<EmbyVideo>()
                        var start = 0
                        var guard = 0
                        while (guard < 100) {
                            val page = current.getVideos(start, PAGE_SIZE, query)
                            all.addAll(page.items)
                            if (page.items.isEmpty() || all.size >= page.totalRecordCount) break
                            start += page.items.size
                            guard++
                        }
                        videos = all.shuffled()
                        totalRecordCount = all.size
                        hasMore = false
                        feedSourceCount = all.size
                    } else {
                        val page = current.getVideos(feedSourceCount, PAGE_SIZE, query)
                        if (reset) {
                            videos = page.items
                        } else {
                            val existing = videos.map { it.id }.toSet()
                            videos = videos + page.items.filter { it.id !in existing }
                        }
                        feedSourceCount += page.items.size
                        totalRecordCount = page.totalRecordCount
                        hasMore = videos.size < page.totalRecordCount && page.items.isNotEmpty()
                    }
                }
                if (videos.isEmpty()) errorMessage = "没有找到视频"
            } catch (error: Exception) {
                errorMessage = error.message ?: "加载失败"
            } finally {
                isLoading = false
            }
        }
    }

    fun handlePlaybackEnd() {
        if (videos.isEmpty()) return
        val isLast = currentIndex >= videos.size - 1
        if (isLast && hasMore) {
            loadVideos(false)
            return
        }
        if (isLast) {
            if (shufflePlayback) {
                videos = videos.shuffled()
                currentIndex = 0
                showHint("没有更多视频，已重新随机")
                return
            }
            showHint("已经是最后一个视频")
            return
        }
        currentIndex = currentIndex + 1
    }

    // ---------- 筛选 ----------

    fun openAuthorFeed(item: EmbyVideo) {
        if (client == null) {
            showHint("尚未连接服务器")
            return
        }
        val author = item.authorName
        if (filterAuthorName == author) return
        if (!isFiltered()) {
            resumeLibraryId = selectedLibraryId
            resumeLibraryName = selectedLibraryName
            resumeShuffle = shufflePlayback
        }
        filterAuthorName = author
        filterTagName = ""
        filterTagKind = ""
        if (shufflePlayback) {
            shufflePlayback = false
            scope.launch { AppSettings.saveShuffle(context, false) }
        }
        selectedLibraryId = ""
        selectedLibraryName = if (author.isNotEmpty()) "@$author" else "未标注作者"
        showHint(if (author.isNotEmpty()) "正在筛选 @$author 的视频" else "正在筛选未标注作者的视频")
        mediaListVisible = false
        loadVideos(true)
    }

    fun openTagFeed(tag: String, kind: String) {
        if (client == null) {
            showHint("尚未连接服务器")
            return
        }
        if (filterTagName == tag && filterTagKind == kind) return
        if (!isFiltered()) {
            resumeLibraryId = selectedLibraryId
            resumeLibraryName = selectedLibraryName
            resumeShuffle = shufflePlayback
        }
        filterTagName = tag
        filterTagKind = kind
        filterAuthorName = ""
        if (shufflePlayback) {
            shufflePlayback = false
            scope.launch { AppSettings.saveShuffle(context, false) }
        }
        selectedLibraryName = "#$tag"
        showHint("正在筛选 #$tag 的视频")
        mediaListVisible = false
        loadVideos(true)
    }

    fun clearFilter() {
        if (!isFiltered()) return
        filterAuthorName = ""
        filterTagName = ""
        filterTagKind = ""
        selectedLibraryId = resumeLibraryId
        selectedLibraryName = resumeLibraryName
        if (resumeShuffle && !shufflePlayback) {
            shufflePlayback = true
            scope.launch { AppSettings.saveShuffle(context, true) }
        }
        showHint("已恢复全部视频")
        loadVideos(true)
    }

    // ---------- 收藏 ----------

    fun isFavoriteVideo(video: EmbyVideo): Boolean = favorites.any { it.id == video.id }

    fun toggleFavorite(item: EmbyVideo) {
        val exists = favorites.any { it.id == item.id }
        favorites = if (exists) favorites.filter { it.id != item.id } else favorites + item
        showHint(if (exists) "已取消喜欢" else "已加入喜欢")
        scope.launch { FavoriteStore.save(context, favorites) }
        if (selectedLibraryId == "favorites") {
            videos = favorites
            totalRecordCount = favorites.size
        }
    }

    // ---------- 播放设置 ----------

    fun togglePlayMode() {
        shufflePlayback = !shufflePlayback
        scope.launch { AppSettings.saveShuffle(context, shufflePlayback) }
        loadVideos(true)
    }

    fun toggleHideCollections() {
        hideCollections = !hideCollections
        scope.launch { AppSettings.saveHideCollections(context, hideCollections) }
        loadVideos(true)
    }

    fun setFastSpeed(speed: Float) {
        fastSpeed = speed
        scope.launch { AppSettings.saveFastSpeed(context, speed) }
    }

    fun setRememberLogin(value: Boolean) {
        rememberLogin = value
        scope.launch {
            if (value) {
                AppSettings.saveLogin(context, serverUrl, userName, password)
            } else {
                AppSettings.clearLogin(context)
            }
        }
    }

    // ---------- 媒体库扫描 ----------

    fun refreshMediaLibrary() {
        val current = client ?: run {
            showHint("尚未连接服务器")
            return
        }
        if (isLoading || mediaListLoading) {
            showHint("正在加载中，请稍候")
            return
        }
        if (selectedLibraryId == "favorites") {
            showHint("「喜欢」是本地收藏，无需扫描")
            return
        }
        optionsVisible = false
        showHint("正在通知服务器扫描媒体库…")
        scope.launch {
            try {
                if (selectedLibraryId.isNotEmpty()) {
                    current.refreshItem(selectedLibraryId)
                } else {
                    libraries.filter { it.id != "favorites" }.forEach { library ->
                        current.refreshItem(library.id)
                    }
                }
                showHint("媒体库扫描已开始，新内容稍后自动可见")
            } catch (error: Exception) {
                showHint("扫描失败：${error.message ?: "未知错误"}")
            }
        }
    }

    // ---------- 媒体网格 ----------

    fun openMediaList() {
        multiSelectMode = false
        selectedIds = emptyList()
        mediaListVisible = true
        mediaListItems = emptyList()
        mediaListTotal = 0
        mediaListHasMore = true
        mediaListLoading = false
        loadMediaListPage()
    }

    fun loadMediaListPage() {
        val current = client ?: return
        if (mediaListLoading || !mediaListHasMore) return
        if (selectedLibraryId == "favorites") {
            mediaListItems = favorites
            mediaListTotal = favorites.size
            mediaListHasMore = false
            return
        }
        mediaListLoading = true
        scope.launch {
            try {
                val query = EmbyVideoQuery(
                    libraryId = selectedLibraryId,
                    hideCollections = hideCollections
                )
                val page = current.getVideos(mediaListItems.size, PAGE_SIZE, query)
                val existing = mediaListItems.map { it.id }.toSet()
                mediaListItems = mediaListItems + page.items.filter { it.id !in existing }
                mediaListTotal = page.totalRecordCount
                mediaListHasMore = mediaListItems.size < page.totalRecordCount && page.items.isNotEmpty()
            } catch (error: Exception) {
                errorMessage = error.message ?: "加载失败"
            } finally {
                mediaListLoading = false
            }
        }
    }

    fun playFromList(item: EmbyVideo) {
        multiSelectMode = false
        selectedIds = emptyList()
        mediaListVisible = false
        val index = videos.indexOfFirst { it.id == item.id }
        if (index >= 0) {
            currentIndex = index
            return
        }
        videos = listOf(item) + videos
        currentIndex = 0
    }

    fun enterMultiSelect(item: EmbyVideo) {
        if (batchDeletePending) return
        multiSelectMode = true
        if (item.id !in selectedIds) selectedIds = selectedIds + item.id
    }

    fun exitMultiSelect() {
        if (batchDeletePending) return
        multiSelectMode = false
        selectedIds = emptyList()
    }

    fun toggleSelect(item: EmbyVideo) {
        if (batchDeletePending) return
        selectedIds = if (item.id in selectedIds) {
            selectedIds.filter { it != item.id }
        } else {
            selectedIds + item.id
        }
    }

    fun toggleSelectAll() {
        if (batchDeletePending) return
        selectedIds = if (selectedIds.size >= mediaListItems.size && mediaListItems.isNotEmpty()) {
            emptyList()
        } else {
            mediaListItems.map { it.id }
        }
    }

    // ---------- 删除 ----------

    fun confirmDeleteVideo(item: EmbyVideo) {
        if (deletePending) return
        deleteConfirmItem = item
        deleteConfirmMode = "single"
        deleteConfirmVisible = true
    }

    fun confirmBatchDelete() {
        if (batchDeletePending || selectedIds.isEmpty()) return
        deleteConfirmMode = "batch"
        deleteConfirmVisible = true
    }

    fun dismissDeleteConfirm() {
        deleteConfirmVisible = false
        deleteConfirmItem = null
    }

    fun deleteCurrentVideo(item: EmbyVideo) {
        val current = client ?: return
        if (deletePending) return
        deletePending = true
        showHint("正在删除…")
        scope.launch {
            try {
                withContext(Dispatchers.IO) { current.deleteItem(item.id) }
                removeFavoriteRecord(item.id)
                if (totalRecordCount > 0) totalRecordCount -= 1
                val deletedIndex = videos.indexOfFirst { it.id == item.id }
                if (deletedIndex < 0) {
                    showHint("已删除")
                    return@launch
                }
                if (videos.size <= 1) {
                    videos = emptyList()
                    feedSourceCount = 0
                    currentIndex = 0
                    showHint("已删除，正在重新加载列表")
                    loadVideos(true)
                    return@launch
                }
                videos = videos.filter { it.id != item.id }
                if (feedSourceCount > 0) feedSourceCount -= 1
                if (currentIndex >= videos.size) currentIndex = videos.size - 1
                showHint("已删除")
            } catch (error: Exception) {
                showHint("删除失败：${error.message ?: "未知错误"}")
            } finally {
                deletePending = false
            }
        }
    }

    fun batchDeleteSelected() {
        val current = client ?: return
        if (batchDeletePending || selectedIds.isEmpty()) return
        val ids = selectedIds.toList()
        batchDeletePending = true
        showHint("正在删除 ${ids.size} 个视频…")
        scope.launch {
            val success = mutableListOf<String>()
            var failCount = 0
            for (id in ids) {
                try {
                    withContext(Dispatchers.IO) { current.deleteItem(id) }
                    success.add(id)
                } catch (_: Exception) {
                    failCount++
                }
            }
            if (success.isNotEmpty()) {
                val deletedSet = success.toSet()
                mediaListItems = mediaListItems.filter { it.id !in deletedSet }
                if (mediaListTotal >= success.size) mediaListTotal -= success.size
                val removedFavs = favorites.count { it.id in deletedSet }
                if (removedFavs > 0) {
                    favorites = favorites.filter { it.id !in deletedSet }
                    FavoriteStore.save(context, favorites)
                }
                if (totalRecordCount >= success.size) totalRecordCount -= success.size
                syncFeedAfterBatchDelete(deletedSet)
                selectedIds = emptyList()
            }
            multiSelectMode = false
            batchDeletePending = false
            showHint(
                if (failCount > 0) "已删除 ${success.size} 个，$failCount 个失败"
                else "已删除 ${success.size} 个视频"
            )
        }
    }

    private fun syncFeedAfterBatchDelete(deletedSet: Set<String>) {
        if (videos.isEmpty()) return
        val currentId = videos.getOrNull(currentIndex)?.id ?: ""
        var removedBefore = 0
        for (i in 0 until minOf(currentIndex, videos.size)) {
            if (videos[i].id in deletedSet) removedBefore++
        }
        videos = videos.filter { it.id !in deletedSet }
        feedSourceCount = videos.size
        if (currentId.isEmpty()) return
        if (currentId in deletedSet) {
            if (videos.isEmpty()) {
                currentIndex = 0
                loadVideos(true)
                return
            }
            val target = (currentIndex - removedBefore).coerceIn(0, videos.size - 1)
            currentIndex = target
        } else {
            currentIndex = (currentIndex - removedBefore).coerceAtLeast(0)
        }
    }

    private fun removeFavoriteRecord(id: String) {
        if (favorites.any { it.id == id }) {
            favorites = favorites.filter { it.id != id }
            scope.launch { FavoriteStore.save(context, favorites) }
        }
    }

    companion object {
        const val PAGE_SIZE = 20
    }
}
