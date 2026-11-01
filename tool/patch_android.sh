#!/usr/bin/env bash
# `flutter create .` এর পর একবার চালান: HTTP (https নয়) সার্ভারে সংযোগের অনুমতি + INTERNET permission
set -e
M=android/app/src/main/AndroidManifest.xml
[ -f "$M" ] || { echo "আগে 'flutter create --project-name live_mcq_app .' চালান"; exit 1; }
grep -q 'usesCleartextTraffic' "$M" || sed -i 's/<application/<application android:usesCleartextTraffic="true"/' "$M"
grep -q 'android.permission.INTERNET' "$M" || sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' "$M"
echo "AndroidManifest ঠিক করা হয়েছে"
