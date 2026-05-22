package com.voidtunnel.voidtunnel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UnderlyingNetworkResolverTest {
    @Test
    fun `prefers ethernet over wifi and cellular`() {
        val best = UnderlyingNetworkResolver.chooseBestCandidate(
            listOf(
                candidate("cell", UnderlyingNetworkResolver.TransportClass.CELLULAR),
                candidate("wifi", UnderlyingNetworkResolver.TransportClass.WIFI),
                candidate("ethernet", UnderlyingNetworkResolver.TransportClass.ETHERNET),
            ),
        )

        assertEquals("ethernet", best?.value)
    }

    @Test
    fun `uses active network as tie breaker within same transport`() {
        val best = UnderlyingNetworkResolver.chooseBestCandidate(
            listOf(
                candidate(
                    "wifi-1",
                    UnderlyingNetworkResolver.TransportClass.WIFI,
                    isActiveNetwork = false,
                    discoveryIndex = 0,
                ),
                candidate(
                    "wifi-2",
                    UnderlyingNetworkResolver.TransportClass.WIFI,
                    isActiveNetwork = true,
                    discoveryIndex = 1,
                ),
            ),
        )

        assertEquals("wifi-2", best?.value)
    }

    @Test
    fun `keeps discovery order when rank and active flag match`() {
        val best = UnderlyingNetworkResolver.chooseBestCandidate(
            listOf(
                candidate(
                    "wifi-1",
                    UnderlyingNetworkResolver.TransportClass.WIFI,
                    discoveryIndex = 0,
                ),
                candidate(
                    "wifi-2",
                    UnderlyingNetworkResolver.TransportClass.WIFI,
                    discoveryIndex = 1,
                ),
            ),
        )

        assertEquals("wifi-1", best?.value)
    }

    @Test
    fun `returns null for no candidates`() {
        assertNull(UnderlyingNetworkResolver.chooseBestCandidate<String>(emptyList()))
    }

    private fun candidate(
        value: String,
        transport: UnderlyingNetworkResolver.TransportClass,
        isActiveNetwork: Boolean = false,
        discoveryIndex: Int = 0,
    ) = UnderlyingNetworkResolver.Candidate(
        value = value,
        transport = transport,
        isActiveNetwork = isActiveNetwork,
        discoveryIndex = discoveryIndex,
    )
}
