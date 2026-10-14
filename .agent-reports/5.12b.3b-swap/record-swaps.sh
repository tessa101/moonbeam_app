#!/bin/zsh
# Records both location swaps on the iPhone 17 simulator, through Settings as a user would:
# compass on -> Settings, revoke -> back (on to off) -> Settings, grant -> back (off to on).
# Usage: record-swaps.sh out.mov   (needs CoreSimulator outside the agent sandbox)
U=C86BA1FD-2B5E-4D20-A847-19A4246ED1F7
B=com.t-alien.moonbeam-app
OUT=$1
xcrun simctl terminate $U $B 2>/dev/null
xcrun simctl location $U set 33.6846,-117.8265
xcrun simctl privacy $U grant location $B
xcrun simctl launch $U $B -onboardingCompleted YES >/dev/null
sleep 8
xcrun simctl io $U recordVideo --codec=h264 --force $OUT > /tmp/rec.log 2>&1 &
REC=$!
sleep 2
xcrun simctl launch $U com.apple.Preferences >/dev/null; sleep 2
xcrun simctl privacy $U revoke location $B; sleep 1
echo "on->off: return at $(date +%T)"
xcrun simctl launch $U $B -onboardingCompleted YES >/dev/null; sleep 5
xcrun simctl launch $U com.apple.Preferences >/dev/null; sleep 2
xcrun simctl privacy $U grant location $B; sleep 1
echo "off->on: return at $(date +%T)"
xcrun simctl launch $U $B -onboardingCompleted YES >/dev/null; sleep 6
kill -INT $REC; wait $REC
tail -1 /tmp/rec.log
