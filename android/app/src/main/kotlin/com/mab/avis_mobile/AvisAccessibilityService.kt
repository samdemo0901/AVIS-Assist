package com.mab.avis_mobile

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AvisAccessibilityService : AccessibilityService() {

    companion object {
        var instance: AvisAccessibilityService? = null
            private set

        val isServiceRunning: Boolean
            get() = instance != null

        fun performGlobal(action: String): Boolean {
            val service = instance ?: return false
            return when (action.uppercase()) {
                "BACK" -> service.performGlobalAction(GLOBAL_ACTION_BACK)
                "HOME" -> service.performGlobalAction(GLOBAL_ACTION_HOME)
                "RECENTS", "RECENT_APPS" -> service.performGlobalAction(GLOBAL_ACTION_RECENTS)
                "NOTIFICATIONS" -> service.performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
                "QUICK_SETTINGS" -> service.performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
                "LOCK_SCREEN" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        service.performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
                    } else false
                }
                else -> false
            }
        }

        fun clickByText(text: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false
            return try {
                val nodes = root.findAccessibilityNodeInfosByText(text)
                if (nodes.isNullOrEmpty()) {
                    // Try case-insensitive recursive search
                    findAndClickNodeCaseInsensitive(root, text.trim().lowercase())
                } else {
                    for (node in nodes) {
                        if (performClickOnNodeOrParent(node)) {
                            return true
                        }
                    }
                    false
                }
            } catch (e: Exception) {
                false
            }
        }

        private fun findAndClickNodeCaseInsensitive(node: AccessibilityNodeInfo, target: String): Boolean {
            val nodeText = node.text?.toString()?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            if (nodeText.contains(target) || desc.contains(target)) {
                if (performClickOnNodeOrParent(node)) return true
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                if (findAndClickNodeCaseInsensitive(child, target)) {
                    return true
                }
            }
            return false
        }

        private fun performClickOnNodeOrParent(node: AccessibilityNodeInfo): Boolean {
            var current: AccessibilityNodeInfo? = node
            while (current != null) {
                if (current.isClickable) {
                    return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
                current = current.parent
            }
            // If none marked clickable, try direct action anyway
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        fun scroll(direction: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false
            val action = if (direction.uppercase() == "UP") {
                AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            } else {
                AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            }
            return findAndScrollNode(root, action)
        }

        fun typeTextWithTypography(
            text: String,
            targetField: String? = null,
            pressEnter: Boolean = false,
            typographyCadence: Boolean = true
        ): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false

            // 1. If target field label or hint provided, find and click/focus it
            if (!targetField.isNullOrBlank()) {
                clickByText(targetField)
            }

            // 2. Locate editable node (focused or first editable)
            val currentRoot = service.rootInActiveWindow ?: root
            val targetNode = findEditableNode(currentRoot) ?: return false

            return try {
                if (typographyCadence && text.length <= 150) {
                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                    for (i in text.indices) {
                        val subText = text.substring(0, i + 1)
                        handler.postDelayed({
                            try {
                                val args = android.os.Bundle()
                                args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, subText)
                                targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                                if (i == text.length - 1 && pressEnter) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                        targetNode.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)
                                    }
                                    findAndClickSearchOrSend(service.rootInActiveWindow ?: currentRoot)
                                }
                            } catch (_: Exception) {}
                        }, (i * 25).toLong())
                    }
                } else {
                    val args = android.os.Bundle()
                    args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                    targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                    if (pressEnter) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            targetNode.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)
                        }
                        findAndClickSearchOrSend(service.rootInActiveWindow ?: currentRoot)
                    }
                }
                true
            } catch (e: Exception) {
                false
            }
        }

        private fun findEditableNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focused != null && focused.isEditable) return focused
            return findFirstEditableRecursive(root)
        }

        private fun findFirstEditableRecursive(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if (node.isEditable) return node
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val found = findFirstEditableRecursive(child)
                if (found != null) return found
            }
            return null
        }

        private fun findAndClickSearchOrSend(root: AccessibilityNodeInfo): Boolean {
            val searchTerms = listOf("search", "go", "send", "submit", "enter", "khojo", "bhejo")
            for (term in searchTerms) {
                val nodes = root.findAccessibilityNodeInfosByText(term)
                if (!nodes.isNullOrEmpty()) {
                    for (node in nodes) {
                        if (performClickOnNodeOrParent(node)) return true
                    }
                }
            }
            return false
        }

        private fun findAndScrollNode(node: AccessibilityNodeInfo, action: Int): Boolean {
            if (node.isScrollable) {
                if (node.performAction(action)) return true
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                if (findAndScrollNode(child, action)) return true
            }
            return false
        }

        fun getScreenTexts(limit: Int = 20): List<String> {
            val service = instance ?: return emptyList()
            val root = service.rootInActiveWindow ?: return emptyList()
            val texts = mutableListOf<String>()
            extractTextsRecursive(root, texts, limit)
            return texts
        }

        private fun extractTextsRecursive(node: AccessibilityNodeInfo, texts: MutableList<String>, limit: Int) {
            if (texts.size >= limit) return
            val t = node.text?.toString()?.trim()
            if (!t.isNullOrEmpty() && !texts.contains(t)) {
                texts.add(t)
            }
            for (i in 0 until node.childCount) {
                if (texts.size >= limit) break
                val child = node.getChild(i) ?: continue
                extractTextsRecursive(child, texts, limit)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Events monitored for reactive navigation
    }

    override fun onInterrupt() {
        // Interrupted by system
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }
}
