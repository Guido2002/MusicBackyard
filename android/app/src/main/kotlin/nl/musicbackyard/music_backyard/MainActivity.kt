package nl.musicbackyard.music_backyard

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.android.apksig.ApkVerifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    @Suppress("DEPRECATION")
    private fun distribution(): String {
        val source = if (Build.VERSION.SDK_INT >= 30) {
            packageManager.getInstallSourceInfo(packageName).installingPackageName
        } else packageManager.getInstallerPackageName(packageName)
        return if (source == "com.android.vending" || BuildConfig.FLAVOR == "play") "play" else "direct"
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nl.musicbackyard/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "distribution" -> result.success(distribution())
                    "install" -> {
                        if (distribution() != "direct" || BuildConfig.FLAVOR != "direct") {
                            result.error("CHANNEL", "Direct updates are disabled for store builds", null)
                            return@setMethodCallHandler
                        }
                        val path = call.argument<String>("path")
                        val hash = call.argument<String>("sha256")
                        val build = call.argument<Number>("buildNumber")?.toLong()
                        if (path == null || hash == null || build == null) {
                            result.error("INPUT", "Missing update information", null)
                            return@setMethodCallHandler
                        }
                        worker.execute {
                            try {
                                val file = validateApk(path, hash, build)
                                runOnUiThread {
                                    try {
                                        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                                            result.success("permissionRequired")
                                        } else {
                                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                                setDataAndType(uri, "application/vnd.android.package-archive")
                                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                            }
                                            startActivity(intent)
                                            // System installer owns confirmation, cancellation and final signature checks.
                                            result.success("started")
                                        }
                                    } catch (error: Exception) { result.error("INSTALL", error.javaClass.simpleName, null) }
                                }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("VERIFICATION", error.message ?: "Invalid APK", null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    @Suppress("DEPRECATION")
    private fun validateApk(path: String, expectedHash: String, expectedBuild: Long): File {
        val file = File(path).canonicalFile
        val root = File(cacheDir, "musicbackyard-updates").canonicalFile
        require(file.parentFile == root && file.isFile && file.extension == "apk") { "Invalid cache file" }
        require(expectedHash.matches(Regex("[a-f0-9]{64}"))) { "Invalid hash" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { stream ->
            val buffer = ByteArray(65536)
            while (true) { val count = stream.read(buffer); if (count < 0) break; digest.update(buffer, 0, count) }
        }
        require(digest.digest().joinToString("") { "%02x".format(it) } == expectedHash) { "Integrity mismatch" }
        val verified = ApkVerifier.Builder(file).setMinCheckedPlatformVersion(Build.VERSION.SDK_INT).build().verify()
        require(verified.isVerified) { "APK signature verification failed" }
        val archive = packageManager.getPackageArchiveInfo(file.path, 0) ?: error("Unreadable APK")
        require(archive.packageName == packageName) { "Wrong package identity" }
        val installed = packageManager.getPackageInfo(packageName,
            if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES)
        val currentBuild = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        val candidateBuild = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
        require(candidateBuild == expectedBuild && candidateBuild > currentBuild) { "Invalid version code" }
        val trusted = if (Build.VERSION.SDK_INT >= 28) installed.signingInfo!!.apkContentsSigners.toList() else installed.signatures!!.toList()
        val candidate = verified.signerCertificates.map { it.encoded.toList() }.toSet()
        require(candidate == trusted.map { it.toByteArray().toList() }.toSet()) { "Untrusted signing certificate" }
        return file
    }
}
