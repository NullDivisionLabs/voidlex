package com.voidlex.voidlex

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetCompactLayoutTest {

    @Test
    fun slashLayout_keepsPhoneBaselineAtTypicalCellSize() {
        val layout = WidgetCompactLayout.slashLayoutForSpan(
            70,
            CompactTriangleOrientation.UPRIGHT,
        )

        assertEquals(24, layout.widthDp)
        assertEquals(17, layout.heightDp)
        assertEquals(5f, layout.translationYDp, 0.01f)
    }

    @Test
    fun slashLayout_scalesUpOnTabletCell() {
        val layout = WidgetCompactLayout.slashLayoutForSpan(
            110,
            CompactTriangleOrientation.UPRIGHT,
        )

        assertEquals(33, layout.widthDp)
        assertEquals(23, layout.heightDp)
        assertEquals(8.03f, layout.translationYDp, 0.01f)
    }

    @Test
    fun slashLayout_invertedTriangleFlipsTranslation() {
        val layout = WidgetCompactLayout.slashLayoutForSpan(
            110,
            CompactTriangleOrientation.INVERTED,
        )

        assertEquals(-8.03f, layout.translationYDp, 0.01f)
    }

    @Test
    fun slashLayout_scalesBeyondPanelReferenceOnVeryLargeCells() {
        val layout = WidgetCompactLayout.slashLayoutForSpan(
            140,
            CompactTriangleOrientation.UPRIGHT,
        )

        assertEquals(43, layout.widthDp)
        assertEquals(30, layout.heightDp)
    }
}
