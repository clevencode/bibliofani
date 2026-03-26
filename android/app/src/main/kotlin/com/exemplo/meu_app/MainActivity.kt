package com.exemplo.meu_app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var lifecycleChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "biblefm.android_lifecycle",
        )
    }

    /**
     * Quando a tarefa sai das recentes (ou o utilizador fecha a app com back),
     * [isFinishing] é true — avisamos o Dart para parar o [AudioPlayer] e soltar o serviço em primeiro plano.
     * Em rotação do ecrã, [isFinishing] é false, por isso o áudio não é cortado.
     */
    override fun onDestroy() {
        if (isFinishing) {
            lifecycleChannel?.invokeMethod("uiTaskFinishing", null)
        }
        super.onDestroy()
    }
}
