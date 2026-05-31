package dev.opencode.mobile

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.openziti.Ziti
import org.openziti.ZitiConnection
import org.openziti.ZitiContext
import java.io.*
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.security.KeyStore

class MainActivity : FlutterActivity() {
    private val zitiChannel = "dev.opencode/ziti"
    private val tailscaleChannel = "dev.opencode/tailscale"
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val tailscalePackage = "com.tailscale.ipn"
    private val tailscaleReceiverClass = "$tailscalePackage.IPNReceiver"

    private var identityFile: File? = null
    private var zitiContext: ZitiContext? = null
    private var proxy: ZitiTcpProxy? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            zitiChannel
        ).setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    when (call.method) {
                        "enroll" -> {
                            val jwtUrl = call.argument<String>("jwtUrl") ?: ""
                            enroll(jwtUrl)
                            result.success(buildStatusMap())
                        }
                        "connect" -> {
                            connect()
                            result.success(buildStatusMap())
                        }
                        "getStatus" -> {
                            result.success(buildStatusMap())
                        }
                        "disconnect" -> {
                            disconnect()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(buildErrorMap(e.message ?: "Unknown error"))
                }
            }
        }

        setupTailscaleChannel(flutterEngine)
    }

    private fun setupTailscaleChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tailscaleChannel
        ).setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    when (call.method) {
                        "isInstalled" -> {
                            result.success(isTailscaleInstalled())
                        }
                        "connect" -> {
                            connectTailscale()
                            result.success(buildTailscaleStatusMap())
                        }
                        "disconnect" -> {
                            disconnectTailscale()
                            result.success(buildTailscaleStatusMap())
                        }
                        "getStatus" -> {
                            result.success(buildTailscaleStatusMap())
                        }
                        "getTailscaleIP" -> {
                            result.success(getTailscaleIP())
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(mapOf(
                        "connected" to false,
                        "error" to (e.message ?: "Unknown error")
                    ))
                }
            }
        }
    }

    private suspend fun enroll(jwtUrl: String) = withContext(Dispatchers.IO) {
        val jwtFile = File(cacheDir, "enroll.jwt")
        try {
            URL(jwtUrl).openStream().use { input ->
                FileOutputStream(jwtFile).use { output ->
                    input.copyTo(output)
                }
            }

            val identityPwd = "opencode".toCharArray()
            val ks = KeyStore.getInstance("PKCS12").apply { load(null, null) }
            val jwtBytes = jwtFile.readBytes()
            Ziti.enroll(ks, jwtBytes, "opencode")

            identityFile = File(filesDir, "ziti-identity.p12")
            ks.store(identityFile!!.outputStream(), identityPwd)
        } finally {
            jwtFile.delete()
        }
    }

    private suspend fun connect() = withContext(Dispatchers.IO) {
        val idFile = identityFile
            ?: throw Exception("Not enrolled. Enroll first.")

        val ctx = Ziti.newContext(idFile, "opencode".toCharArray())
        zitiContext = ctx

        val p = ZitiTcpProxy(ctx, "opencode-svc", 4095)
        p.start(scope)
        proxy = p
    }

    private fun disconnect() {
        proxy?.stop()
        proxy = null
        zitiContext?.destroy()
        zitiContext = null
    }

    private fun buildStatusMap(): Map<String, Any?> = mapOf(
        "enrolled"  to (identityFile?.exists() == true),
        "connected" to (proxy?.isActive == true),
    )

    private fun buildErrorMap(msg: String): Map<String, Any?> = mapOf(
        "enrolled"  to (identityFile?.exists() == true),
        "connected" to false,
        "error"     to msg,
    )

    private fun isTailscaleInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(tailscalePackage, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun connectTailscale() {
        val intent = Intent("com.tailscale.ipn.CONNECT_VPN").apply {
            component = ComponentName(tailscalePackage, tailscaleReceiverClass)
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }
        sendBroadcast(intent)
    }

    private fun disconnectTailscale() {
        val intent = Intent("com.tailscale.ipn.DISCONNECT_VPN").apply {
            component = ComponentName(tailscalePackage, tailscaleReceiverClass)
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }
        sendBroadcast(intent)
    }

    private fun buildTailscaleStatusMap(): Map<String, Any?> {
        val ip = getTailscaleIP()
        return mapOf(
            "connected" to (ip != null),
            "tailscaleIP" to ip,
        )
    }

    private fun getTailscaleIP(): String? {
        return try {
            NetworkInterface.getNetworkInterfaces()?.asSequence()
                ?.flatMap { it.inetAddresses.asSequence() }
                ?.filterIsInstance<Inet4Address>()
                ?.firstOrNull { addr ->
                    val bytes = addr.address
                    bytes[0] == 100.toByte() && (bytes[1].toInt() and 0xC0) == 0x40
                }
                ?.hostAddress
        } catch (_: Exception) {
            null
        }
    }

    override fun onDestroy() {
        disconnect()
        scope.cancel()
        super.onDestroy()
    }
}

private class ZitiTcpProxy(
    private val ctx: ZitiContext,
    private val serviceName: String,
    private val port: Int,
) {
    @Volatile
    var isActive: Boolean = false

    private var serverSocket: ServerSocket? = null
    private var job: Job? = null

    fun start(scope: CoroutineScope) {
        isActive = true
        job = scope.launch(Dispatchers.IO) {
            val ss = ServerSocket(port)
            serverSocket = ss
            try {
                while (isActive) {
                    val client = ss.accept()
                    scope.launch {
                        try {
                            relay(client)
                        } catch (_: Exception) {
                            client.close()
                        }
                    }
                }
            } catch (e: IOException) {
                if (isActive) throw e
            } finally {
                ss.close()
            }
        }
        job?.invokeOnCompletion { isActive = false }
    }

    private suspend fun relay(client: Socket) = withContext(Dispatchers.IO) {
        val zitiConn: ZitiConnection = ctx.dial(serviceName)
        try {
            val clientIn = client.getInputStream()
            val clientOut = client.getOutputStream()

            val fwd = launch {
                try {
                    val bytes = ByteArray(8192)
                    while (true) {
                        val n = clientIn.read(bytes)
                        if (n == -1) break
                        zitiConn.write(bytes.copyOf(n))
                    }
                } finally {
                    zitiConn.close()
                }
            }
            val bwd = launch {
                try {
                    val bytes = ByteArray(8192)
                    while (true) {
                        val n = zitiConn.read(bytes, 0, bytes.size)
                        if (n == -1) break
                        clientOut.write(bytes, 0, n)
                    }
                } finally {
                    client.close()
                }
            }
            fwd.join()
            bwd.join()
        } finally {
            try { zitiConn.close() } catch (_: Exception) {}
            try { client.close() } catch (_: Exception) {}
        }
    }

    fun stop() {
        isActive = false
        job?.cancel()
        serverSocket?.close()
    }
}
