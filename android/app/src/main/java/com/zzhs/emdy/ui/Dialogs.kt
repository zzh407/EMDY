package com.zzhs.emdy.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zzhs.emdy.data.EmbyLibrary
import com.zzhs.emdy.ui.theme.EmdyAccent
import com.zzhs.emdy.ui.theme.EmdyDelete
import com.zzhs.emdy.ui.theme.EmdySurface
import com.zzhs.emdy.ui.theme.EmdySurfaceDim
import com.zzhs.emdy.ui.theme.EmdyTextMuted
import com.zzhs.emdy.ui.theme.EmdyTextSecondary

/** 删除确认弹窗（单条 / 批量） */
@Composable
fun DeleteConfirmDialog(state: EmdyState) {
    val isBatch = state.deleteConfirmMode == "batch"
    val item = state.deleteConfirmItem
    val name = item?.name ?: ""
    val title = if (name.length > 20) name.substring(0, 20) + "…" else name.ifEmpty { "该视频" }
    val message = if (isBatch) {
        "确定删除选中的 ${state.selectedIds.size} 个视频吗？将从 Emby 服务器永久移除，不可恢复。"
    } else {
        "确定删除《$title》吗？将从 Emby 服务器永久移除，不可恢复。"
    }
    AlertDialog(
        onDismissRequest = { state.dismissDeleteConfirm() },
        containerColor = EmdySurface,
        title = { Text("删除视频", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White) },
        text = { Text(message, fontSize = 13.sp, color = EmdyTextSecondary, textAlign = TextAlign.Center) },
        confirmButton = {
            TextButton(onClick = {
                state.dismissDeleteConfirm()
                if (isBatch) state.batchDeleteSelected() else item?.let { state.deleteCurrentVideo(it) }
            }) {
                Text("删除", color = EmdyDelete, fontSize = 14.sp)
            }
        },
        dismissButton = {
            TextButton(onClick = { state.dismissDeleteConfirm() }) {
                Text("取消", color = EmdyTextMuted, fontSize = 14.sp)
            }
        }
    )
}

/** 设置面板 */
@Composable
fun SettingsSheet(state: EmdyState) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x99000000))
            .clickable { state.optionsVisible = false },
        contentAlignment = Alignment.BottomCenter
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 520.dp)
                .background(EmdySurface, RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                .clickable(enabled = false) { }
                .padding(horizontal = 20.dp, vertical = 22.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "播放设置",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    "关闭",
                    fontSize = 13.sp,
                    color = EmdyTextMuted,
                    modifier = Modifier.clickable { state.optionsVisible = false })
            }

            SettingCheckbox(
                checked = state.shufflePlayback,
                label = "随机播放：打乱当前视频顺序"
            ) { state.togglePlayMode() }

            SettingCheckbox(
                checked = state.hideCollections,
                label = "隐藏合集与文件夹"
            ) { state.toggleHideCollections() }

            SettingCheckbox(
                checked = state.rememberLogin,
                label = "记住服务器、用户名和密码"
            ) { state.setRememberLogin(it) }

            // 倍速档位
            Column(modifier = Modifier.padding(top = 4.dp)) {
                Text("长按屏幕加速倍速", fontSize = 13.sp, color = EmdyTextSecondary)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    listOf(1.25f, 1.5f, 1.75f, 2.0f, 3.0f).forEach { speed ->
                        val selected = state.fastSpeed == speed
                        Text(
                            text = "${speed}x",
                            fontSize = 13.sp,
                            color = if (selected) Color.White else EmdyTextSecondary,
                            modifier = Modifier
                                .background(
                                    if (selected) EmdyAccent else EmdySurfaceDim,
                                    RoundedCornerShape(14.dp)
                                )
                                .clickable { state.setFastSpeed(speed) }
                                .padding(horizontal = 14.dp, vertical = 7.dp)
                        )
                    }
                }
            }

            // 操作按钮
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.padding(top = 10.dp)
            ) {
                SheetButton("扫描媒体库", EmdySurfaceDim) { state.refreshMediaLibrary() }
                SheetButton("更换服务器", EmdySurfaceDim) { state.changeServer() }
                SheetButton("关闭", EmdyAccent) { state.optionsVisible = false }
            }
        }
    }
}

@Composable
private fun SettingCheckbox(checked: Boolean, label: String, onChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp)
    ) {
        Checkbox(checked = checked, onCheckedChange = onChange)
        Text(label, fontSize = 13.sp, color = EmdyTextSecondary)
    }
}

@Composable
private fun SheetButton(text: String, background: Color, onClick: () -> Unit) {
    Text(
        text = text,
        fontSize = 13.sp,
        color = Color.White,
        modifier = Modifier
            .weight(1f)
            .background(background, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        textAlign = TextAlign.Center
    )
}

/** 媒体库选择弹窗 */
@Composable
fun LibraryPickerDialog(state: EmdyState) {
    AlertDialog(
        onDismissRequest = { state.libraryPickerVisible = false },
        containerColor = EmdySurface,
        title = { Text("切换媒体库", fontSize = 17.sp, color = Color.White) },
        text = {
            Column {
                (listOf(EmbyLibrary("", "全部媒体库", "all")) + state.libraries.filter { it.id != "" })
                    .forEach { library ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { state.selectLibrary(library) }
                                .padding(vertical = 14.dp)
                        ) {
                            Text(
                                text = library.name,
                                fontSize = 16.sp,
                                color = if (library.id == state.selectedLibraryId) EmdyAccent else Color.White,
                                modifier = Modifier.weight(1f)
                            )
                            if (library.id == state.selectedLibraryId) {
                                Text("当前", fontSize = 11.sp, color = EmdyAccent)
                            }
                        }
                    }
            }
        },
        confirmButton = {
            TextButton(onClick = { state.libraryPickerVisible = false }) {
                Text("取消", color = EmdyTextMuted)
            }
        }
    )
}
