package com.zzhs.emdy.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zzhs.emdy.ui.theme.EmdyAccent
import com.zzhs.emdy.ui.theme.EmdyBackground
import com.zzhs.emdy.ui.theme.EmdyTextMuted
import com.zzhs.emdy.ui.theme.EmdyTextSecondary
import androidx.compose.ui.platform.LocalConfiguration

/** 竖屏短视频信息流 */
@Composable
fun FeedScreen(state: EmdyState) {
    val configuration = LocalConfiguration.current
    val isWide = configuration.screenWidthDp >= 600

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(EmdyBackground),
        contentAlignment = Alignment.Center
    ) {
        when {
            state.videos.isNotEmpty() -> {
                val pagerState = rememberPagerState(
                    initialPage = state.currentIndex,
                    pageCount = { state.videos.size }
                )
                // Pager 与状态双向同步
                LaunchedEffect(pagerState.currentPage) {
                    if (pagerState.currentPage != state.currentIndex) {
                        state.currentIndex = pagerState.currentPage
                        if (state.hasMore && pagerState.currentPage >= state.videos.size - 3) {
                            state.loadVideos(false)
                        }
                    }
                }
                LaunchedEffect(state.currentIndex) {
                    if (state.currentIndex != pagerState.currentPage &&
                        state.currentIndex < state.videos.size
                    ) {
                        pagerState.scrollToPage(state.currentIndex)
                    }
                }

                Box(
                    modifier = if (isWide) {
                        Modifier
                            .widthIn(max = 460.dp)
                            .fillMaxHeight()
                    } else {
                        Modifier.fillMaxSize()
                    }
                ) {
                    VerticalPager(
                        state = pagerState,
                        modifier = Modifier.fillMaxSize()
                    ) { page ->
                        VideoCard(
                            state = state,
                            item = state.videos[page],
                            active = page == pagerState.currentPage
                        )
                    }
                }
            }

            state.isLoading -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator(color = EmdyAccent)
                    Text("正在读取媒体库…", fontSize = 14.sp, color = EmdyTextSecondary)
                }
            }

            else -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier.padding(32.dp)
                ) {
                    Text("没有找到视频", fontSize = 22.sp, color = EmdyTextSecondary)
                    Text(
                        "当前用户至少有一个媒体库，但没有取到视频条目。",
                        fontSize = 14.sp,
                        color = EmdyTextMuted,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
        }

        // 顶部栏（库切换 / 序号 / 全部媒体 / 设置）
        if (state.showControls) {
            FeedTopBar(state)
        } else {
            // 沉浸模式：右下角眼睛图标恢复控件
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 16.dp, bottom = 40.dp)
                    .size(48.dp)
                    .background(
                        androidx.compose.ui.graphics.Color(0x66000000),
                        androidx.compose.foundation.shape.CircleShape
                    )
                    .clickableNoRipple { state.showControls = true },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Visibility,
                    contentDescription = "恢复控件",
                    tint = androidx.compose.ui.graphics.Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }
        }

        // 删除确认弹窗
        if (state.deleteConfirmVisible) {
            DeleteConfirmDialog(state)
        }

        // 设置面板
        if (state.optionsVisible) {
            SettingsSheet(state)
        }

        // 媒体库选择
        if (state.libraryPickerVisible) {
            LibraryPickerDialog(state)
        }

        // 中央提示
        HintOverlay(state)
    }
}

@Composable
private fun FeedTopBar(state: EmdyState) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        Text(
            text = state.libraryButtonLabel(),
            fontSize = 12.sp,
            color = androidx.compose.ui.graphics.Color.White,
            modifier = Modifier
                .background(androidx.compose.ui.graphics.Color(0x66000000), shape = androidx.compose.foundation.shape.RoundedCornerShape(17.dp))
                .clickableNoRipple { state.openLibraryPicker() }
                .padding(horizontal = 12.dp, vertical = 7.dp))
        Spacer(modifier = Modifier.weight(1f))
        if (state.videos.isNotEmpty()) {
            Text(
                text = state.feedCounter(),
                fontSize = 12.sp,
                color = androidx.compose.ui.graphics.Color(0xD9FFFFFF),
                modifier = Modifier.padding(end = 8.dp)
            )
        }
        if (state.isFiltered()) {
            TopBarButton("全部视频", EmdyAccent) { state.clearFilter() }
        } else {
            TopBarButton("全部媒体", androidx.compose.ui.graphics.Color(0x66000000)) { state.openMediaList() }
        }
        Spacer(modifier = Modifier.width(8.dp))
        TopBarButton("设置", androidx.compose.ui.graphics.Color(0x66000000)) { state.optionsVisible = true }
    }
}

@Composable
private fun TopBarButton(text: String, background: androidx.compose.ui.graphics.Color, onClick: () -> Unit) {
    Text(
        text = text,
        fontSize = 12.sp,
        color = androidx.compose.ui.graphics.Color.White,
        modifier = Modifier
            .background(background, shape = androidx.compose.foundation.shape.RoundedCornerShape(17.dp))
            .clickableNoRipple(onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp)
    )
}

@Composable
private fun HintOverlay(state: EmdyState) {
    if (state.hintText.isNotEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                text = state.hintText,
                fontSize = 13.sp,
                color = androidx.compose.ui.graphics.Color.White,
                modifier = Modifier
                    .background(
                        androidx.compose.ui.graphics.Color(0x99000000),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp)
                    )
                    .padding(horizontal = 18.dp, vertical = 10.dp)
            )
        }
    }
}
