package dev.opencode.mobile

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var backend: com.tailscale.libtailscale.Backend? = null
    private var statusSink: EventChannel.EventSink? = null

    companion object {
        const val METHOD_CHANNEL = "dev.opencode/tailscale"
        const val STATUS_CHANNEL = "dev.opencode/tailscale/status"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val hostname = call.argument<String>("hostname") ?: "opencode-mobile"
                    val authKey  = call.argument<String>("authKey")
                    scope.launch {
                        try {
                            val status = startNode(hostname, authKey)
                            result.success(status)
                        } catch (e: Exception) {
                            result.error("TS_START_FAILED", e.message, null)
                        }
                    }
                }
                "stop" -> {
                    scope.launch {
                        stopNode()
                        result.success(null)
                    }
                }
                "getStatus" -> {
                    scope.launch {
                        result.success(buildStatusMap())
                    }
                }
                "resolvePeer" -> {
                    val hostname = call.argument<String>("hostname") ?: ""
                    scope.launch {
                        result.success(resolvePeer(hostname))
                    }
                }
                "listPeers" -> {
                    scope.launch {
                        result.success(listPeers())
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STATUS_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                statusSink = events
            }
            override fun onCancel(arguments: Any?) {
                statusSink = null
            }
        })
    }

    private suspend fun startNode(
        hostname: String,
        authKey: String?
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        if (backend != null) return@withContext buildStatusMap()

        val dataDir = applicationContext
            .getDir("tailscale", Context.MODE_PRIVATE)
            .absolutePath

        val ts = com.tailscale.libtailscale.Tailscale.newBackend(
            dataDir,
            applicationContext,
            hostname,
        )
        backend = ts

        ts.setStateChangeCallback { state ->
            scope.launch(Dispatchers.Main) {
                statusSink?.success(buildStatusMapFromState(state, ts))
            }
        }

        if (!authKey.isNullOrBlank()) {
            ts.setAuthKey(authKey)
        }

        ts.start()
        buildStatusMap()
    }

    private suspend fun stopNode() = withContext(Dispatchers.IO) {
        backend?.quit()
        backend = null
    }

    private fun buildStatusMap(): Map<String, Any?> {
        val ts = backend ?: return mapOf("state" to "stopped")
        return try {
            val state = ts.state
            val prefs = ts.preferences
            mapOf(
                "state"       to mapTsState(state),
                "hostname"    to prefs?.hostname,
                "tailnetName" to ts.networkName,
                "ipv4"        to ts.ipv4Address,
                "ipv6"        to ts.ipv6Address,
                "loginUrl"    to if (mapTsState(state) == "needsLogin") ts.authUrl else null,
            )
        } catch (e: Exception) {
            mapOf("state" to "error", "error" to e.message)
        }
    }

    private fun buildStatusMapFromState(
        state: String,
        ts: com.tailscale.libtailscale.Backend
    ): Map<String, Any?> = mapOf(
        "state"       to mapTsState(state),
        "hostname"    to try { ts.preferences?.hostname } catch (_: Exception) { null },
        "tailnetName" to try { ts.networkName } catch (_: Exception) { null },
        "ipv4"        to try { ts.ipv4Address } catch (_: Exception) { null },
        "ipv6"        to try { ts.ipv6Address } catch (_: Exception) { null },
        "loginUrl"    to if (state == "NeedsLogin") try { ts.authUrl } catch (_: Exception) { null } else null,
    )

    private fun mapTsState(raw: String): String = when (raw) {
        "Running"    -> "running"
        "Starting"   -> "starting"
        "NeedsLogin" -> "needsLogin"
        "Stopped"    -> "stopped"
        else         -> "stopped"
    }

    private fun resolvePeer(hostname: String): String? {
        val ts = backend ?: return null
        return try {
            ts.peers()
                ?.firstOrNull { it.hostName == hostname || it.dnsName.startsWith(hostname) }
                ?.tailscaleIPs
                ?.firstOrNull { it.contains('.') }
        } catch (_: Exception) { null }
    }

    private fun listPeers(): List<Map<String, Any?>> {
        val ts = backend ?: return emptyList()
        return try {
            ts.peers()?.map { peer ->
                mapOf(
                    "hostname" to peer.hostName,
                    "ipv4"     to peer.tailscaleIPs.firstOrNull { it.contains('.') },
                    "ipv6"     to peer.tailscaleIPs.firstOrNull { it.contains(':') },
                    "os"       to peer.os,
                    "online"   to peer.online,
                )
            } ?: emptyList()
        } catch (_: Exception) { emptyList() }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
