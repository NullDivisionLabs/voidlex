package com.voidlex.voidlex

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.LruCache
import java.io.ByteArrayOutputStream

internal object InstalledAppsBridge {
    private const val TAG = "InstalledAppsBridge"
    // 64 px is what the routing settings list renders at; 96 px was 2× the
    // visible size on every common density. Combined with WebP encoding
    // below this trims the per-icon payload by ~70%.
    private const val ICON_SIZE_PX = 64
    private const val ICON_CACHE_SIZE = 256

    // Encoded-bytes cache keyed by package name. PackageInfo lookups dominate
    // the cold path; on the warm path we serve straight from this LRU and
    // skip both the PackageManager call and the encode pass.
    private val iconCache = LruCache<String, ByteArray>(ICON_CACHE_SIZE)

    fun list(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager

        val installed = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledApplications(0)
            }
        }.getOrElse {
            AppLogger.e(TAG, "Failed to enumerate installed applications", it)
            return emptyList()
        }

        val ownPackage = context.packageName

        return installed
            .asSequence()
            .filter { info -> info.packageName != ownPackage }
            .map { info ->
                val label = runCatching { pm.getApplicationLabel(info).toString() }
                    .getOrDefault(info.packageName)
                val isSystem = isAndroidInternalApp(pm, info)
                mapOf(
                    "name" to label,
                    "packageName" to info.packageName,
                    "isSystem" to isSystem,
                )
            }
            .sortedWith(
                compareBy(
                    { (it["isSystem"] as Boolean) },
                    { (it["name"] as String).lowercase() },
                ),
            )
            .toList()
    }

    fun icon(context: Context, packageName: String?): ByteArray {
        if (packageName.isNullOrBlank()) return ByteArray(0)
        iconCache.get(packageName)?.let { return it }

        val pm = context.packageManager
        val info = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(packageName, 0)
            }
        }.getOrElse {
            AppLogger.w(TAG, "Failed to resolve app icon target $packageName", it)
            return ByteArray(0)
        }
        val encoded = encodeIcon(pm, info)
        if (encoded.isNotEmpty()) {
            iconCache.put(packageName, encoded)
        }
        return encoded
    }

    // "System" only covers Android-internal, headless components (system UI,
    // providers, services without a launcher entry). User-facing preinstalls —
    // Chrome, YouTube, Gmail, Phone, Settings — all expose a launcher intent
    // and are surfaced as regular apps regardless of partition.
    private fun isAndroidInternalApp(pm: PackageManager, info: ApplicationInfo): Boolean {
        val onSystemPartition = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        if (!onSystemPartition) return false
        val launchIntent = runCatching { pm.getLaunchIntentForPackage(info.packageName) }
            .getOrNull()
        return launchIntent == null
    }

    private fun encodeIcon(pm: PackageManager, info: ApplicationInfo): ByteArray {
        val drawable = runCatching { pm.getApplicationIcon(info) }
            .getOrElse {
                AppLogger.w(TAG, "Failed to load icon for ${info.packageName}", it)
                return ByteArray(0)
            }
        val bitmap = drawable.toBitmap(ICON_SIZE_PX, ICON_SIZE_PX)
        val baos = ByteArrayOutputStream()
        val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // WebP lossy at q=85 is ~3-4× smaller than PNG for these icons
            // and visually indistinguishable at 64 px. The lossless variant
            // (WEBP_LOSSLESS on R+) is overkill for adaptive-icon foregrounds
            // that are already gradient-heavy.
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            @Suppress("DEPRECATION")
            Bitmap.CompressFormat.WEBP
        }
        bitmap.compress(format, 85, baos)
        if (bitmap !== (drawable as? BitmapDrawable)?.bitmap) {
            bitmap.recycle()
        }
        return baos.toByteArray()
    }

    private fun Drawable.toBitmap(width: Int, height: Int): Bitmap {
        if (this is BitmapDrawable) {
            val source = bitmap
            if (source != null && !source.isRecycled) {
                if (source.width == width && source.height == height) {
                    return source
                }
                return Bitmap.createScaledBitmap(source, width, height, true)
            }
        }

        val outWidth = width.coerceAtLeast(1)
        val outHeight = height.coerceAtLeast(1)
        val output = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val previousBounds = bounds
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && this is AdaptiveIconDrawable) {
            // Adaptive icons rely on bounds to render foreground+background.
            setBounds(0, 0, outWidth, outHeight)
        } else {
            setBounds(0, 0, outWidth, outHeight)
        }
        draw(canvas)
        bounds = previousBounds
        return output
    }
}
