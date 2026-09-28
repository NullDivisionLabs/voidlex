package com.voidlex.voidlex

import android.os.Bundle
import kotlin.math.roundToInt

/**
 * Proportional layout for the centre "//" glyph on 1×1 home-screen widgets.
 *
 * Sizes mirror [widget_void_panel]'s hub area (108×99 dp triangle, 34×24 dp
 * slash) so the compact glyph scales with the triangle on large tablet cells.
 */
data class CompactSlashLayout(
    val widthDp: Int,
    val heightDp: Int,
    val translationYDp: Float,
)

enum class CompactTriangleOrientation {
    UPRIGHT,
    INVERTED,
}

object WidgetCompactLayout {
    // Hub reference from widget_void_panel.xml.
    private const val REF_HUB_WIDTH_DP = 108
    private const val REF_SLASH_WIDTH_DP = 34
    private const val REF_SLASH_HEIGHT_DP = 24
    private const val REF_TRANSLATION_Y_DP = 5f
    private const val WIDGET_ROOT_PADDING_DP = 4 // 2dp padding on each side

    // Baseline from widget_void_compact.xml — never shrink below phone size.
    private const val BASELINE_SLASH_WIDTH_DP = 24
    private const val BASELINE_SLASH_HEIGHT_DP = 17
    private const val DEFAULT_WIDGET_SPAN_DP = 70
    // Inner span at which widget_void_compact.xml's 5dp translationY was tuned.
    private const val BASELINE_INNER_DP = DEFAULT_WIDGET_SPAN_DP - WIDGET_ROOT_PADDING_DP

    private const val OPTION_MIN_WIDTH = "appWidgetMinWidth"
    private const val OPTION_MIN_HEIGHT = "appWidgetMinHeight"
    private const val OPTION_MAX_WIDTH = "appWidgetMaxWidth"
    private const val OPTION_MAX_HEIGHT = "appWidgetMaxHeight"

    fun slashLayout(
        options: Bundle,
        orientation: CompactTriangleOrientation,
    ): CompactSlashLayout {
        return slashLayoutForSpan(widgetSpanDp(options), orientation)
    }

    fun slashLayoutForSpan(
        widgetSpanDp: Int,
        orientation: CompactTriangleOrientation,
    ): CompactSlashLayout {
        val innerDp = (widgetSpanDp - WIDGET_ROOT_PADDING_DP).coerceAtLeast(1)
        val widthDp = (innerDp * REF_SLASH_WIDTH_DP.toDouble() / REF_HUB_WIDTH_DP)
            .roundToInt()
            .coerceAtLeast(BASELINE_SLASH_WIDTH_DP)
        val heightDp = (widthDp * REF_SLASH_HEIGHT_DP.toDouble() / REF_SLASH_WIDTH_DP)
            .roundToInt()
            .coerceAtLeast(BASELINE_SLASH_HEIGHT_DP)
        // Scale from the compact-widget baseline (5dp @ 66dp inner), not the
        // wide-panel hub width — otherwise the offset shrinks and the glyph
        // sits too high inside the triangle on every size.
        val translationScale = innerDp.toFloat() / BASELINE_INNER_DP
        val translationYDp = when (orientation) {
            CompactTriangleOrientation.UPRIGHT ->
                REF_TRANSLATION_Y_DP * translationScale
            CompactTriangleOrientation.INVERTED ->
                -REF_TRANSLATION_Y_DP * translationScale
        }
        return CompactSlashLayout(widthDp, heightDp, translationYDp)
    }

    fun widgetSpanDp(options: Bundle): Int {
        val minWidth = options.getInt(OPTION_MIN_WIDTH, 0)
        val maxWidth = options.getInt(OPTION_MAX_WIDTH, 0)
        val minHeight = options.getInt(OPTION_MIN_HEIGHT, 0)
        val maxHeight = options.getInt(OPTION_MAX_HEIGHT, 0)
        val width = if (maxWidth > 0) maxWidth else minWidth
        val height = if (maxHeight > 0) maxHeight else minHeight
        val span = minOf(width, height)
        return if (span > 0) span else DEFAULT_WIDGET_SPAN_DP
    }
}
