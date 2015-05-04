# pk2w.sh

# burn a pic
# 20121120 -tm
DEV="pic16f716"

pk2cmd -I -B/usr/share/pk2 -P${DEV} -M -F${1}
