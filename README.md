# mastodon-bot

A bot for Mastodon to post image toots with optional text comment.

Features:
* simple login procedure: one just has to specify `client_secret` and `access_token` in secrets.yaml
* images are sourced from a local directory
* pick images randomly or sequentially
* remember the list of already processed images so that each is posted only once
* **use different post texts from a file** - each post can have a different text description
* append text tags like #gif or #video depending on media type
* read the Info-DB for extra data like description and source
* custom text and tags to add with every image
* generate tags from the names of subdirectories. E.g. if path to image is a/b/image.jpg then append extra tags: #a #b
* mark posts as sensitive
* skip files it does not recognize
* downscale too large images to 2048 pixels
* retry on server failures


## Quick Start

0. Install prerequisites:
```
$ cd mastodon_imgbot
$ pip3 install -r requirements.txt
```

1.  Copy `default.config.yaml` to `config.yaml` and edit accordingly.
    The script expects `config.yaml` to be in the current directory.
2.  Generate client secret and access token for your application by visiting
    `https://your_mastodon_instance/settings/applications` and clicking "New app".
3.  Copy `default.secrets.yaml` to the location specified in `config.yaml`
    (default: `secrets.yaml`) and substitute the placeholder text with
    the secret tokens you received on previous step.

Invocation is as simple as:
```
$ python bot.py
```
This will post the next image and return immediately.


## Running with Docker

### Prerequisites
- Docker installed on your system
- Docker Compose (optional, for easier configuration)

### Quick Start with Docker

1. Prepare your configuration files as described in the Quick Start section above:
   - Copy `default.config.yaml` to `config.yaml` and edit accordingly
   - Copy `default.secrets.yaml` to `secrets.yaml` and add your credentials
   - Create a `media` directory with your images

2. Build the Docker image:
```bash
$ docker build -t mastodon-bot .
```

3. Run the bot with Docker:
```bash
$ docker run --rm \
  -v $(pwd)/config.yaml:/app/config.yaml:ro \
  -v $(pwd)/secrets.yaml:/app/secrets.yaml:ro \
  -v $(pwd)/media:/app/media:ro \
  -v $(pwd)/visited.pickledb:/app/visited.pickledb \
  mastodon-bot
```

Note: The `visited.pickledb` file will be created automatically on first run if it doesn't exist.

### Using Docker Compose (Recommended)

Docker Compose simplifies running the bot by managing configuration in a single file. There are two ways to run the bot:

#### Option A: Scheduled Execution (Built-in Scheduler)

The bot can run on a schedule within the container without requiring external cron or systemd.

1. Prepare your configuration files (config.yaml, secrets.yaml, and media directory)

2. Create an empty visited.pickledb file (required for Docker bind mount, will be populated by the bot):
```bash
$ echo '{}' > visited.pickledb
```
Note: Docker requires the file to exist before mounting. The bot will initialize and use this file to track posted images.

3. Start the scheduled bot service:
```bash
$ docker compose up -d mastodon-bot-scheduled
```

4. Configure the schedule interval by setting the `SCHEDULE_INTERVAL` environment variable in docker-compose.yml:
   - `4h` = every 4 hours (default)
   - `30m` = every 30 minutes
   - `1d` = every day
   - `3600s` = every 3600 seconds

5. View logs:
```bash
$ docker compose logs -f mastodon-bot-scheduled
```

6. Stop the scheduled bot:
```bash
$ docker compose down
```

#### Option B: Manual One-off Execution

For manual control or external scheduling (cron/systemd):

```bash
$ docker compose run --rm mastodon-bot
```

### Volume Mounts Explained

The Docker setup uses volume mounts to access your configuration and data:
- `config.yaml`: Your bot configuration (read-only)
- `secrets.yaml`: Your Mastodon credentials (read-only)
- `media/`: Directory containing images to post (read-only)
- `visited.pickledb`: Database tracking posted images (read-write, persisted)
- `info.pickledb`: Optional info database (read-only)

### Alternative Scheduling Methods

The bot is designed to post one image and exit immediately. Besides the built-in scheduler (see "Option A: Scheduled Execution" above), you can also use host-system scheduling:

**Option 1: Cron job**
```bash
# Add to crontab (run every 4 hours)
# Note: 'docker compose run --rm' creates a new container for each run, which is the intended behavior
0 */4 * * * cd /path/to/mastodon-bot && docker compose run --rm mastodon-bot
```

**Option 2: systemd timer with Docker**
Create `/etc/systemd/system/mastodon-bot.service`:
```
[Unit]
Description=Mastodon Image Bot (Docker)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=/path/to/mastodon-bot
ExecStart=/usr/bin/docker compose run --rm mastodon-bot
```

Create `/etc/systemd/system/mastodon-bot.timer`:
```
[Unit]
Description=Timer for Mastodon Image Bot

[Timer]
OnBootSec=15min
OnUnitActiveSec=4h

[Install]
WantedBy=timers.target
```

Enable the timer:
```bash
$ sudo systemctl enable mastodon-bot.timer
$ sudo systemctl start mastodon-bot.timer
```


## Post Texts File
You can configure the bot to use different text descriptions for each post instead of using a fixed text. This is an optional feature.

To use this feature:
1. Create a text file (e.g., `post_texts.txt`) with one post text per line
2. In your `config.yaml`, set `post_texts_file: post_texts.txt`
3. If using Docker, uncomment the volume mount in `docker-compose.yml`:
   ```yaml
   - ./post_texts.txt:/app/post_texts.txt:ro
   ```

Example `post_texts.txt`:
```
Check out this awesome image!
Here's something interesting for you
Another beautiful moment captured
Look what I found today
```

The bot will:
* Load all texts from the file (one per line)
* Skip empty lines
* Use texts in sequential or random order (based on the `order` setting in config.yaml)
* Remember which texts have been used (stored in `visited_texts.pickledb`)
* Fall back to `default_desc` if no texts file is specified or if all texts have been used

## Info-DB
Info-DB is an optional feature. The image does not need to have an entry in the Info-DB to be posted.
It is a json file with list of items as follows
```jsonc
{
    // item #1
    "relative/path/to/file.jpg": {
        "id": 1,
        "desc": "Description",
        "source": [
            "Source String 1",
            "Source String 2",
            "http://source/url/1",
            "http://source/url/2"
        ]
    },
    // item #2
    "relative/path/to/other/file.jpg": {
        //...
    },
    //...
}
```
All fields in an item are optional. `source` may contain arbitrary number of strings. Multiple source entries are concatenated with '|'.
Path must be relative to `image_dir` from `config.yaml`


## Running automatically

To post at regular intervals it can be made into a systemd service.
Copy-paste into `/etc/systemd/system/mastodon_imgbot.service`
Edit `User`, `WorkingDirectory` and path to script in `ExecStart` appropriately.
```
[Unit]
Description=Mastodon Image Bot
Requires=network.target
After=network.target

[Service]
Type=oneshot
User=bot
WorkingDirectory=/home/bot
ExecStart=/usr/bin/python /opt/mastodon_imgbot/bot.py
```

Copy-paste into `/etc/systemd/system/mastodon_imgbot.timer`
```
[Unit]
Description=Timer for Mastodon Image Bot

[Timer]
OnBootSec=15min
OnUnitActiveSec=4h

[Install]
WantedBy=timers.target
```

To install:
```
# systemctl enable mastodon_imgbot.timer
# systemctl start mastodon_imgbot.timer
```

## Related projects
* https://github.com/err4nt/mastodon_imgbot - a very basic mastodon image bot
* https://git.drycat.fr/Dryusdan/masto-image-bot  - a sophisticated mastodon bot with multiple modes of operation