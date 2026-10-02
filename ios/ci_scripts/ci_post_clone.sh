#!/bin/sh

set -e

cd $CI_PRIMARY_REPOSITORY_PATH

echo "===== Create .env ====="

mkdir -p assets

# 값은 Xcode Cloud 워크플로의 환경변수에서 온다.
# SUPABASE_* 가 비면 택시팟 학교 이메일 인증을 쓸 수 없다.
cat > assets/.env <<EOF
NAVER_MAP_CLIENT_ID=$NAVER_MAP_CLIENT_ID
BASE_URL=$BASE_URL
SUPABASE_PROJECT_URL=$SUPABASE_PROJECT_URL
SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY
PLAY_STORE_ID=$PLAY_STORE_ID
APPLE_APP_ID=$APPLE_APP_ID
APP_AUTH_TEST_EMAILS=$APP_AUTH_TEST_EMAILS
EOF

echo "✅ assets/.env created"

# 빠진 값은 이름만 알려준다(값은 로그에 남기지 않는다).
[ -n "$NAVER_MAP_CLIENT_ID" ] || echo "⚠️ NAVER_MAP_CLIENT_ID is not set in the Xcode Cloud environment"
[ -n "$BASE_URL" ] || echo "⚠️ BASE_URL is not set in the Xcode Cloud environment"
[ -n "$SUPABASE_PROJECT_URL" ] || echo "⚠️ SUPABASE_PROJECT_URL is not set in the Xcode Cloud environment"
[ -n "$SUPABASE_PUBLISHABLE_KEY" ] || echo "⚠️ SUPABASE_PUBLISHABLE_KEY is not set in the Xcode Cloud environment"

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
