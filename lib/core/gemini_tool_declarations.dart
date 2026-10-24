/// ============================================================
/// AVIS Mobile — Gemini Live Tool Declarations Registry
/// Centralized schemas for all multimodal agent tools.
/// Extracted from gemini_live_client.dart for clean modularity.
/// ============================================================
class GeminiToolDeclarations {
  GeminiToolDeclarations._(); // Prevent instantiation

  /// Returns the complete list of function declarations for Gemini Live Bidi setup
  static List<Map<String, dynamic>> getDeclarations() {
    return [
      {
        "name": "remember_fact",
        "description": "Permanently save a user fact or preference into long-term cognitive memory.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "key": {"type": "STRING", "description": "Key or label for the memory"},
            "value": {"type": "STRING", "description": "The fact details or content"},
            "category": {"type": "STRING", "description": "Category such as 'facts' or 'preferences'"}
          },
          "required": ["key", "value"]
        }
      },
      {
        "name": "recall_memories",
        "description": "Search and retrieve stored long-term memories matching a query keyword.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "query": {"type": "STRING", "description": "Search term or keyword"}
          },
          "required": ["query"]
        }
      },
      {
        "name": "forget_fact",
        "description": "Delete a fact from long-term cognitive memory.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "key": {"type": "STRING", "description": "Key of the fact to remove"}
          },
          "required": ["key"]
        }
      },
      {
        "name": "get_device_telemetry",
        "description": "Retrieve mobile device battery percentage, charging state, real RAM memory, storage, network status, current date/time, and operational metrics.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "get_current_datetime",
        "description": "Get the REAL accurate current date, time, day of week, and timezone from the phone system clock. Call ONLY when explicitly asked for date or time.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "open_permission_settings",
        "description": "Open Android Settings page for missing permissions (ACCESSIBILITY, OVERLAY, USAGE_STATS, NOTIFICATION, APP_DETAILS, PERMISSIONS).",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "setting_type": {"type": "STRING", "description": "Target settings page: 'ACCESSIBILITY', 'OVERLAY', 'USAGE_STATS', 'NOTIFICATION', 'APP_DETAILS', 'PERMISSIONS'."}
          },
          "required": ["setting_type"]
        }
      },
      {
        "name": "start_screen_cast",
        "description": "Start real-time Screen Cast mode to see user's phone screen and answer questions visually.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "stop_screen_cast",
        "description": "Stop real-time Screen Cast mode.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "switch_persona",
        "description": "Switch AI persona between AVIS (male assistant) and BIBA (female companion).",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "target_persona": {"type": "STRING", "description": "Either 'AVIS' or 'BIBA'"}
          },
          "required": ["target_persona"]
        }
      },
      {
        "name": "control_flashlight",
        "description": "Turn phone flashlight ON, OFF, or TOGGLE. MUST ONLY trigger when user speaks an explicit full command like 'AVIS/BIBA Flashlight chalu karo' or 'Flashlight band karo'. DO NOT trigger on single-word mentions or casual conversation.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {
              "type": "STRING",
              "description": "Action: 'ON', 'OFF', or 'TOGGLE'",
              "enum": ["ON", "OFF", "TOGGLE"]
            }
          },
          "required": ["action"]
        }
      },
      {
        "name": "control_bluetooth",
        "description": "Turn device Bluetooth ON, OFF, or TOGGLE. MUST ONLY trigger on explicit full commands like 'AVIS/BIBA Bluetooth chalu/band karo'. DO NOT trigger on casual chatter or single-word mentions.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {
              "type": "STRING",
              "description": "Action: 'ON', 'OFF', or 'TOGGLE'",
              "enum": ["ON", "OFF", "TOGGLE"]
            }
          },
          "required": ["action"]
        }
      },
      {
        "name": "control_brightness",
        "description": "Adjust mobile screen brightness (0-100%). MUST ONLY trigger on explicit full commands like 'AVIS/BIBA Brightness badha/kam karo' or 'Brightness 80% karo'. DO NOT trigger on casual chatter.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "level": {
              "type": "INTEGER",
              "description": "Brightness percentage level from 0 to 100"
            }
          },
          "required": ["level"]
        }
      },
      {
        "name": "control_wifi",
        "description": "Check phone Wi-Fi status or open Wi-Fi settings. MUST ONLY trigger on explicit full commands like 'AVIS/BIBA Wi-Fi connected hai?' or 'Wi-Fi settings kholo'. DO NOT trigger on casual mentions.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {
              "type": "STRING",
              "description": "'STATUS' to check status, or 'OPEN_SETTINGS' to show Wi-Fi toggle panel",
              "enum": ["STATUS", "OPEN_SETTINGS"]
            }
          },
          "required": ["action"]
        }
      },
      {
        "name": "read_sms_messages",
        "description": "Read incoming SMS text messages from the phone inbox. Optionally filter by keyword or sender.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "limit": {"type": "INTEGER", "description": "Number of recent messages to read (1-10)"},
            "query": {"type": "STRING", "description": "Search keyword or sender name filter"}
          }
        }
      },
      {
        "name": "read_active_notifications",
        "description": "Read active notifications from WhatsApp, Instagram, Telegram, Messages, System, etc.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "limit": {"type": "INTEGER", "description": "Number of notifications to read (1-10)"},
            "app_filter": {"type": "STRING", "description": "Filter by app name (e.g. 'whatsapp', 'gmail')"}
          }
        }
      },
      {
        "name": "perform_screen_action",
        "description": "Hands-free screen navigation. Go HOME, BACK, RECENTS, NOTIFICATIONS, CLICK_TEXT, SCROLL. MUST ONLY trigger on explicit direct navigation commands.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {
              "type": "STRING",
              "description": "Navigation action: 'HOME', 'BACK', 'RECENTS', 'NOTIFICATIONS', 'QUICK_SETTINGS', 'CLICK_TEXT', 'SCROLL_DOWN', 'SCROLL_UP', or 'SCREEN_CONTENT'",
              "enum": ["HOME", "BACK", "RECENTS", "NOTIFICATIONS", "QUICK_SETTINGS", "CLICK_TEXT", "SCROLL_DOWN", "SCROLL_UP", "SCREEN_CONTENT"]
            },
            "target_text": {"type": "STRING", "description": "Label or text of button to click when action is 'CLICK_TEXT'"}
          },
          "required": ["action"]
        }
      },
      {
        "name": "open_app",
        "description": "Launch/open an installed Android app by name. MUST ONLY trigger on complete explicit command phrases like 'AVIS/BIBA [App Name] open/chalu/kholo karo'. NEVER trigger on single app name mentions or casual chatter (e.g., 'WhatsApp pe text aaya' should NOT open WhatsApp).",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "app_name": {"type": "STRING", "description": "The name of the app to launch"}
          },
          "required": ["app_name"]
        }
      },
      {
        "name": "write_sandbox_file",
        "description": "Create, save, or update a script, note, code, or text file in the mobile device sandbox storage folder.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "filename": {"type": "STRING", "description": "The name of the file (e.g., script.py, notes.txt, test.html)"},
            "content": {"type": "STRING", "description": "The text or code content to write to the file"}
          },
          "required": ["filename", "content"]
        }
      },
      {
        "name": "read_sandbox_file",
        "description": "Read the text or code contents of a file from the mobile sandbox storage folder.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "filename": {"type": "STRING", "description": "The name of the file to read"}
          },
          "required": ["filename"]
        }
      },
      {
        "name": "list_sandbox_files",
        "description": "List all files currently saved in the mobile sandbox storage folder.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "delete_sandbox_file",
        "description": "Delete a file from the mobile sandbox storage folder.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "filename": {"type": "STRING", "description": "The name of the file to delete"}
          },
          "required": ["filename"]
        }
      },
      {
        "name": "type_text",
        "description": "Type text into an active input field, search bar, chat box, or document. MANDATORY: press_enter MUST ALWAYS BE FALSE when typing text. NEVER set press_enter to true when typing messages or search terms. After typing, you MUST verbally ask the user for confirmation before sending or searching.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "text": {"type": "STRING", "description": "The text content to type into the field"},
            "target_field": {"type": "STRING", "description": "Optional label or hint text of the field/search box to tap first"},
            "press_enter": {"type": "BOOLEAN", "description": "MUST BE FALSE by default when typing text. Only set true if the user explicitly gave a separate voice command to press enter, search, or send."},
            "typography_cadence": {"type": "BOOLEAN", "description": "Set true to use natural human-like typography animation cadence"}
          },
          "required": ["text"]
        }
      },
      {
        "name": "show_code_popup",
        "description": "Display a futuristic floating code overlay popup on the user's phone screen with syntax highlighting and a copy button. Use this whenever you need to show code snippets, scripts, commands, or structured text to the user.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "code": {"type": "STRING", "description": "The code or structured text content to display"},
            "language": {"type": "STRING", "description": "Programming language for syntax highlighting (python, javascript, dart, html, json, text)"},
            "title": {"type": "STRING", "description": "Optional title or description for the overlay header"}
          },
          "required": ["code"]
        }
      },
      {
        "name": "show_sandbox_popup",
        "description": "Display the floating Sandbox File Manager overlay popup on the user's phone screen showing recent files and downloads in the sandbox directory.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "title": {"type": "STRING", "description": "Optional custom header title for the sandbox file manager"}
          }
        }
      },
      {
        "name": "create_calendar_event",
        "description": "Create a new event or reminder directly in the phone calendar.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "title": {"type": "STRING", "description": "Title of the calendar event"},
            "description": {"type": "STRING", "description": "Optional description or notes"},
            "days_from_now": {"type": "INTEGER", "description": "Days from today (0 for today, 1 for tomorrow)"},
            "hour": {"type": "INTEGER", "description": "Hour of the event (0-23)"},
            "minute": {"type": "INTEGER", "description": "Minute of the event (0-59)"},
            "duration_minutes": {"type": "INTEGER", "description": "Duration in minutes (default 30)"},
            "location": {"type": "STRING", "description": "Optional location"}
          },
          "required": ["title"]
        }
      },
      {
        "name": "list_calendar_events",
        "description": "Read upcoming scheduled calendar events from the phone calendar.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "days_ahead": {"type": "INTEGER", "description": "Number of days ahead to search (default 7)"},
            "query": {"type": "STRING", "description": "Optional keyword or title filter"}
          }
        }
      },
      {
        "name": "set_alarm_or_timer",
        "description": "Set an alarm clock or countdown timer directly on the mobile device.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "type": {"type": "STRING", "description": "'alarm' for clock alarm, or 'timer' for countdown timer", "enum": ["alarm", "timer"]},
            "hour": {"type": "INTEGER", "description": "Alarm hour (0-23)"},
            "minute": {"type": "INTEGER", "description": "Alarm minute (0-59)"},
            "seconds": {"type": "INTEGER", "description": "Timer duration in seconds (e.g. 300 for 5 mins)"},
            "message": {"type": "STRING", "description": "Label or message for the alarm/timer"}
          },
          "required": ["type"]
        }
      },
      {
        "name": "manage_contacts",
        "description": "Search existing contacts or add a new contact to the phone contacts directory.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {"type": "STRING", "description": "'search' to find contacts or 'add' to save a new contact", "enum": ["search", "add"]},
            "name": {"type": "STRING", "description": "Contact name or search keyword"},
            "phone": {"type": "STRING", "description": "Phone number when adding a contact"},
            "email": {"type": "STRING", "description": "Optional email when adding a contact"}
          },
          "required": ["action", "name"]
        }
      },
      {
        "name": "control_media",
        "description": "Control active media playback. MUST ONLY trigger on explicit complete playback commands like 'AVIS/BIBA Music play/pause/stop/next/volume badha karo'. NEVER trigger on casual music conversation or single word mentions.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {
              "type": "STRING",
              "description": "Media action: 'PLAY', 'PAUSE', 'TOGGLE', 'NEXT', 'PREVIOUS', 'STOP', 'VOLUME_UP', 'VOLUME_DOWN', 'MUTE', or 'SET_VOLUME'",
              "enum": ["PLAY", "PAUSE", "TOGGLE", "NEXT", "PREVIOUS", "STOP", "VOLUME_UP", "VOLUME_DOWN", "MUTE", "SET_VOLUME"]
            },
            "volume": {"type": "INTEGER", "description": "Target volume level (0-100) when action is 'SET_VOLUME'"}
          },
          "required": ["action"]
        }
      },
      {
        "name": "close_app",
        "description": "Close a running app or go home. MUST ONLY trigger on explicit complete commands like 'AVIS/BIBA [App Name] band/close karo'. NEVER trigger on casual app mentions.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "app_name": {"type": "STRING", "description": "Name of the app to close (e.g. YouTube, Chrome, Settings)"},
            "package_name": {"type": "STRING", "description": "Optional package name"}
          }
        }
      },
      {
        "name": "consult_user_manual",
        "description": "Consult the in-built AVIS Mobile User Manual and Capabilities Guide to look up accurate explanations of app features, gestures, overlays, tools, workflows, and settings.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "query": {
              "type": "STRING",
              "description": "The search term, feature name, or question to look up in the user manual (e.g., 'html preview', 'floating overlay', 'silent mode', 'gestures', 'tools')"
            },
            "topic": {
              "type": "STRING",
              "description": "Optional specific topic ID ('html_runner', 'floating_overlays', 'neural_orb', 'passive_silent_mode', 'typing_safety', 'autonomous_tools', 'dual_personas', 'cognitive_memory', 'system_permissions')"
            }
          },
          "required": ["query"]
        }
      },
      {
        "name": "run_live_preview",
        "description": "Launch or hot-reload the interactive on-device Live Code Playground & Execution Runner. Use this whenever you generate or modify interactive HTML5, CSS3, JavaScript, Canvas 2D/3D, SVG, React standalone, or Web code so Azhar can touch, interact with, and see it run live on his screen.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "code": {
              "type": "STRING",
              "description": "The complete executable code content to run in the playground"
            },
            "language": {
              "type": "STRING",
              "description": "Programming language ('html', 'javascript', 'js', 'svg', 'markdown')"
            },
            "title": {
              "type": "STRING",
              "description": "Optional title for the live preview window (e.g. 'Cyber Calculator', 'Stock Chart', 'Mini Game')"
            }
          },
          "required": ["code"]
        }
      },
      {
        "name": "web_search",
        "description": "Perform a real-time live internet search across the web for current news, live facts, information, documentation, websites, people, or events. ALWAYS call this tool when the user asks a question requiring real-time internet information or external web lookup.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "query": {
              "type": "STRING",
              "description": "Search keyword, query phrase, or topic to search on the web"
            }
          },
          "required": ["query"]
        }
      },
      {
        "name": "get_weather",
        "description": "Get real-time live weather, current temperature (°C), feels-like temperature, conditions, humidity, wind, and forecast for any city or location. ALWAYS call this tool whenever the user asks about the weather, temperature, rain, or climate for any city.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "location": {
              "type": "STRING",
              "description": "City name, region, or location to get weather for (e.g. 'Mumbai', 'Delhi', 'London', 'Tokyo')"
            }
          },
          "required": ["location"]
        }
      },
      {
        "name": "manage_clipboard",
        "description": "Read from or copy text to the mobile phone system clipboard. Use 'READ' to inspect what the user currently has copied, or 'WRITE' to copy text/links/notes to clipboard for the user. INTENT SAFETY: ONLY call when user explicitly asks to copy something to clipboard or check clipboard content.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "action": {
              "type": "STRING",
              "description": "Action to perform: 'READ' to get clipboard text, or 'WRITE' to copy new text to clipboard",
              "enum": ["READ", "WRITE"]
            },
            "text": {
              "type": "STRING",
              "description": "Text content to copy to clipboard when action is 'WRITE'"
            }
          },
          "required": ["action"]
        }
      },
      {
        "name": "send_whatsapp_message",
        "description": "Draft or send a WhatsApp message. MUST ONLY trigger on explicit full commands like 'AVIS/BIBA WhatsApp pe message bhejo'. NEVER trigger on casual WhatsApp mentions.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "phone": {
              "type": "STRING",
              "description": "Optional recipient phone number with country code (e.g. '+919876543210'). Leave empty if not specified by user."
            },
            "message": {
              "type": "STRING",
              "description": "The message text to send or pre-fill in WhatsApp"
            }
          },
          "required": ["message"]
        }
      },
      {
        "name": "get_youtube_channel_stats",
        "description": "Fetch real-time live YouTube Channel statistics (subscribers, total views, video count, title) for the active YouTube channel. ALWAYS call this tool when Azhar asks about YouTube subscriber count, view count, or channel stats.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "get_youtube_recent_videos",
        "description": "Fetch recent published videos from the active YouTube channel with live view counts, likes, and comments. Call this tool when Azhar asks about recent video performance or latest uploads.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "get_youtube_recent_comments",
        "description": "Fetch recent user comments from the active YouTube channel for AI voice analysis and sentiment summary. Call this tool when Azhar asks what viewers or people are commenting on YouTube.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "get_youtube_video_comments",
        "description": "Fetch user comments for a specific YouTube video by video_id.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "video_id": {"type": "STRING", "description": "The target YouTube video ID"}
          },
          "required": ["video_id"]
        }
      },
      {
        "name": "reply_to_youtube_comment",
        "description": "Post a direct text reply to a YouTube viewer comment on the active channel.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "comment_id": {"type": "STRING", "description": "The target YouTube comment ID or thread ID to reply to"},
            "reply_text": {"type": "STRING", "description": "The message reply text to post on YouTube"}
          },
          "required": ["comment_id", "reply_text"]
        }
      },
      {
        "name": "show_youtube_studio_overlay",
        "description": "Open the Sci-Fi Holographic YouTube Creator Studio Overlay on screen for Azhar to view CTR %, watch time, comments, and analytics.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      },
      {
        "name": "show_youtube_hud_overlay",
        "description": "Open the Sci-Fi Holographic YouTube Creator Studio Overlay on screen for Azhar. Call this tool when Azhar asks to show or view the YouTube dashboard on screen.",
        "parameters": {
          "type": "OBJECT",
          "properties": {}
        }
      }
    ];
  }

  /// List of all tool names for telemetry, debugging, and verification tests
  static List<String> getAllToolNames() {
    return getDeclarations()
        .map((t) => t['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }
}
