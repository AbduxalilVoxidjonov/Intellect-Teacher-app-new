package uz.intellectcrm.teacher

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Fayl (hujjat) tanlash uchun O'ZIMIZNING kanalimiz.
 *
 * NIMA UCHUN paket emas: `file_picker` paketi AGP 9 ostida built-in Kotlin YOQILGAN
 * bo'lishini talab qiladi, bizda esa u O'CHIQ bo'lishi shart (firebase_core va boshqa
 * plaginlar `kotlin-android` plaginini o'zi qo'llaydi — built-in Kotlin bilan build
 * buziladi). Shu sabab onlayn test savollari faylini tanlash ACTION_OPEN_DOCUMENT
 * orqali shu yerda amalga oshirilgan — qo'shimcha paketga ehtiyoj yo'q.
 *
 * Dart tarafi: `lib/services/file_pick.dart`.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "uz.intellectcrm.teacher/file_pick"
        const val REQUEST_CODE = 4711
        /** 20 MB — backend `UploadGuard.MaxBytes` bilan bir xil chek. */
        const val MAX_BYTES = 20_000_000L
    }

    /** Ochiq turgan so'rov (bir vaqtda faqat bittasi bo'ladi). */
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pick") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("busy", "Fayl tanlash oynasi allaqachon ochiq", null)
            return
        }
        val mimeTypes = (call.argument<List<String>>("mimeTypes") ?: listOf("*/*")).toTypedArray()
        pending = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                // Android bitta umumiy `type` + aniq turlar ro'yxatini birga kutadi.
                type = if (mimeTypes.size == 1) mimeTypes[0] else "*/*"
                if (mimeTypes.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
            }
            startActivityForResult(intent, REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.error("unavailable", "Fayl tanlash oynasini ochib bo'lmadi: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pending
        pending = null
        if (result == null) return

        // Foydalanuvchi bekor qildi — Dart tarafida `null` qaytadi (xato emas).
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        try {
            var name = "fayl"
            var size = -1L
            contentResolver.query(uri, null, null, null, null)?.use { cursor: Cursor ->
                if (cursor.moveToFirst()) {
                    val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIdx >= 0 && !cursor.isNull(nameIdx)) name = cursor.getString(nameIdx)
                    val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) size = cursor.getLong(sizeIdx)
                }
            }
            if (size > MAX_BYTES) {
                result.error("too_large", "Fayl 20 MB dan katta", null)
                return
            }
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result.error("unreadable", "Faylni o'qib bo'lmadi", null)
                return
            }
            // Provayder SIZE bermagan bo'lishi mumkin — o'qilgandan keyin ham tekshiramiz.
            if (bytes.size > MAX_BYTES) {
                result.error("too_large", "Fayl 20 MB dan katta", null)
                return
            }
            result.success(mapOf("name" to name, "bytes" to bytes, "size" to bytes.size))
        } catch (e: Exception) {
            result.error("unreadable", "Faylni o'qib bo'lmadi: ${e.message}", null)
        }
    }
}
