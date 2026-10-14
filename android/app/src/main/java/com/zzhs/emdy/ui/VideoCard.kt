package com.zzhs.emdy.ui

import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import coil.compose.AsyncImage
import com.zzhs.emdy.data.EmbyVideo
import com.zzhs.emdy.data.PlaybackMode
import com.zzhs.emdy.ui.theme.EmdyAccent
import com.zzhs.emdy.ui.theme.EmdyDelete
import com.zzhs.emdy.ui.theme.EmdyFavorite
import com.zzhs.emdy.ui.theme.EmdyTagChip
import com.zzhs.emdy.ui.theme.EmdyTagText
import com.zzhs.emdy.ui.theme.EmdyTextMuted
import com.zzhs.emdy.ui.theme.EmdyTextPrimary
import com.zzhs.emdy.ui.theme.EmdyTextSecondary
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * 视频卡片：ExoPlayer 播放、左右拖动进度（实时预览）、长按倍速、
 * 右侧功能按钮、底部信息区（作者/标题/简介/标签）
 */
@Composable
fun VideoCard(state: EmdyState, item: EmbyVideo, active: Boolean) {    val configuration = LocalConfiguration.current
    val screenWidthDp = configuration.screenWidthDp.toFloat()

    var exoPlayer by remember { mutableStateOf<ExoPlayer?>(null) }
    var modeIndex by remember { mutableStateOf(0) }
    var isPlaying by remember { mutableStateOf(false) }
    var hasStarted by remember { mutableStateOf(false) }
    var hasError by remember { mutableStateOf(false) }
    var duration by remember { mutableFloatStateOf(0f) }
    var position by remember { mutableFloatStateOf(0f) }
    var isScrubbing by remember { mutableStateOf(false) }
    var scrubValue by remember { mutableFloatStateOf(0f) }
    var scrubStart by remember { mutableFloatStateOf(0f) }
    var isBoosting by remember { mutableStateOf(false) }
    var showScrubTime by remember { mutableStateOf(false) }

    val context = LocalContext.current

    // 当前播放地址（按模式）
    val currentUrl = item.playbackModes.getOrElse(modeIndex) { PlaybackMode.DIRECT }.let { item.urlOf(it) }

    // 播放器创建与释放
    DisposableEffect(item.id, modeIndex) {
        val player = ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(currentUrl))
            volume = if (state.muted) 0f else 1f
            playWhenReady = active
            prepare()
        }
        exoPlayer = player
        onDispose {
            player.release()
            exoPlayer = null
        }
    }

    // 进度轮询
    LaunchedEffect(exoPlayer, active) {
        val player = exoPlayer ?: return@LaunchedEffect
        while (true) {
            kotlinx.coroutines.delay(200)
            if (!isScrubbing) {
                duration = player.duration.coerceAtLeast(0) / 1000f
                position = player.currentPosition.coerceAtLeast(0) / 1000f
                isPlaying = player.isPlaying
            }
        }
    }

    // 播放结束
    LaunchedEffect(exoPlayer) {
        val player = exoPlayer ?: return@LaunchedEffect
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED && active && !isScrubbing) {
                    state.handlePlaybackEnd()
                }
                if (playbackState == Player.STATE_READY) hasStarted = true
            }

            override fun onPlayerError(error: PlaybackException) {
                hasError = true
            }
        })
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(item.id) {
                detectTapGestures(
                    onTap = {
                        val player = exoPlayer ?: return@detectTapGestures
                        if (player.isPlaying) {
                            player.pause()
                            isPlaying = false
                        } else {
                            player.play()
                            isPlaying = true
                        }
                    },
                    onLongPress = {
                        val player = exoPlayer ?: return@detectTapGestures
                        if (player.isPlaying && state.fastSpeed > 1f) {
                            player.setPlaybackSpeed(state.fastSpeed)
                            isBoosting = true
                        }
                    }
                )
            }
            .pointerInput(item.id) {
                var totalDrag = 0f
                detectHorizontalDragGestures(
                    onDragStart = {
                        if (state.deletePending) return@detectHorizontalDragGestures
                        scrubStart = position
                        scrubValue = position
                        isScrubbing = true
                        showScrubTime = true
                        totalDrag = 0f
                    },
                    onDragEnd = {
                        exoPlayer?.seekTo((scrubValue * 1000).toLong())
                        isScrubbing = false
                        showScrubTime = false
                    },
                    onDragCancel = {
                        isScrubbing = false
                        showScrubTime = false
                    }
                ) { _, dragAmount ->
                    totalDrag += dragAmount
                    if (!isScrubbing) return@detectHorizontalDragGestures
                    // 满屏宽度对应整个视频时长
                    val deltaSeconds = totalDrag / screenWidthDp * duration
                    val maxTarget = if (duration > 1f) duration - 1f else duration
                    val next = (scrubStart + deltaSeconds).coerceIn(0f, maxTarget)
                    scrubValue = next
                }
            }
    ) {
        // 视频画面
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    useController = false
                    resizeMode = androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                }
            },
            update = { view -> view.player = exoPlayer },
            modifier = Modifier.fillMaxSize()
        )

        // 中央暂停/拖动提示
        if (showScrubTime) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color(0x99000000), RoundedCornerShape(16.dp))
                    .padding(horizontal = 18.dp, vertical = 12.dp)
            ) {
                Text(
                    text = "${formatTime(scrubValue)} / ${formatTime(duration)}",
                    fontSize = 15.sp,
                    color = Color.White
                )
            }
        }

        if (isBoosting) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color(0x99000000), RoundedCornerShape(18.dp))
                    .padding(horizontal = 22.dp, vertical = 14.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "${state.fastSpeed}x",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text("倍速播放中", fontSize = 11.sp, color = EmdyTextSecondary)
                }
            }
        }

        if (active && !isPlaying && hasStarted && !hasError && !isScrubbing) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color(0x99000000), CircleShape)
                    .clickable { exoPlayer?.play(); isPlaying = true }
                    .padding(horizontal = 28.dp, vertical = 18.dp)
            ) {
                Text("播放", fontSize = 16.sp, color = Color.White)
            }
        }

        if (hasError) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color(0x99000000), RoundedCornerShape(20.dp))
                    .padding(24.dp)
            ) {
                Text("视频播放失败", fontSize = 18.sp, color = Color.White)
                Text(
                    "当前编码可能不支持直播放，可切换兼容模式播放",
                    fontSize = 13.sp,
                    color = EmdyTextSecondary,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "切换模式",
                        fontSize = 13.sp,
                        color = Color.White,
                        modifier = Modifier
                            .background(EmdyAccent, RoundedCornerShape(18.dp))
                            .clickable {
                                hasError = false
                                modeIndex = (modeIndex + 1) % item.playbackModes.size
                            }
                            .padding(horizontal = 16.dp, vertical = 9.dp)
                    )
                    Text(
                        text = "重试",
                        fontSize = 13.sp,
                        color = Color.White,
                        modifier = Modifier
                            .background(Color(0xFF2B2E39), RoundedCornerShape(18.dp))
                            .clickable {
                                hasError = false
                                exoPlayer?.prepare()
                            }
                            .padding(horizontal = 16.dp, vertical = 9.dp)
                    )
                }
            }
        }

        // 底部信息区 + 进度条
        Column(modifier = Modifier.align(Alignment.BottomStart)) {
            if (state.showControls) {
                ItemCaption(state, item)
            }
            ProgressRow(
                position = if (isScrubbing) scrubValue else position,
                duration = duration,
                visible = showScrubTime || state.showControls
            )
        }

        // 右侧功能按钮
        if (state.showControls) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 16.dp)
            ) {
                SideButton(
                    icon = if (state.isFavoriteVideo(item)) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                    tint = if (state.isFavoriteVideo(item)) EmdyFavorite else Color.White,
                    background = if (state.isFavoriteVideo(item)) Color(0x59FF5E7A) else Color(0x66000000),
                    contentDescription = "收藏"
                ) { state.toggleFavorite(item) }

                SideButton(
                    icon = Icons.Filled.Shuffle,
                    tint = Color.White,
                    background = if (state.shufflePlayback) EmdyAccent else Color(0x66000000),
                    contentDescription = "播放模式"
                ) { state.togglePlayMode() }

                SideButton(
                    icon = Icons.Filled.VolumeOff,
                    tint = Color.White,
                    background = if (state.muted) EmdyAccent else Color(0x66000000),
                    contentDescription = "静音"
                ) {
                    state.muted = !state.muted
                    exoPlayer?.volume = if (state.muted) 0f else 1f
                }

                SideButton(
                    icon = Icons.Filled.Delete,
                    tint = EmdyDelete,
                    background = Color(0x66000000),
                    contentDescription = "删除",
                    enabled = !state.deletePending
                ) { state.confirmDeleteVideo(item) }

                SideButton(
                    icon = Icons.Filled.VisibilityOff,
                    tint = Color.White,
                    background = Color(0x66000000),
                    contentDescription = "隐藏控件"
                ) { state.showControls = false }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ItemCaption(state: EmdyState, item: EmbyVideo) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                androidx.compose.ui.graphics.Brush.verticalGradient(
                    colors = listOf(Color.Transparent, Color(0xCC000000))
                )
            )
            .padding(start = 18.dp, end = 24.dp, top = 56.dp, bottom = 12.dp)
    ) {
        // 作者头像
        Box(
            modifier = Modifier
                .size(46.dp)
                .background(Color(0xFF2A2F3D), CircleShape)
                .clickable { state.openAuthorFeed(item) },
            contentAlignment = Alignment.Center
        ) {
            if (item.authorAvatar.isNotEmpty()) {
                AsyncImage(
                    model = item.authorAvatar,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(46.dp)
                )
            } else {
                Text(
                    text = item.authorInitial(),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = if (item.authorName.isNotEmpty()) "@${item.authorName}" else "未标注作者",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                modifier = Modifier.clickable { state.openAuthorFeed(item) }
            )
            if (item.name.isNotEmpty()) {
                Text(
                    text = item.name,
                    fontSize = 17.sp,
                    color = EmdyTextPrimary,
                    maxLines = 3,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
            if (item.overview.isNotEmpty()) {
                Text(
                    text = item.overview,
                    fontSize = 14.sp,
                    color = EmdyTextSecondary,
                    maxLines = 6,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
            // 标签（Genres + Tags 合并）
            val labels = item.tagLabels()
            if (labels.isNotEmpty()) {
                androidx.compose.foundation.layout.FlowRow(
                    modifier = Modifier.padding(top = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    labels.forEach { (name, kind) ->
                        Text(
                            text = "# $name",
                            fontSize = 12.sp,
                            color = EmdyTagText,
                            modifier = Modifier
                                .background(EmdyTagChip, RoundedCornerShape(12.dp))
                                .clickable { state.openTagFeed(name, kind) }
                                .padding(horizontal = 10.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ProgressRow(position: Float, duration: Float, visible: Boolean) {
    if (!visible || duration <= 0f) return
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
    ) {
        Text(formatTime(position), fontSize = 11.sp, color = Color.White)
        Box(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 8.dp)
                .height(4.dp)
                .background(Color(0x33FFFFFF), RoundedCornerShape(2.dp))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth((position / duration).coerceIn(0f, 1f))
                    .background(EmdyAccent, RoundedCornerShape(2.dp))
            )
        }
        Text(formatTime(duration), fontSize = 11.sp, color = Color.White)
    }
}

@Composable
private fun SideButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    background: Color,
    contentDescription: String,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(48.dp)
            .background(background, CircleShape)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = tint,
            modifier = Modifier.size(26.dp)
        )
    }
}

internal fun formatTime(seconds: Float): String {
    val total = seconds.toInt().coerceAtLeast(0)
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) String.format("%d:%02d:%02d", h, m, s) else String.format("%02d:%02d", m, s)
}
