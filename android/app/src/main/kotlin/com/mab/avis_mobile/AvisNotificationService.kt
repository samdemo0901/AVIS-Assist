package com.mab.avis_mobile

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.CopyOnWriteArrayList

class AvisNotificationService : NotificationListenerService() {

    companion object {
        var isConnected: Boolean = false
            private set

        private val notificationList = CopyOnWriteArrayList<Map<String, Any>>()
        private const val MAX_STORED = 50

        fun getRecentNotifications(limit: Int = 10, appFilter: String? = null): List<Map<String, Any>> {
            val filter = appFilter?.trim()?.lowercase()
            val filtered = if (filter.isNullOrEmpty()) {
                notificationList
            } else {
                notificationList.filter {
                    val pkg = (it["package"] as? String)?.lowercase() ?: ""
                    val title = (it["title"] as? String)?.lowercase() ?: ""
                    pkg.contains(filter) || title.contains(filter)
                }
            }
            return filtered.take(limit)
        }

        fun clearNotifications() {
            notificationList.clear()
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        fetchActiveNotifications()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        extractAndStoreNotification(sbn)
    }

    private fun extractAndStoreNotification(sbn: StatusBarNotification) {
        try {
            val notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
            val pkg = sbn.packageName ?: ""

            // Skip empty notifications or self
            if (pkg == "com.mab.avis_mobile" || pkg == "com.example.avis_mobile" || (title.isEmpty() && text.isEmpty())) {
                return
            }

            val item = mapOf<String, Any>(
                "package" to pkg,
                "title" to title,
                "text" to text,
                "subText" to subText,
                "timestamp" to sbn.postTime,
                "isOngoing" to sbn.isOngoing
            )

            // Insert at beginning
            notificationList.add(0, item)
            while (notificationList.size > MAX_STORED) {
                notificationList.removeAt(notificationList.size - 1)
            }
        } catch (e: Exception) {
            // Non-blocking catch
        }
    }

    private fun fetchActiveNotifications() {
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                extractAndStoreNotification(sbn)
            }
        } catch (e: Exception) {
            // Permission or security exception
        }
    }
}
