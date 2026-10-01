package com.voidlex.voidlex

import org.json.JSONArray
import org.json.JSONObject

internal object UrlProbeConfigBuilder {
    fun build(server: ServerConfig, port: Int): String {
        require(port in 1..65535)
        val isolated = server.copy(
            isGlobalProxy = true,
            appRoutingMode = AppRoutingMode.OFF,
            appRoutingPackages = emptyList(),
            userRoutingRulesJson = "[]",
            detourServer = null,
            hotspotBindEnabled = false,
            httpProxyAuthEnabled = false,
            verboseXrayLogs = false,
        )
        if (XrayConfigBuilder.usesDirectLibbox(isolated)) {
            return TunToSocksConfigBuilder.buildProbe(isolated, port)
        }
        return XrayConfigBuilder.buildWithInbounds(
            config = isolated,
            includeRuntimeInbounds = false,
            inbounds = JSONArray().put(JSONObject().apply {
                put("tag", "url-probe")
                put("listen", "127.0.0.1")
                put("port", port)
                put("protocol", "http")
                put("settings", JSONObject())
            }),
        )
    }
}
