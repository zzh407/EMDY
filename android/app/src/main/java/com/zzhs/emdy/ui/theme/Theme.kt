package com.zzhs.emdy.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val EmdyBackground = Color(0xFF090A0F)
val EmdyAccent = Color(0xFF5B74F6)
val EmdyAccentSoft = Color(0xFF7C9CFF)
val EmdySurface = Color(0xFF1E2333)
val EmdySurfaceDim = Color(0xFF2B2E39)
val EmdyTextPrimary = Color(0xFFF2F5FF)
val EmdyTextSecondary = Color(0xFFB8BDCA)
val EmdyTextMuted = Color(0xFF9DA3B2)
val EmdyFavorite = Color(0xFFFF5E7A)
val EmdyDelete = Color(0xFFFF3B30)
val EmdyTagChip = Color(0xFF1E2A4A)
val EmdyTagText = Color(0xFF9EC1FF)

private val EmdyColorScheme = darkColorScheme(
    primary = EmdyAccent,
    onPrimary = Color.White,
    secondary = EmdyAccentSoft,
    background = EmdyBackground,
    onBackground = EmdyTextPrimary,
    surface = EmdySurface,
    onSurface = EmdyTextPrimary,
    surfaceVariant = EmdySurfaceDim,
    onSurfaceVariant = EmdyTextSecondary,
    error = EmdyDelete
)

@Composable
fun EmdyTheme(content: @Composable () -> Unit) {
    // 应用始终为深色沉浸式主题
    MaterialTheme(colorScheme = EmdyColorScheme, content = content)
}
