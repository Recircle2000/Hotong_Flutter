package com.jw.hoseotransport

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createTaxiNotificationChannel()
    }

    // 서버가 보내는 택시팟 알림(channel_id = taxi_party)이 화면 위에 뜨도록 중요도를 높게 둔다.
    private fun createTaxiNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "taxi_party",
            "택시팟 알림",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "택시팟 채팅과 팟 취소·변경 알림"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
