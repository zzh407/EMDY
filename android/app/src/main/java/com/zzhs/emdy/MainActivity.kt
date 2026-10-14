package com.zzhs.emdy

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.zzhs.emdy.ui.EmdyNavHost
import com.zzhs.emdy.ui.theme.EmdyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            EmdyTheme {
                EmdyNavHost()
            }
        }
    }
}
