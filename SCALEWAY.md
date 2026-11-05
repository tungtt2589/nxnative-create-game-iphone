# Scaleway Apple Silicon Setup

## Instance Info
- **Server ID**: a66aa052-802d-4c99-9ca6-d78365e693d8
- **IP**: 62.210.194.185
- **Zone**: fr-par-1
- **Type**: M4-SP (Apple M4, 10 cores, 16GB RAM, 512GB SSD)
- **OS**: macOS Golden Gates 27 + Xcode 27
- **SSH user**: m1
- **SSH key**: ~/.ssh/scaleway_nxnative
- **Cost**: ~€0.30-0.40/hr, minimum 1 day lease

## Scaleway Credentials
- Access Key: SCWAG4XSJ9Q26HJKDDZE
- Project/Org ID: e80a64ac-e120-4941-a0e6-1cce5ce8bac7
- Config stored at: ~/.config/scw/config.yaml

## Quick Commands

```bash
# Export env
export SCW_ACCESS_KEY=SCWAG4XSJ9Q26HJKDDZE
export SCW_SECRET_KEY=f019d4e0-1be1-4c6b-8f79-b68d73589f3f
export SCW_DEFAULT_ORGANIZATION_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7
export SCW_DEFAULT_PROJECT_ID=e80a64ac-e120-4941-a0e6-1cce5ce8bac7

# Check status
bash .github/scripts/scaleway_manage.sh status

# SSH into server
ssh -i ~/.ssh/scaleway_nxnative -o StrictHostKeyChecking=no m1@62.210.194.185

# Delete server (only after game installed on iPhone!)
bash .github/scripts/scaleway_manage.sh delete
```

## Setup Runner (run after SSH)

```bash
# On the Scaleway Mac:
GH_TOKEN="<your_github_pat>"
bash <(curl -fsSL https://raw.githubusercontent.com/tungtt2589/nxnative-create-game-iphone/main/.github/scripts/setup_runner.sh) \
  "$GH_TOKEN" \
  "tungtt2589/nxnative-create-game-iphone" \
  "scaleway-m4"
```

## Trigger Build

After runner is online, trigger `build-ipa-scaleway.yml` with:
- game_name: `FE3H`

## Why Scaleway for FE3H

- FE3H requires **Metal 4** GPU for GLSL shader capture
- GitHub `xcode-27` runner = VM (paravirtualized GPU, no Metal 4)
- GitHub `macos-latest` = bare-metal but only Xcode 26 (missing MTL4FXTemporalScaler)
- Scaleway M4-SP = **bare-metal Apple M4** (Metal 4) + **macOS 27 + Xcode 27** = works!

## Shutdown Checklist
1. Build succeeded — IPA + RomFS artifacts uploaded
2. Downloaded IPA + RomFS to local Mac
3. Installed IPA via AltStore on iPhone
4. Copied RomFS.img via Finder -> iPhone -> DmIOS -> Documents
5. Opened game on iPhone — confirmed working
6. Run: `bash .github/scripts/scaleway_manage.sh delete`
