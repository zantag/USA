# Unraid SSH Alert (USA)

[🇧🇬 Български](README.bg.md) | 🇬🇧 English

Bash script for monitoring SSH activity on Unraid servers with push notifications via ntfy.sh.

## 📋 Description

This script monitors SSH logs in real-time and sends notifications for:
- ✅ Successful SSH login
- ❌ Failed login attempt
- 🚪 SSH logout

Notifications include username and IP address information.

## ✨ Features

- **Real-time monitoring** - Uses `tail -F` for continuous syslog monitoring
- **Smart deduplication** - Prevents notification spam (5 sec for failed attempts, 30 sec for others)
- **Prioritization** - Different priority levels based on event type
- **Easy setup** - Only one parameter to configure

## 🚀 Installation

### 1. Download the script

```bash
wget https://raw.githubusercontent.com/zantag/USA/main/unraid-ssh-alert.sh
chmod +x unraid-ssh-alert.sh
```

### 2. Configure ntfy.sh topic

Edit the script and change `NTFY_TOPIC`:

```bash
nano unraid-ssh-alert.sh
```

Find the line:
```bash
NTFY_TOPIC="put-your-ntfy-topic"
```

And replace it with your ntfy.sh topic (e.g., `my-unraid-alerts`).

### 3. Test the script

```bash
./unraid-ssh-alert.sh
```

Open a new SSH session to the server - you should receive a notification.

## 🔧 Auto-start

### Option 1: User Scripts Plugin (recommended)

1. Install **User Scripts** plugin from Community Applications
2. Create a new script
3. Copy the contents of `unraid-ssh-alert.sh`
4. Set it to run **At Startup of Array**

### Option 2: Via /boot/config/go

Add to `/boot/config/go`:

```bash
/path/to/unraid-ssh-alert.sh &
```

## 📱 ntfy.sh Setup

1. Install the ntfy app on your phone:
   - [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [iOS](https://apps.apple.com/app/ntfy/id1625396347)

2. Subscribe to your topic (same as in `NTFY_TOPIC`)

3. Done! You'll receive notifications for SSH activity

## 🔒 Security

- The script runs locally and doesn't send sensitive information
- Uses the public ntfy.sh server (or you can host your own)
- For additional security, check out [ntfy authentication](https://docs.ntfy.sh/publish/#authentication)

## 📝 Requirements

- Unraid 6.x or newer
- `curl` (pre-installed on Unraid)
- Internet connection for ntfy.sh notifications

## 🐛 Troubleshooting

### Not receiving notifications

1. Check if the script is running:
   ```bash
   ps aux | grep unraid-ssh-alert
   ```

2. Test ntfy.sh manually:
   ```bash
   curl -d "Test message" https://ntfy.sh/your-topic
   ```

3. Check the logs:
   ```bash
   tail -f /var/log/syslog | grep sshd
   ```

### Receiving too many notifications

The script has built-in deduplication. If you're still receiving too many, you can increase the `DUP_TIME` values in the script.

## 📄 License

MIT License - free to use and modify

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss.

## 👤 Author

**zantag**

---

⭐ If this script is useful to you, leave a star on the repo!
