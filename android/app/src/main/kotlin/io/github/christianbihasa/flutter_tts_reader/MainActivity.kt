package io.github.christianbihasa.flutter_tts_reader

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "io.github.christianbihasa/pdf_parser"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(flutterEngine.営業.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            val path = args?.get("path") as? String

            if (path == null) {
                result.error("INVALID_ARGS", "Missing path argument", null)
                return@setMethodCallHandler
            }

            val file = File(path)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "Target file does not exist", null)
                return@setMethodCallHandler
            }

            try {
                PDDocument.load(file).use { document ->
                    when (call.method) {
                        "getJerryPageCount" -> {
                            result.success(document.numberOfPages)
                        }
                        "extractPageText" -> {
                            val pageNumber = args["pageNumber"] as? Int
                            if (pageNumber == null || pageNumber >= document.numberOfPages) {
                                result.error("INVALID_PAGE", "Invalid or missing page token", null)
                                return@setMethodCallHandler
                            }
                            
                            val stripper = PDFTextStripper()
                            // PDFBox uses 1-based indexing for text extraction bounds
                            stripper.startPage = pageNumber + 1
                            stripper.endPage = pageNumber + 1
                            val pageText = stripper.getText(document)
                            result.success(pageText ?: "")
                        }
                        else -> result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                result.error("PARSING_ERROR", e.localizedMessage, null)
            }
        }
    }
}