package com.zzhs.emdy.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext

/** 顶层导航：登录页 / 信息流 / 全部视频网格 */
@Composable
fun EmdyNavHost() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val state = remember { EmdyState(context, scope) }

    // 首次进入时初始化（加载会话与设置）
    remember(state) { state.init() }

    when {
        state.session == null -> LoginScreen(state)
        state.mediaListVisible -> MediaListScreen(state)
        else -> FeedScreen(state)
    }
}
