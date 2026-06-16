# s3sync

**s3sync** is a Dockerized tool for synchronizing digitized media files and Docker registry content to offsite S3-compatible storage. It is designed to run as a cronjob from multiple servers, providing automated, reliable backup of large filesystems to object storage.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Server: dockerhem (media content)              │
│  Server: opendata-lab (Docker registry)         │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  s3sync (Docker container)                │  │
│  │                                           │
│  │  ENV vars:                                │
│  │    SRCPATH   → local source directory     │  │
│  │    DSTPATH   → S3 bucket path             │  │
│  │    CFGPATH   → s3cmd config directory     │  │
│  │    S3EXTRA   → extra s3cmd flags          │  │
│  │                                           │
│  │  Mounts:                                  │
│  │    STORE_HOST_PATH  → STORE_CONTAINER     │  │
│  │    S3CFG_HOST_PATH  → S3CFG_CONTAINER     │  │
│  └───────────────────────────────────────────┘  │
│         │                                       │
│         │ s3cmd sync                            │
│         ▼                                       │
│  ┌──────────────┐                               │
│  │  S3 Bucket   │  (offsite storage)            │
│  └──────────────┘                               │
└─────────────────────────────────────────────────┘
```

Each server runs its own containerized instance, each pointing at a different source directory but sharing the same image and configuration format.

## What It Does

For each top-level entry in the source directory (`SRCPATH`), the script runs an `s3cmd sync` to that entry's contents in the S3 bucket (`DSTPATH`). This means:

- Each subdirectory of the source becomes a separate "item" in the bucket (or a prefix path, depending on the S3 backend).
- Only new or changed files are transferred (s3cmd's `sync` mode).
- MD5 checks are skipped (`--no-check-md5`) for faster transfers over large media files.

## Project Structure

```
s3sync/
├── s3sync.sh          # Main synchronization script
├── Dockerfile          # Docker image definition (Ubuntu 20.04 + s3cmd)
├── docker-compose.yml  # Docker Compose configuration
├── .env                # Default environment variables
├── .gitignore          # Git ignore rules
├── .dockerignore       # Docker build ignore rules
└── cfg/
    └── s3cfg.sample    # Sample s3cmd configuration file
```

## Files Explained

### `s3sync.sh` — Main Script

The core script. It iterates over every entry in `$SRCPATH` and runs `s3cmd sync` on each one.

**Requirements:**
- `SRCPATH` — The local directory to synchronize from (required, exits with code 1 if unset)
- `DSTPATH` — The S3 destination path, e.g. `s3://mybucket/path/` (required, exits with code 2 if unset)
- `CFGPATH` — Directory containing the s3cmd config file `s3cfg` (required, exits with code 3 if unset)
- `S3EXTRA_PARAMS` — Optional extra flags passed to `s3cmd sync` (e.g. `-n` for dry-run)

**Behavior:**
1. Changes into `$SRCPATH`.
2. Loops over every entry (`*` glob) in that directory.
3. For each entry, logs the start time, runs `s3cmd sync`, then logs the completion.
4. Timestamps are printed via `date` at each step for monitoring.

**Exit codes:**
| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | `SRCPATH` not set |
| 2    | `DSTPATH` not set |
| 3    | `CFGPATH` not set |
| >3   | s3cmd failure (exit code from s3cmd itself) |

### `Dockerfile`

Builds a minimal container image based on **Ubuntu 20.04**.

**Base image:** `ubuntu:20.04`

**Installed packages:**
- `python3-pip` — Required for the s3cmd pip install
- `less` — For paging output if needed
- `s3cmd` — The S3 command-line tool, installed via `pip3`

The script `s3sync.sh` is copied to `/usr/local/bin/` inside the image.

### `docker-compose.yml`

Defines the Docker Compose service with the following configuration:

| Variable                  | Docker Compose Variable       | Purpose                                         |
|---------------------------|-------------------------------|-------------------------------------------------|
| `CFGPATH`                 | `$S3CFG_CONTAINER_PATH`       | Path to s3cmd config inside the container       |
| `SRCPATH`                 | `$STORE_CONTAINER_PATH`       | Source directory inside the container           |
| `DSTPATH`                 | `$TARGET_S3_BUCKET_PATH`      | S3 destination bucket path                      |
| `S3EXTRA_PARAMS`          | `$S3EXTRA_PARAMS`             | Extra s3cmd flags                               |
| `image`                   | `docker.ub.gu.se/s3sync:${GIT_REVISION}` | Image name and tag (uses a git revision) |

**Volumes:**
| Host path              | Container path             |
|------------------------|----------------------------|
| `$STORE_HOST_PATH`     | `$STORE_CONTAINER_PATH`    |
| `$S3CFG_HOST_PATH`     | `$S3CFG_CONTAINER_PATH`    |

### `.env`

Default environment variables. Edit this file for your setup:

| Variable                | Default Value           | Description                                          |
|-------------------------|-------------------------|------------------------------------------------------|
| `GIT_REVISION`          | `local`                 | Git commit hash or tag used in the image tag         |
| `STORE_HOST_PATH`       | `./data`                | Local path containing files to back up               |
| `S3CFG_HOST_PATH`       | `./cfg`                 | Local path containing the s3cmd config file          |
| `STORE_CONTAINER_PATH`  | `/app/store`            | Mount point for source data inside the container     |
| `S3CFG_CONTAINER_PATH`  | `/app/cfg`              | Mount point for s3cmd config inside the container    |
| `TARGET_S3_BUCKET_PATH` | `s3://s3-bucket-path/`  | S3 bucket path to sync to (edit this!)               |
| `S3EXTRA_PARAMS`        | `-n`                    | Extra s3cmd parameters (`-n` = dry-run / no upload)  |

> **Note:** The default `-n` in `S3EXTRA_PARAMS` means the default configuration runs in **dry-run** mode. Remove or change it to perform actual uploads.

### `cfg/s3cfg.sample`

A sample s3cmd configuration file. Copy this to `cfg/s3cfg` (or wherever `$S3CFG_HOST_PATH` points) and fill in your details:

| Field                    | Description                                    | Example                          |
|--------------------------|------------------------------------------------|----------------------------------|
| `access_key`             | Your S3 access key ID                          | `AKIAIOSFODNN7EXAMPLE`           |
| `secret_key`             | Your S3 secret access key                      | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `check_ssl_certificate`  | Whether to check SSL certificates (`True`/`False`) | `False`                    |
| `guess_mime_type`        | Auto-detect MIME types (`True`/`False`)        | `True`                           |
| `host_base`              | S3-compatible storage endpoint host            | `s3.example.com`                 |
| `host_bucket`            | S3 bucket URL pattern                        | `{bucket}.s3.example.com`        |
| `use_https`              | Use HTTPS (`True`/`False`)                     | `True`                           |

### `.gitignore`

Ignores:
- `cfg/s3cfg` — The actual s3cmd config (contains secrets)
- Editor backup files: `*~`, `\#*#`, `.#*`

### `.dockerignore`

Ignores the `cfg/` directory during Docker builds to prevent the config from being baked into the image (it is mounted at runtime instead).

## Usage

### 1. Build the Image

```bash
# Build the Docker image
docker build -t docker.ub.gu.se/s3sync:latest .

# Or use docker-compose to build (uses GIT_REVISION from .env)
docker-compose build
```

### 2. Configure

Copy and edit the sample config:

```bash
cp cfg/s3cfg.sample cfg/s3cfg
nano cfg/s3cfg  # Edit access_key, secret_key, host_base, host_bucket
```

Edit `.env` to set the correct paths and S3 bucket:

```bash
nano .env
```

### 3. Run

#### Dry-run (default, since S3EXTRA_PARAMS=-n):

```bash
docker-compose up
```

#### Live sync:

```bash
# Override S3EXTRA_PARAMS in .env:
S3EXTRA_PARAMS=

# Or override on the command line:
docker-compose run --rm s3sync
```

#### With explicit parameters:

```bash
SRCPATH=/path/to/source \
DSTPATH="s3://mybucket/backup/" \
CFGPATH=/path/to/config/dir \
docker run --rm \
  -v /path/to/source:/app/store \
  -v /path/to/config:/app/cfg \
  -e CFGPATH=/app/cfg \
  -e SRCPATH=/app/store \
  -e DSTPATH=s3://mybucket/backup/ \
  docker.ub.gu.se/s3sync:latest
```

## Running as a Cronjob

Each server ("dockerhem" for media content, "opendata-lab" for Docker registry content) runs s3sync as a cronjob. Example cron entry:

```cron
# Run s3sync every day at 2:00 AM
0 2 * * * cd /path/to/s3sync && docker-compose run --rm s3sync >> /var/log/s3sync.log 2>&1
```

Each server would have its own `.env` with the appropriate `STORE_HOST_PATH` and possibly different `TARGET_S3_BUCKET_PATH`.

## S3-Compatible Storage

s3cmd works with any S3-compatible storage backend (MinIO, Ceph, DigitalOcean Spaces, Wasabi, etc.). Configure `host_base` and `host_bucket` in `cfg/s3cfg` accordingly.

For a standard AWS S3 bucket:
```
host_base = s3.amazonaws.com
host_bucket = %(bucket).s3.amazonaws.com
```

## Notes

- **s3cmd `sync` mode**: Only transfers new and modified files. Deleted files in the source are NOT deleted in the destination. Use `s3cmd rm` separately if you need one-way deletion.
- **`--no-check-md5`**: Speeds up transfers by skipping MD5 checksum verification. This is safe for most use cases but may miss byte-level corruption.
- **Per-directory sync**: Each top-level entry in `$SRCPATH` is treated as a separate sync target, which is ideal for backing up a collection of independent media packages or a Docker registry directory.
- **Ubuntu 20.04 base**: The Dockerfile uses Ubuntu 20.04. For newer systems, consider updating the base image.

## Environment Variables Summary

| Variable | Required | Description |
|----------|----------|-------------|
| `SRCPATH` | Yes | Source directory to sync from |
| `DSTPATH` | Yes | S3 destination path |
| `CFGPATH` | Yes | Directory containing s3cmd config file |
| `S3EXTRA_PARAMS` | No | Extra s3cmd flags (e.g., `-n` for dry-run) |
| `GIT_REVISION` | No | Git revision used in Docker image tag (docker-compose) |
| `STORE_HOST_PATH` | No | Local host path for source data (docker-compose) |
| `STORE_CONTAINER_PATH` | No | Container path for source data (docker-compose) |
| `S3CFG_HOST_PATH` | No | Local host path for s3cmd config (docker-compose) |
| `S3CFG_CONTAINER_PATH` | No | Container path for s3cmd config (docker-compose) |
| `TARGET_S3_BUCKET_PATH` | No | S3 bucket path to sync to (docker-compose) |
