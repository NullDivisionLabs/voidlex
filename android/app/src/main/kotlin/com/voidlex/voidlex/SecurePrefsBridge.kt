package com.voidlex.voidlex

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/// Thin wrapper around EncryptedSharedPreferences for credentials we do not
/// want sitting in plain-text SharedPreferences (proxy auth password today;
/// extendable to other secrets). The MasterKey is anchored in the Android
/// KeyStore, so the underlying bytes-at-rest are encrypted with a hardware-
/// backed AES-256 key when available.
internal object SecurePrefsBridge {
    private const val TAG = "SecurePrefsBridge"
    private const val PREFS_NAME = "void_secure_prefs"

    @Volatile
    private var cached: SharedPreferences? = null

    fun get(context: Context, key: String): String? {
        return runCatching {
            prefs(context).getString(key, null)
        }.getOrElse {
            AppLogger.e(TAG, "secureGet failed for $key", it)
            null
        }
    }

    fun set(context: Context, key: String, value: String): Boolean {
        return runCatching {
            prefs(context).edit().putString(key, value).apply()
            true
        }.getOrElse {
            AppLogger.e(TAG, "secureSet failed for $key", it)
            false
        }
    }

    fun remove(context: Context, key: String): Boolean {
        return runCatching {
            prefs(context).edit().remove(key).apply()
            true
        }.getOrElse {
            AppLogger.e(TAG, "secureRemove failed for $key", it)
            false
        }
    }

    private fun prefs(context: Context): SharedPreferences {
        val existing = cached
        if (existing != null) return existing
        return synchronized(this) {
            cached ?: build(context).also { cached = it }
        }
    }

    private fun build(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }
}
