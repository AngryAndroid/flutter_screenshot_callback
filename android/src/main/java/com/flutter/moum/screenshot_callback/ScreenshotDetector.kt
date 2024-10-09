package com.flutter.moum.screenshot_callback

import android.app.Activity
import android.app.Application
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import java.io.File

class ScreenshotDetector(
    private val context: Context,
    private val callback: (name: String?) -> Unit
) {

    private var contentObserver: Array<ContentObserver>? = null
    private val DIRECTORY_KEYWORDS = arrayOf(
        "screenshot", "screen_shot", "screen-shot", "screen shot",
        "screencap", "screen_cap", "screen-cap", "screen cap"
    )
    private var startListenTime = 0L
    private val pathCache = object : LinkedHashMap<String, Any>(16, 1f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Any>?): Boolean {
            return size > 15
        }
    }
    private var isBackground = false
    private var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks = object:
        Application.ActivityLifecycleCallbacks{
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        }

        override fun onActivityStarted(activity: Activity) {
        }

        override fun onActivityResumed(activity: Activity) {
            isBackground = false
        }

        override fun onActivityPaused(activity: Activity) {
            isBackground = true
        }

        override fun onActivityStopped(activity: Activity) {
        }

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        }

        override fun onActivityDestroyed(activity: Activity) {
        }
    }

    fun start() {
        (context.applicationContext as Application).registerActivityLifecycleCallbacks(activityLifecycleCallbacks)

        if (contentObserver == null) {
            startListenTime = System.currentTimeMillis()
            val handler = Handler(Looper.getMainLooper())
            val externalContentObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    reportScreenshotsUpdate(uri, handler)
                }
            }
            val internalContentObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    reportScreenshotsUpdate(uri, handler)
                }
            }
            context.contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                externalContentObserver
            )
            context.contentResolver.registerContentObserver(
                MediaStore.Images.Media.INTERNAL_CONTENT_URI,
                true,
                internalContentObserver
            )
            contentObserver = arrayOf(externalContentObserver, internalContentObserver)
        }
    }

    fun stop() {
        (context.applicationContext as Application).unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks)

        startListenTime = 0L
        contentObserver?.forEach {
            context.contentResolver.unregisterContentObserver(it)
        }
        contentObserver = null
    }

    private fun reportScreenshotsUpdate(uri: Uri?, handler: Handler) {
        if (!isBackground) {
            handler.postDelayed({
                if (uri != null) {
                    callback.invoke(queryScreenshots(uri))
                }
            }, 1000)
        }
    }

    private fun queryScreenshots(uri: Uri): String? {
        return try {
            queryDataColumn(uri)
        } catch (e: Exception) {
            null
        }
    }

    private fun queryDataColumn(uri: Uri): String? {
        val projection = arrayOf(
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.ImageColumns.DATE_TAKEN
        )
        context.contentResolver.query(
            uri,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            val dataColumn = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
            val displayNameColumn = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
            val dateTakenColumn =
                cursor.getColumnIndex(MediaStore.Images.ImageColumns.DATE_TAKEN)
            if (cursor.moveToFirst()) {
                val path = cursor.getString(dataColumn)
                val name = cursor.getString(displayNameColumn)
                val timestamp = cursor.getLong(dateTakenColumn)

                // If the latest image was created before we started listening or more than 5 seconds ago,
                // it must not be a screenshot.
                if (timestamp < startListenTime || (System.currentTimeMillis() - timestamp) > 5 * 1000) {
                    return null
                }

                DIRECTORY_KEYWORDS.forEach {
                    if ((path.contains(it, true) || name.contains(
                            it,
                            true
                        )) && !fileExists(name)
                    ) {
                        val file = File(path)
                        return if (file.exists() && file.length() > 0) {
                            pathCache[name] = Unit

                            val newPath =
                                "${context.cacheDir.absolutePath}/${System.currentTimeMillis()}.${
                                    path.substringAfterLast(
                                        '.',
                                        "jpg"
                                    )
                                }"
                            file.copyTo(File(newPath), true)
                            newPath
                        } else {
                            null
                        }
                    }
                }
            }
        }

        return null
    }

    // Check if the file exists in the cache in case of some unexpected scenario.
    // On some devices the onChange callback will be called for more than 1 times after a screenshot is taken,
    // and it will also be called after an image is deleted.
    private fun fileExists(fileName: String): Boolean {
        return pathCache.contains(fileName)
    }

}