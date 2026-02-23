package com.petspace.app

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 한글 입력을 위한 소프트 키보드 설정
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        // 카카오 키 해시 출력 (개발용)
        printKeyHash()
    }

    @Suppress("DEPRECATION", "PackageManagerGetSignatures")
    private fun printKeyHash() {
        try {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            info.signatures?.forEach { signature ->
                val md = MessageDigest.getInstance("SHA")
                md.update(signature.toByteArray())
                val keyHash = Base64.encodeToString(md.digest(), Base64.NO_WRAP)
                Log.d("KeyHash", "====================================")
                Log.d("KeyHash", "📱 Package Name: $packageName")
                Log.d("KeyHash", "🔑 Key Hash: $keyHash")
                Log.d("KeyHash", "====================================")
                Log.d("KeyHash", "⚠️ 카카오 개발자 콘솔에 위 키 해시를 등록하세요!")
                Log.d("KeyHash", "====================================")
            }
        } catch (e: Exception) {
            Log.e("KeyHash", "Error getting key hash", e)
        }
    }
}
