package com.tecuidapp.app.util

import android.util.Base64
import com.tecuidapp.app.BuildConfig
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object EncryptionUtils {
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val AES_ALGORITHM = "AES"
    private const val IV_SIZE_BYTES = 12
    private const val AUTH_TAG_LENGTH_BITS = 128

    private val secureRandom = SecureRandom()

    private val secretKey: SecretKey by lazy {
        val rawKey = BuildConfig.ENCRYPTION_KEY
        require(rawKey.isNotBlank()) {
            "ENCRYPTION_KEY is missing. Please add it to local.properties and sync the project."
        }
        val keyBytes = MessageDigest.getInstance("SHA-256")
            .digest(rawKey.toByteArray(Charsets.UTF_8))
        SecretKeySpec(keyBytes, AES_ALGORITHM)
    }

    fun encrypt(value: String): String {
        if (value.isEmpty()) return value
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val iv = ByteArray(IV_SIZE_BYTES).also { secureRandom.nextBytes(it) }
        val spec = GCMParameterSpec(AUTH_TAG_LENGTH_BITS, iv)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, spec)
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val combined = iv + encrypted
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    fun decrypt(value: String): String {
        if (value.isEmpty()) return value
        return try {
            val decoded = Base64.decode(value, Base64.NO_WRAP)
            if (decoded.size <= IV_SIZE_BYTES) return value
            val iv = decoded.copyOfRange(0, IV_SIZE_BYTES)
            val cipherText = decoded.copyOfRange(IV_SIZE_BYTES, decoded.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val spec = GCMParameterSpec(AUTH_TAG_LENGTH_BITS, iv)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
            val decrypted = cipher.doFinal(cipherText)
            String(decrypted, Charsets.UTF_8)
        } catch (e: Exception) {
            value
        }
    }

    fun hash(value: String): String? {
        if (value.isBlank()) return null
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.trim().toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(digest, Base64.NO_WRAP)
    }
}

