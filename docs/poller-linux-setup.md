# Running the Poller on Linux with systemd

This guide covers setting up the Match Chat results poller to run continuously on a Linux server using systemd, with automatic restarts and boot-time startup.

## Prerequisites

- Linux server with systemd (Ubuntu, Debian, Fedora, etc.)
- Python 3.11+
- Git access to the match-chat repository
- API-Football API key (from https://dashboard.api-football.com)
- Firebase service account key (from Firebase console)

## Setup Steps

### 1. Clone the repository and prepare the environment

```bash
cd /opt  # or wherever you prefer to keep the app
git clone https://github.com/yourusername/match-chat.git
cd match-chat/src/backend/poller
```

### 2. Create and activate a Python virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and set:
- `API_FOOTBALL_KEY`: Your API-Football key
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to your Firebase service account JSON (e.g., `/opt/match-chat/src/backend/poller/service-account.json`)

Place the Firebase service account key in this directory:
```bash
cp /path/to/your/service-account.json /opt/match-chat/src/backend/poller/service-account.json
chmod 600 /opt/match-chat/src/backend/poller/service-account.json
```

### 4. Test the setup

Before setting up systemd, verify everything works:

```bash
python poller.py --once
```

This should sync all fixtures to Firestore and exit. Check for errors and confirm the connection works before proceeding.

### 5. Create the systemd service file

Create `/etc/systemd/system/match-chat-poller.service`:

```ini
[Unit]
Description=Match Chat Results Poller
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=poller
WorkingDirectory=/opt/match-chat/src/backend/poller
Environment="PATH=/opt/match-chat/src/backend/poller/.venv/bin"
ExecStart=/opt/match-chat/src/backend/poller/.venv/bin/python poller.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Optional: Create a dedicated user** (recommended for security):
```bash
sudo useradd -r -s /bin/false poller
sudo chown -R poller:poller /opt/match-chat/src/backend/poller
```

Or if running as your own user, change `User=poller` to `User=yourusername`.

### 6. Enable and start the service

```bash
sudo systemctl daemon-reload
sudo systemctl enable match-chat-poller
sudo systemctl start match-chat-poller
```

### 7. Verify it's running

```bash
sudo systemctl status match-chat-poller
```

## Managing the Service

### View live logs
```bash
sudo journalctl -u match-chat-poller -f
```

### View logs since last boot
```bash
sudo journalctl -u match-chat-poller -b
```

### Stop the poller
```bash
sudo systemctl stop match-chat-poller
```

### Restart the poller
```bash
sudo systemctl restart match-chat-poller
```

### Check if it's enabled to auto-start
```bash
sudo systemctl is-enabled match-chat-poller
```

## Troubleshooting

### Service fails to start
Check the logs for errors:
```bash
sudo journalctl -u match-chat-poller -n 50
```

Common issues:
- **Python not found**: Verify the path to the virtual environment is correct
- **Module not found**: Ensure `pip install -r requirements.txt` was run
- **Permission denied**: Check that the user has read/execute permissions on the directory
- **Firestore connection failed**: Verify `GOOGLE_APPLICATION_CREDENTIALS` path and that the service account key is accessible

### High memory/CPU usage
The poller sleeps during idle time and only polls during active match windows. If consuming resources during idle periods, there may be a bug — check the logs and ensure `POLL_INTERVAL_SECONDS` and `MAX_POLL_INTERVAL_SECONDS` are set reasonably (default: 300s and 900s).

### Updates and restarts
To pull and deploy a newer version:
```bash
cd /opt/match-chat
git pull
sudo systemctl restart match-chat-poller
```

## Notes

- The poller respects API-Football's free tier (100 requests/day) and will throttle requests if approaching the limit
- The local cache file (`.poller-cache.json`) prevents redundant writes to Firestore
- Logs are sent to the systemd journal and can be queried at any time
- The service will automatically restart if it crashes (after 10 seconds)
- On server reboot, the service will start automatically
