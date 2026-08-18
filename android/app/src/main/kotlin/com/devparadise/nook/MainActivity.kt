package com.devparadise.nook

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.NetworkInfo
import android.net.wifi.WifiManager
import android.net.wifi.WpsInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceInfo
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceRequest
import android.os.Build
import android.os.Looper
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val WINDOW_CHANNEL = "com.nook/window_manager"
    private val PERMISSIONS_CHANNEL = "com.nook/nearby_permissions"
    private val MULTICAST_CHANNEL = "com.nook/multicast_lock"
    private val WIFI_DIRECT_CHANNEL = "com.nook/wifi_direct"
    private val WIFI_DIRECT_EVENTS = "com.nook/wifi_direct/events"
    private val REQUEST_CODE_NEARBY = 1001

    private companion object {
        const val WIFI_DIRECT_SERVICE_TYPE = "_syncnotenet._tcp."
    }

    private var pendingPermissionsResult: MethodChannel.Result? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wifiDirect: WifiDirectManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Window flags channel (screenshot blocker)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WINDOW_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "addFlags" -> {
                    val flags = call.argument<Int>("flags") ?: 0
                    window.addFlags(flags)
                    result.success(null)
                }
                "clearFlags" -> {
                    val flags = call.argument<Int>("flags") ?: 0
                    window.clearFlags(flags)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Multicast lock channel — mDNS discovery requires receiving multicast
        // frames, which Android Wi-Fi drops unless a MulticastLock is held.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MULTICAST_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    if (multicastLock?.isHeld != true) {
                        val wifiManager =
                            applicationContext.getSystemService(WIFI_SERVICE) as? WifiManager
                        val lock = wifiManager?.createMulticastLock("nook-mdns")
                        lock?.setReferenceCounted(false)
                        lock?.acquire()
                        multicastLock = lock
                    }
                    result.success(null)
                }
                "release" -> {
                    multicastLock?.let {
                        if (it.isHeld) it.release()
                    }
                    multicastLock = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Nearby permissions channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNearbyPermissions" -> {
                    result.success(hasNearbyPermissions())
                }
                "requestNearbyPermissions" -> {
                    if (hasNearbyPermissions()) {
                        result.success(true)
                    } else {
                        pendingPermissionsResult = result
                        requestNearbyPermissions()
                    }
                }
                "isWifiEnabled" -> {
                    val wifiManager =
                        applicationContext.getSystemService(WIFI_SERVICE) as? WifiManager
                    result.success(wifiManager?.isWifiEnabled == true)
                }
                else -> result.notImplemented()
            }
        }

        // Wi-Fi Direct channel — Quick Share-style cross-network sync. The
        // receiver hosts a P2P group and registers Nook's DNS-SD service
        // (_syncnotenet._tcp) carrying its multiaddr; the sender discovers it,
        // joins the group, and the existing UDX/libp2p transport dials across
        // the P2P link — no deprecated Nearby Connections API.
        val wifiDirectManager = WifiDirectManager()
        wifiDirect = wifiDirectManager
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_DIRECT_EVENTS,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                wifiDirectManager.eventsSink = events
            }

            override fun onCancel(arguments: Any?) {
                wifiDirectManager.eventsSink = null
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_DIRECT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "createGroup" -> {
                    wifiDirectManager.createGroup { map -> result.success(map) }
                }
                "registerService" -> {
                    val name = call.argument<String>("name") ?: ""
                    val txt = call.argument<Map<String, String>>("txt") ?: emptyMap()
                    wifiDirectManager.registerService(name, txt) { ok ->
                        result.success(ok)
                    }
                }
                "removeGroup" -> {
                    wifiDirectManager.removeGroup()
                    result.success(null)
                }
                "discoverServices" -> {
                    wifiDirectManager.discoverServices()
                    result.success(null)
                }
                "stopDiscovery" -> {
                    wifiDirectManager.stopDiscovery()
                    result.success(null)
                }
                "connect" -> {
                    val address = call.argument<String>("address") ?: ""
                    wifiDirectManager.connect(address)
                    result.success(null)
                }
                "cancelConnect" -> {
                    wifiDirectManager.cancelConnect()
                    result.success(null)
                }
                "getOwnerAddress" -> {
                    wifiDirectManager.getOwnerAddress { addr -> result.success(addr) }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        wifiDirect?.deinit()
        wifiDirect = null
        super.onDestroy()
    }

    private fun hasNearbyPermissions(): Boolean {
        val permissions = getNearbyPermissions()
        return permissions.all { perm ->
            ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun getNearbyPermissions(): List<String> {
        val permissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33)
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Android 12 and below
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                permissions.add(Manifest.permission.BLUETOOTH_SCAN)
                permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }

        return permissions
    }

    private fun requestNearbyPermissions() {
        val permissions = getNearbyPermissions()
        val missing = permissions.filter { perm ->
            ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isEmpty()) {
            pendingPermissionsResult?.success(true)
            pendingPermissionsResult = null
            return
        }

        ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQUEST_CODE_NEARBY)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQUEST_CODE_NEARBY) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionsResult?.success(allGranted)
            pendingPermissionsResult = null
        }
    }

    /// Wraps WifiP2pManager (group owner, DNS-SD service registration and
    /// discovery, connect) and pushes state to the Dart side over an
    /// EventChannel.
    inner class WifiDirectManager {
        var eventsSink: EventChannel.EventSink? = null

        private var manager: WifiP2pManager? = null
        private var channel: WifiP2pManager.Channel? = null
        private var receiver: BroadcastReceiver? = null
        private var initialized = false

        fun ensureInit() {
            if (initialized) return
            initialized = true
            manager = applicationContext.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
            channel = manager?.initialize(
                applicationContext,
                Looper.getMainLooper(),
                object : WifiP2pManager.ChannelListener {
                    override fun onChannelDisconnected() {
                        emit("error", mapOf("message" to "Wi-Fi Direct channel disconnected"))
                        initialized = false
                    }
                },
            )
            manager?.setDnsSdResponseListeners(
                channel,
                object : WifiP2pManager.DnsSdServiceResponseListener {
                    override fun onDnsSdServiceAvailable(
                        instanceName: String?,
                        registrationType: String?,
                        srcDevice: WifiP2pDevice?,
                    ) {
                        // TXT records arrive via DnsSdTxtRecordListener.
                    }
                },
                DnsSdTxtRecordListenerProxy(),
            )
            registerReceiver()
        }

        private fun registerReceiver() {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            }
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    when (intent.action) {
                        WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                            val networkInfo: NetworkInfo? =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    intent.getParcelableExtra(
                                        WifiP2pManager.EXTRA_NETWORK_INFO,
                                        NetworkInfo::class.java,
                                    )
                                } else {
                                    @Suppress("DEPRECATION")
                                    intent.getParcelableExtra(WifiP2pManager.EXTRA_NETWORK_INFO)
                                }
                            val p2pInfo: WifiP2pInfo? =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    intent.getParcelableExtra(
                                        WifiP2pManager.EXTRA_WIFI_P2P_INFO,
                                        WifiP2pInfo::class.java,
                                    )
                                } else {
                                    @Suppress("DEPRECATION")
                                    intent.getParcelableExtra(WifiP2pManager.EXTRA_WIFI_P2P_INFO)
                                }
                            if (networkInfo?.isConnected == true && p2pInfo != null) {
                                emit(
                                    "connection",
                                    mapOf(
                                        "groupFormed" to p2pInfo.groupFormed,
                                        "isGroupOwner" to p2pInfo.isGroupOwner,
                                        "groupOwnerAddress" to
                                            (p2pInfo.groupOwnerAddress?.hostAddress ?: ""),
                                    ),
                                )
                            }
                        }
                        WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                            val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                            if (state != WifiP2pManager.WIFI_P2P_STATE_ENABLED) {
                                emit(
                                    "error",
                                    mapOf("message" to "Wi-Fi Direct is not available (Wi-Fi off?)"),
                                )
                            }
                        }
                    }
                }
            }
            runCatching { registerReceiver(receiver, filter) }
        }

        fun createGroup(onResult: (Map<String, Any>?) -> Unit) {
            if (!hasNearbyPermissions()) {
                emit("error", mapOf("message" to "Nearby permissions not granted"))
                onResult(null)
                return
            }
            ensureInit()
            val m = manager ?: return onResult(null)
            val ch = channel ?: return onResult(null)
            val listener = object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    requestGroupAndOwner(onResult)
                }

                override fun onFailure(reason: Int) {
                    emit("error", mapOf("message" to "createGroup failed: $reason"))
                    onResult(null)
                }
            }
            // Drop any stale group before creating a fresh one.
            m.removeGroup(
                ch,
                object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {
                        m.createGroup(ch, listener)
                    }

                    override fun onFailure(reason: Int) {
                        m.createGroup(ch, listener)
                    }
                },
            )
        }

        private fun requestGroupAndOwner(onResult: (Map<String, Any>?) -> Unit) {
            val m = manager ?: return onResult(null)
            val ch = channel ?: return onResult(null)
            m.requestGroupInfo(ch) { group ->
                val name = group?.networkName ?: ""
                val pass = group?.passphrase ?: ""
                m.requestConnectionInfo(ch) { info ->
                    val owner = info?.groupOwnerAddress?.hostAddress ?: ""
                    emit(
                        "group",
                        mapOf(
                            "networkName" to name,
                            "passphrase" to pass,
                            "ownerAddress" to owner,
                        ),
                    )
                    onResult(
                        mapOf(
                            "networkName" to name,
                            "passphrase" to pass,
                            "ownerAddress" to owner,
                        ),
                    )
                }
            }
        }

        fun registerService(name: String, txt: Map<String, String>, onResult: (Boolean) -> Unit) {
            ensureInit()
            val m = manager ?: return onResult(false)
            val ch = channel ?: return onResult(false)
            val serviceInfo = WifiP2pDnsSdServiceInfo.newInstance(
                name,
                WIFI_DIRECT_SERVICE_TYPE,
                txt,
            )
            val listener = object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    onResult(true)
                }

                override fun onFailure(reason: Int) {
                    emit("error", mapOf("message" to "registerService failed: $reason"))
                    onResult(false)
                }
            }
            // Remove then re-add so re-registration (e.g. owner address
            // resolution) is idempotent.
            m.removeLocalService(
                ch,
                serviceInfo,
                object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {
                        m.addLocalService(ch, serviceInfo, listener)
                    }

                    override fun onFailure(reason: Int) {
                        m.addLocalService(ch, serviceInfo, listener)
                    }
                },
            )
        }

        fun removeGroup() {
            if (!initialized) return
            manager?.removeGroup(
                channel,
                object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {}

                    override fun onFailure(reason: Int) {}
                },
            )
        }

        fun discoverServices() {
            if (!hasNearbyPermissions()) {
                emit("error", mapOf("message" to "Nearby permissions not granted"))
                return
            }
            ensureInit()
            val m = manager ?: return
            val ch = channel ?: return
            m.clearServiceRequests(
                ch,
                object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {
                        val request = WifiP2pDnsSdServiceRequest.newInstance(WIFI_DIRECT_SERVICE_TYPE)
                        m.addServiceRequest(
                            ch,
                            request,
                            object : WifiP2pManager.ActionListener {
                                override fun onSuccess() {
                                    m.discoverServices(
                                        ch,
                                        object : WifiP2pManager.ActionListener {
                                            override fun onSuccess() {}

                                            override fun onFailure(reason: Int) {
                                                emit(
                                                    "error",
                                                    mapOf("message" to "discoverServices failed: $reason"),
                                                )
                                            }
                                        },
                                    )
                                }

                                override fun onFailure(reason: Int) {
                                    emit(
                                        "error",
                                        mapOf("message" to "addServiceRequest failed: $reason"),
                                    )
                                }
                            },
                        )
                    }

                    override fun onFailure(reason: Int) {}
                },
            )
        }

        fun stopDiscovery() {
            if (!initialized) return
            manager?.stopPeerDiscovery(channel, null)
        }

        fun connect(address: String) {
            if (!hasNearbyPermissions()) {
                emit("error", mapOf("message" to "Nearby permissions not granted"))
                return
            }
            ensureInit()
            val m = manager ?: return
            val ch = channel ?: return
            val config = WifiP2pConfig()
            config.deviceAddress = address
            config.wps.setup = WpsInfo.PBC
            m.connect(
                ch,
                config,
                object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {}

                    override fun onFailure(reason: Int) {
                        emit("error", mapOf("message" to "connect failed: $reason"))
                    }
                },
            )
        }

        fun cancelConnect() {
            if (!initialized) return
            manager?.cancelConnect(channel, null)
        }

        fun getOwnerAddress(onResult: (String) -> Unit) {
            ensureInit()
            val m = manager ?: return onResult("")
            val ch = channel ?: return onResult("")
            m.requestConnectionInfo(ch) { info ->
                onResult(info?.groupOwnerAddress?.hostAddress ?: "")
            }
        }

        fun deinit() {
            receiver?.let {
                runCatching { unregisterReceiver(it) }
            }
            receiver = null
            channel?.close()
            channel = null
            manager = null
            initialized = false
        }

        internal fun emit(event: String, data: Map<String, Any>) {
            val map = HashMap<String, Any>()
            map["event"] = event
            map.putAll(data)
            eventsSink?.success(map)
        }
    }

    /// Receives Wi-Fi Direct DNS-SD TXT records and forwards the discovered
    /// Nook service (with its dialable multiaddr) to the Dart side. Kept as a
    /// separate object so it implements the interface exactly as compiled by
    /// the Android SDK.
    inner class DnsSdTxtRecordListenerProxy : WifiP2pManager.DnsSdTxtRecordListener {
        override fun onDnsSdTxtRecordAvailable(
            fullDomainName: String?,
            txtRecord: MutableMap<String, String>?,
            srcDevice: WifiP2pDevice?,
        ) {
            wifiDirect?.emit(
                "service",
                mapOf(
                    "instanceName" to (fullDomainName?.substringBefore(".") ?: ""),
                    "deviceAddress" to (srcDevice?.deviceAddress ?: ""),
                    "txt" to (txtRecord ?: emptyMap<String, String>()),
                ),
            )
        }
    }
}