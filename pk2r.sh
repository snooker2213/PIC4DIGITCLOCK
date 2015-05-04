# pk2r.sh
# 20121120 -tm
# read a PK2 device
DEV="pic16f716"

pk2cmd -B/usr/share/pk2 -I -P${DEV} -GF${1}
