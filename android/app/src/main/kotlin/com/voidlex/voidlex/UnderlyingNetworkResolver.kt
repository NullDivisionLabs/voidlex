package com.voidlex.voidlex

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build

/// Picks the non-VPN network the tunnel should consume as its underlying
/// transport. Both VoidVpnService (when handing libbox's TUN through
/// `setUnderlyingNetworks`) and LibboxTunRuntime (when satisfying the
/// `localDNSTransport` resolver) need the same answer; centralising the
/// logic here keeps their choices in sync.
internal object UnderlyingNetworkResolver {
    internal enum class TransportClass(val rank: Int) {
        ETHERNET(0),
        WIFI(1),
        CELLULAR(2),
        OTHER(3),
    }

    internal data class Candidate<T>(
        val value: T,
        val transport: TransportClass,
        val isActiveNetwork: Boolean,
        val discoveryIndex: Int,
    )

    internal data class Selection(
        val network: Network,
        val transport: TransportClass,
    )

    fun find(
        connectivityManager: ConnectivityManager,
        excludedNetwork: Network? = null,
    ): Network? = findSelection(connectivityManager, excludedNetwork)?.network

    fun findSelection(
        connectivityManager: ConnectivityManager,
        excludedNetwork: Network? = null,
    ): Selection? {
        val activeNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.activeNetwork
        } else {
            null
        }
        val candidates = sequenceOf(activeNetwork)
            .filterNotNull()
            .plus(connectivityManager.allNetworks.asSequence())
            .distinct()
            .mapIndexedNotNull { index, network ->
                if (network == excludedNetwork) return@mapIndexedNotNull null
                val capabilities = candidateCapabilities(connectivityManager, network)
                    ?: return@mapIndexedNotNull null
                val transport = transportClass(capabilities)
                Candidate(
                    value = Selection(
                        network = network,
                        transport = transport,
                    ),
                    transport = transport,
                    isActiveNetwork = network == activeNetwork,
                    discoveryIndex = index,
                )
            }
            .toList()
        return chooseBestCandidate(candidates)?.value
    }

    fun isCandidate(connectivityManager: ConnectivityManager, network: Network): Boolean {
        return candidateCapabilities(connectivityManager, network) != null
    }

    internal fun <T> chooseBestCandidate(candidates: List<Candidate<T>>): Candidate<T>? {
        return candidates.minWithOrNull(
            compareBy<Candidate<T>> { it.transport.rank }
                .thenBy { if (it.isActiveNetwork) 0 else 1 }
                .thenBy { it.discoveryIndex },
        )
    }

    internal fun transportClass(capabilities: NetworkCapabilities): TransportClass {
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                TransportClass.ETHERNET
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
                TransportClass.WIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                TransportClass.CELLULAR
            else -> TransportClass.OTHER
        }
    }

    private fun candidateCapabilities(
        connectivityManager: ConnectivityManager,
        network: Network,
    ): NetworkCapabilities? {
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return null
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return null
        }
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
            return null
        }
        return capabilities
    }
}
