# pk2e.sh
# 20121120 -tm
# erase a PK2 device
DEV="pic16f716"

pk2cmd -I -B/usr/share/pk2  -P${DEV} -E
