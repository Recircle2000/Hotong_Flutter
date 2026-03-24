#!/bin/sh

set -e

cd $CI_PRIMARY_REPOSITORY_PATH

echo "===== Environment Info ====="
uname -a || true

echo "===== DNS Info ====="
scutil --dns || true

echo "===== Network Check (Naver Repo) ====="
URL="https://repository.map.naver.com/archive/pod/NMapsGeometry/1.0.2/NMapsGeometry.zip"

for i in 1 2 3 4 5; do
  echo "Attempt $i: checking DNS + HTTP"

  if nslookup repository.map.naver.com && curl -I --connect-timeout 15 "$URL"; then
    echo "✅ Naver repository reachable"
    break
  fi

  echo "❌ Failed attempt $i, retrying..."
  sleep 5
done

echo "===== Install Flutter ====="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios

echo "===== Flutter Pub Get ====="
flutter pub get

echo "===== Install CocoaPods ====="
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods || true

echo "===== Clean CocoaPods Cache ====="
rm -rf ios/Pods ios/Podfile.lock || true
rm -rf ~/Library/Caches/CocoaPods || true
pod cache clean --all || true

echo "===== Pod Install ====="
cd ios

# 네트워크 문제 대비해서 pod install도 재시도
for i in 1 2 3; do
  echo "pod install attempt $i"

  if pod install --repo-update --verbose; then
    echo "✅ pod install success"
    break
  fi

  echo "❌ pod install failed, retrying..."
  sleep 5
done

exit 0