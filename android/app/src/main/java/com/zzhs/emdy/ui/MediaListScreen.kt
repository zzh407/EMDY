package com.zzhs.emdy.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.zzhs.emdy.ui.theme.EmdyAccent
import com.zzhs.emdy.ui.theme.EmdyBackground
import com.zzhs.emdy.ui.theme.EmdyDelete
import com.zzhs.emdy.ui.theme.EmdyFavorite
import com.zzhs.emdy.ui.theme.EmdyTagText
import com.zzhs.emdy.ui.theme.EmdyTextMuted
import com.zzhs.emdy.ui.theme.EmdyTextSecondary

/** 「全部视频」网格页：竖版 9:16 预览、长按多选、批量删除 */
@Composable
fun MediaListScreen(state: EmdyState) {
    val configuration = LocalConfiguration.current
    val columns = if (configuration.screenWidthDp >= 600) 4 else 2

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(EmdyBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        // 顶部栏
        if (state.multiSelectMode) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text(
                    text = "取消",
                    fontSize = 13.sp,
                    color = EmdyTextMuted,
                    modifier = Modifier
                        .background(Color(0xFF2B2E39), RoundedCornerShape(14.dp))
                        .clickable { state.exitMultiSelect() }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                )
                Text(
                    text = "已选 ${state.selectedIds.size}",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 10.dp)
                )
                Text(
                    text = if (state.selectedIds.size >= state.mediaListItems.size && state.mediaListItems.isNotEmpty())
                        "取消全选" else "全选",
                    fontSize = 13.sp,
                    color = EmdyTagText,
                    modifier = Modifier
                        .background(Color(0xFF1E2A4A), RoundedCornerShape(14.dp))
                        .clickable { state.toggleSelectAll() }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                )
                Spacer(modifier = Modifier.size(10.dp))
                Text(
                    text = if (state.selectedIds.isNotEmpty()) "删除(${state.selectedIds.size})" else "删除",
                    fontSize = 13.sp,
                    color = if (state.selectedIds.isNotEmpty() && !state.batchDeletePending) EmdyDelete else Color(0xFF667080),
                    modifier = Modifier
                        .background(Color(0xFF3A2028), RoundedCornerShape(14.dp))
                        .clickable { state.confirmBatchDelete() }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                )
            }
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text(
                    text = state.selectedLibraryName,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                if (state.mediaListTotal > 0) {
                    Text(
                        text = "共 ${state.mediaListTotal} 个视频",
                        fontSize = 12.sp,
                        color = EmdyTextMuted,
                        modifier = Modifier.padding(end = 14.dp)
                    )
                }
                Text(
                    text = "关闭",
                    fontSize = 13.sp,
                    color = EmdyTextMuted,
                    modifier = Modifier
                        .background(Color(0xFF2B2E39), RoundedCornerShape(14.dp))
                        .clickable { state.mediaListVisible = false }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                )
            }
        }

        // 网格
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
            modifier = Modifier
                .fillMaxSize()
        ) {
            items(state.mediaListItems, key = { it.id }) { item ->
                MediaGridItem(
                    state = state,
                    item = item,
                    onLoadMore = { state.loadMediaListPage() }
                )
            }
        }

        if (state.mediaListItems.isEmpty() && !state.mediaListLoading) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp)
            ) {
                Text("暂无视频", fontSize = 18.sp, color = EmdyTextSecondary)
                Text(
                    "当前媒体库没有可显示的视频条目。",
                    fontSize = 13.sp,
                    color = EmdyTextMuted,
                    textAlign = TextAlign.Center
                )
            }
        }

        if (state.mediaListLoading) {
            Row(
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp)
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = EmdyAccent, strokeWidth = 2.dp)
                Text("正在加载更多…", fontSize = 12.sp, color = EmdyTextMuted, modifier = Modifier.padding(start = 10.dp))
            }
        }

        // 删除确认弹窗
        if (state.deleteConfirmVisible) {
            DeleteConfirmDialog(state)
        }
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun MediaGridItem(state: EmdyState, item: com.zzhs.emdy.data.EmbyVideo, onLoadMore: () -> Unit) {
    val isCurrent = state.videos.getOrNull(state.currentIndex)?.id == item.id
    val selected = item.id in state.selectedIds

    Column(modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(9f / 16f)
                .combinedClickable(
                    onClick = {
                        if (state.multiSelectMode) state.toggleSelect(item) else state.playFromList(item)
                    },
                    onLongClick = { state.enterMultiSelect(item) }
                )
        ) {
            AsyncImage(
                model = item.imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF141720), RoundedCornerShape(8.dp))
            )

            // 时长
            if (item.durationText.isNotEmpty()) {
                Text(
                    text = item.durationText,
                    fontSize = 10.sp,
                    color = Color.White,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(end = 4.dp, bottom = 4.dp)
                        .background(Color(0x99000000), RoundedCornerShape(4.dp))
                        .padding(horizontal = 5.dp, vertical = 2.dp)
                )
            }

            // 收藏
            if (state.isFavoriteVideo(item)) {
                Text(
                    text = "♥",
                    fontSize = 11.sp,
                    color = EmdyFavorite,
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(start = 4.dp, bottom = 4.dp)
                        .background(Color(0x99000000), RoundedCornerShape(4.dp))
                        .padding(horizontal = 5.dp, vertical = 2.dp)
                )
            }

            // 播放中
            if (isCurrent) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(start = 4.dp, top = 4.dp)
                        .background(EmdyAccent, RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 3.dp)
                ) {
                    Text("▶", fontSize = 9.sp, color = Color.White)
                    Text("播放中", fontSize = 10.sp, color = Color.White)
                }
            }

            // 多选选中态
            if (state.multiSelectMode && selected) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color(0x595B74F6))
                )
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(6.dp)
                        .size(24.dp)
                        .background(EmdyAccent, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text("✓", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
        }

        Text(
            text = item.name,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = if (isCurrent) EmdyAccent else Color.White,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 6.dp)
        )

        // 触底加载（仅列表大小变化时重新评估，避免每次重组都触发）
        androidx.compose.runtime.LaunchedEffect(state.mediaListItems.size) {
            if (item.id == state.mediaListItems.lastOrNull()?.id) onLoadMore()
        }
    }
}
