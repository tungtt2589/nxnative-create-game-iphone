# nxnative-create-game-iphone

Build Nintendo Switch games thanh IPA de chay tren iPhone, su dung pipeline tu dong qua GitHub Actions + Scaleway Apple Silicon.

---

## Tong quan kien truc

```
Google Drive (game files .rar/.nsp)
    down rclone download
Scaleway M4-SP (bare-metal Apple M4, Metal 4)
    -> GitHub Actions self-hosted runner
    -> nxnative build (Python 3.12 + .NET 10 + Metal Toolchain)
    -> IPA + RomFS.img artifact
    down gh run download (tren Scaleway)
    down rsync/SCP ve Mac local (~450 KB/s)
iPhone (Sideloadly install + RomFS qua Finder USB)
```

---

## Tai sao can Scaleway (khong dung GitHub hosted runner)

| | GitHub hosted xcode-27 | Scaleway M4-SP |
|---|---|---|
| Metal GPU | VM (paravirtualized, NO Metal 4) | Bare-metal Apple M4 - Metal 4 OK |
| Dung cho game nao | Hau het game | FE3H va game can Metal 4 |
| Chi phi | Free | ~EU0.30-0.40/hr, minimum 1 ngay |

FE3H can Metal 4 vi dung MTL4FXTemporalScaler. Tren VM chay se crash o buoc GLSL capture.

---

## Prerequisites

### Repos
- Build repo: `tungtt2589/nxnative-create-game-iphone` (private)
- nxnative fork: `tungtt2589/nxnative` (private)
- nxnative upstream: `seedds/nxnative`

### GitHub Secrets can co
| Secret | Mo ta |
|--------|-------|
| `GDRIVE_ROOT_ID` | ID thu muc root Google Drive |
| `GDRIVE_SA_JSON` | Service account JSON cho rclone |

### Google Drive layout
```
Root/  (ID: 1EwdiG20Beo2jbPrwmYlp7e8sK9IpMUTs)
  keys/
    prod.keys          <- Nintendo Switch keys (bat buoc)
  Games/               <- chu G hoa!
    FE3H/
      base.part1.rar, base.part2.rar, update.rar, dlc1.rar...
    octopath1/
      base.rar
    octopath2/
      base.rar
    <game_name>/       <- ten folder = game_name khi trigger build
```

**File naming convention:**
- Multi-part: `base.part01.rar`, `base.part02.rar`, ...
- Single: `base.rar`
- Update: `update.rar`
- DLC: `dlc.rar` hoac `dlc1.rar`, `dlc2.rar`, ...
- Hoac NSP files truc tiep (khong can RAR)

---

## Workflow 1: Build tren GitHub hosted runner (khong can Scaleway)

File: `.github/workflows/build-ipa.yml`

Dung cho cac game **khong can Metal 4** (Octopath, Tactics Ogre, FF Tactics...).

Trigger:
```
GitHub -> Actions -> Build IPA -> Run workflow -> game_name: octopath2
```

---

## Workflow 2: Build tren Scaleway (can Metal 4)

File: `.github/workflows/build-ipa-scaleway.yml`

Dung cho **FE3H va game can Metal 4**.

### Buoc 1: Tao Scaleway server

```bash
export SCW_ACCESS_KEY=SCWAG4XSJ9Q26HJKDDZE
export SCW_SECRET_KEY=f019d4e0-1be1-4c6b-8f79-b68d73589f3f
export SCW_DEFAULT_ORGANIZATION_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7
export SCW_DEFAULT_PROJECT_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7

# Tao server M4-SP voi macOS Golden Gates 27 + Xcode 27
scw apple-silicon server create \
  type=M4-SP \
  zone=fr-par-1 \
  os=91791d27-b0fe-42bc-b845-8ea96154932c \
  name=nxnative-build

# Lay IP va trang thai
scw apple-silicon server get <SERVER_ID> zone=fr-par-1 | grep -E "IP|Status|DeletableAt"
```

**Luu y:**
- OS ID `91791d27-b0fe-42bc-b845-8ea96154932c` = macOS Golden Gates 27 (co Xcode 27 san)
- Minimum lease = **1 ngay** (da bi tinh tien du xoa som hon)
- Thoi gian boot: 60-90 phut — **Khong tao lai server**, cho tiep. Status tu chuyen ve `ready`.
- SSH user: `m1`
- Sudo password: lay tu Scaleway console (tab Credentials khi click vao server)

### Buoc 2: Them SSH key

```bash
# Tao key
ssh-keygen -t ed25519 -C "nxnative" -f ~/.ssh/scaleway_nxnative

# Them public key vao Scaleway console -> SSH Keys
# (paste noi dung ~/.ssh/scaleway_nxnative.pub)
```

### Buoc 3: Setup runner tren server

```bash
ssh -i ~/.ssh/scaleway_nxnative -o StrictHostKeyChecking=no m1@<SERVER_IP>

# Tren server, chay setup script:
GH_TOKEN="<github_pat_voi_repo_write>"
bash <(curl -fsSL https://raw.githubusercontent.com/tungtt2589/nxnative-create-game-iphone/main/.github/scripts/setup_runner.sh) \
  "$GH_TOKEN" \
  "tungtt2589/nxnative-create-game-iphone" \
  "scaleway-m4"
```

Script nay se:
- Install Homebrew packages (xcodegen, zstd, glslang, unar, rclone)
- Install Python 3.12 + deps (lz4, capstone, fonttools, nsz, zbic, gdown, backports.zstd)
- Install .NET 10
- Dang ky runner voi labels `scaleway-m4,xcode-27-baremetal`
- Start runner o background

Kiem tra runner online: GitHub -> repo -> Settings -> Actions -> Runners

### Buoc 4: Trigger build

```
GitHub -> Actions -> "Build IPA (Scaleway M4 Bare-Metal)" -> Run workflow
game_name: FE3H
```

Thoi gian build: ~15-20 phut.

---

## Download artifacts ve Mac local

### Cach nhanh: Download qua Scaleway server (relay)

Scaleway EU download artifact ~10 MB/s, roi SCP ve Vietnam ~450 KB/s.

```bash
# SSH vao server
ssh -i ~/.ssh/scaleway_nxnative m1@<SERVER_IP>

# Tren server: tim RUN_ID
export PATH=/opt/homebrew/bin:$PATH
gh run list --repo tungtt2589/nxnative-create-game-iphone --workflow build-ipa-scaleway.yml --limit 5

# Download artifact tren server
mkdir -p ~/downloads/<game_name>
cd ~/downloads/<game_name>
gh run download <RUN_ID> -n <game_name>-ipa-<run_number> --repo tungtt2589/nxnative-create-game-iphone
gh run download <RUN_ID> -n <game_name>-romfs-<run_number> --repo tungtt2589/nxnative-create-game-iphone
```

```bash
# Tu Mac local: rsync ve (ho tro resume neu bi ngat)
mkdir -p ~/Downloads/<game_name>
rsync -av --partial --progress \
  -e "ssh -i ~/.ssh/scaleway_nxnative -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=10" \
  "m1@<SERVER_IP>:/Users/m1/downloads/<game_name>/<artifact_folder>/Game.ipa" \
  ~/Downloads/<game_name>/Game.ipa

rsync -av --partial --progress \
  -e "ssh -i ~/.ssh/scaleway_nxnative -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=10" \
  "m1@<SERVER_IP>:/Users/m1/downloads/<game_name>/<romfs_folder>/RomFS.img" \
  ~/Downloads/<game_name>/RomFS.img
```

**Dung rsync thay SCP** vi rsync co `--partial` (resume neu bi drop connection).

---

## Cai game len iPhone

**Thiet bi:** iPhone 16 Pro Max (A18 Pro, iOS 26)
**Tool:** Sideloadly (cai) + AltStore (quan ly refresh 7 ngay)

### Buoc 1: Cai IPA

1. Mo **Sideloadly** tren Mac
2. Cam iPhone qua USB
3. Keo file `.ipa` vao Sideloadly -> nhap Apple ID -> Start
4. Cho cai xong

> **Tai sao dung Sideloadly thay AltStore?**
> AltStore crash khi install IPA lon (>500MB) tren Mac. Sideloadly xu ly tot hon.
>
> **Sau khi Sideloadly install xong**, mo AltStore -> My Apps -> app tu xuat hien (cung Apple ID) -> AltStore quan ly tu refresh moi 7 ngay.

### Buoc 2: Copy RomFS (chi cho ROMFS=separate builds)

Build `ROMFS=separate` co IPA nho + file `RomFS.img` rieng. **Game crash ngay neu thieu RomFS.**

1. Cam iPhone qua USB
2. Mo **Finder** -> chon iPhone o sidebar
3. Tab **Files** -> tim app **DmIOS**
4. Vao thu muc **Documents**
5. Keo tha `RomFS.img` vao do
6. Cho copy xong
7. Mo game

> Mo app 1 lan dau (du crash) truoc khi copy RomFS, de app tao thu muc Documents.

### Refresh moi 7 ngay

AltStore tu refresh neu Mac + iPhone cung WiFi. Neu het han:
- Mo AltStore -> My Apps -> Refresh All
- Hoac Sideloadly install lai IPA

---

## Quan ly Scaleway server

Script: `.github/scripts/scaleway_manage.sh`

```bash
# Check status
bash .github/scripts/scaleway_manage.sh status

# SSH vao server
bash .github/scripts/scaleway_manage.sh ssh

# Cho server ready (sau khi tao moi, lap lai moi 30s)
bash .github/scripts/scaleway_manage.sh wait

# Xoa server (chi sau khi game ok tren iPhone!)
bash .github/scripts/scaleway_manage.sh delete
```

### Checklist truoc khi xoa server
1. Build xong, IPA + RomFS artifact uploaded
2. Download IPA + RomFS ve local Mac
3. Cai IPA len iPhone qua Sideloadly
4. Copy RomFS.img qua Finder -> iPhone -> DmIOS -> Documents
5. Mo game tren iPhone, confirm chay duoc
6. `bash .github/scripts/scaleway_manage.sh delete`

---

## Games da build thanh cong

| Game | IPA | RomFS | Flags | Notes |
|------|-----|-------|-------|-------|
| Unicorn Overlords | 3.2 GB (bundled) | khong co | — | ROMFS=bundle |
| FF Tactics | nho | artifact | — | ROMFS=separate |
| Tactics Ogre | nho | artifact | — | ROMFS=separate |
| Octopath Traveler 1 | 156 MB | 3.5 GB | `--provisional` | ROMFS=separate |
| Octopath Traveler 2 | 526 MB | 12 GB | `--provisional` | ROMFS=separate |
| **FE3H** | **1.1 GB** | **12 GB** | `--provisional --allow-other-metal` | **Can Scaleway (Metal 4)** |

**Trang thai hien tai (2026-11-06):** Tat ca 6 game da build + download ve Mac local. Scaleway server da xoa.

---

## Troubleshooting va Lessons Learned

### "Metal compiler version mismatch"
Them env var `DM_ALLOW_OTHER_METAL: "1"` vao step Verify Metal. Xay ra khi Xcode 27.0 (32023.921) vs tested 27.2 (32023.922).

### "shader profile mismatch" / DATA1.bin index X vs Y
Them flag `--provisional` vao lenh build. Flag nay tao lai shader profile tu du lieu game. IPA se lon hon (~1 GB).

### Python 3.9 too old
macOS ship Python 3.9, nxnative can 3.12:
```bash
brew install python@3.12
echo "$(brew --prefix python@3.12)/bin" >> "$GITHUB_PATH"
pip3.12 install --break-system-packages lz4 capstone fonttools nsz zbic gdown backports.zstd
```

### pip "externally managed environment" (PEP 668)
Them `--break-system-packages` vao pip install.

### Homebrew not found tren self-hosted runner
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
echo "/opt/homebrew/bin" >> "$GITHUB_PATH"
```

### Artifact contamination giua cac build
Self-hosted runner khong tu clean workspace. Them cleanup step dau workflow:
```bash
rm -rf "$HOME/Games" "$HOME/gdrive_raw" "$HOME/keys" "$HOME/_work/_tool" || true
find "$HOME" -name "*.ipa" -delete 2>/dev/null || true
find "$HOME" -name "RomFS.img" -o -name "romfs.img" 2>/dev/null -delete || true
```

### Server bi "unknown_status" / "reinstalling" lau
macOS Golden Gates 27 mat 60-90 phut de provision. **Khong tao lai**, cho tiep.

### SCP bi drop giua chung (exit 255)
Dung `rsync --partial` thay SCP. Tu resume tu byte da download.

### AltStore crash khi cai IPA lon
Dung Sideloadly de cai, AltStore tu nhan vao My Apps sau.

### App khong hien trong AltStore du cung Apple ID
Binh thuong. App cai bang Sideloadly van duoc auto-refresh boi AltStore trong My Apps.

### "Device has reached maximum number of installed apps using a free developer profile"
iOS gioi han tong cong **3 app sideload tren 1 thiet bi** (tinh tat ca Apple ID mien phi cong lai). Dung them Apple ID khac khong giup duoc.
- Giai phap A: Xoa 1 app cu de lay slot
- Giai phap B: Apple Developer Account ($99/nam) — unlimited app, khong can resign 7 ngay

### Auto-delete script bi stuck neu Mac ngu
`sleep` trong bash bi tam dung khi Mac ngu. Neu can xoa server tu dong, xoa thu cong khi den gio:
```bash
export SCW_ACCESS_KEY=SCWAG4XSJ9Q26HJKDDZE SCW_SECRET_KEY=f019d4e0-1be1-4c6b-8f79-b68d73589f3f \
  SCW_DEFAULT_ORGANIZATION_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7 \
  SCW_DEFAULT_PROJECT_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7
scw apple-silicon server delete <SERVER_ID> zone=fr-par-1
```

---

## Thong tin Scaleway

```bash
export SCW_ACCESS_KEY=SCWAG4XSJ9Q26HJKDDZE
export SCW_SECRET_KEY=f019d4e0-1be1-4c6b-8f79-b68d73589f3f
export SCW_DEFAULT_ORGANIZATION_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7
export SCW_DEFAULT_PROJECT_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7

# macOS Golden Gates 27 OS ID (co Xcode 27 san)
OS_ID=91791d27-b0fe-42bc-b845-8ea96154932c

# Tao server moi
scw apple-silicon server create type=M4-SP zone=fr-par-1 os=$OS_ID name=nxnative-build

# Check status
scw apple-silicon server get <ID> zone=fr-par-1
```

Chi phi: ~EU0.30-0.40/hr, minimum 1 ngay (~EU7-10/lan build can Scaleway).

---

## rclone / Google Drive

```bash
# Service Account
# SA email: nxnative-gdrive@my-project-1497279467887.iam.gserviceaccount.com
# JSON luu trong GitHub Secret: GDRIVE_SA_JSON

# Config rclone thu cong
mkdir -p ~/.config/rclone
printf '[gdrive]\ntype = drive\nscope = drive.readonly\nservice_account_file = /path/to/sa.json\nroot_folder_id = 1EwdiG20Beo2jbPrwmYlp7e8sK9IpMUTs\n' \
  > ~/.config/rclone/rclone.conf

# Download game
rclone copy "gdrive:Games/FE3H" ~/Games/FE3H --drive-acknowledge-abuse --transfers 4
```

---

## Files trong repo

```
.github/
  workflows/
    build-ipa.yml              # Build tren GitHub hosted (khong can Metal 4)
    build-ipa-scaleway.yml     # Build tren Scaleway M4 (can Metal 4)
  scripts/
    setup_runner.sh            # Setup runner + deps tren Scaleway Mac
    scaleway_manage.sh         # Manage server: status/ssh/delete/wait
    retry_gdrive.py            # Retry helper cho rclone download
SCALEWAY.md                    # Quick reference Scaleway
README.md                      # File nay
```
