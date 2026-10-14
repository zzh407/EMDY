package com.zzhs.emdy.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zzhs.emdy.ui.theme.EmdyAccent
import com.zzhs.emdy.ui.theme.EmdyAccentSoft
import com.zzhs.emdy.ui.theme.EmdyBackground
import com.zzhs.emdy.ui.theme.EmdySurfaceDim
import com.zzhs.emdy.ui.theme.EmdyTextMuted
import com.zzhs.emdy.ui.theme.EmdyTextSecondary

/** 登录页：服务器地址 / 用户名 / 密码 / 记住登录 */
@Composable
fun LoginScreen(state: EmdyState) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(EmdyBackground),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 520.dp)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp, vertical = 48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "EMDY",
                fontSize = 44.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                color = EmdyAccentSoft
            )
            Text(
                text = "你的 Emby 短视频流",
                fontSize = 18.sp,
                color = EmdyTextSecondary,
                modifier = Modifier.padding(bottom = 20.dp)
            )

            OutlinedTextField(
                value = state.serverUrl,
                onValueChange = { state.serverUrl = it },
                label = { Text("服务器地址") },
                placeholder = { Text("http://192.168.1.10:8096") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Uri,
                    imeAction = ImeAction.Next
                ),
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = state.userName,
                onValueChange = { state.userName = it },
                label = { Text("用户名") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = state.password,
                onValueChange = { state.password = it },
                label = { Text("密码") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done
                ),
                modifier = Modifier.fillMaxWidth()
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Checkbox(
                    checked = state.rememberLogin,
                    onCheckedChange = { state.setRememberLogin(it) }
                )
                Text(
                    text = "记住服务器、用户名和密码",
                    fontSize = 13.sp,
                    color = EmdyTextSecondary
                )
            }

            if (state.loginError.isNotEmpty()) {
                Text(
                    text = state.loginError,
                    fontSize = 13.sp,
                    color = com.zzhs.emdy.ui.theme.EmdyDelete,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Button(
                onClick = { state.login() },
                enabled = !state.isConnecting,
                colors = ButtonDefaults.buttonColors(containerColor = EmdyAccent),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            ) {
                if (state.isConnecting) {
                    CircularProgressIndicator(
                        modifier = Modifier.height(20.dp),
                        color = androidx.compose.ui.graphics.Color.White,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text("登录", fontSize = 16.sp)
                }
            }

            Text(
                text = "登录令牌会保存在本机，建议优先使用 HTTPS。",
                fontSize = 12.sp,
                color = EmdyTextMuted,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 18.dp)
            )
        }
    }
}
