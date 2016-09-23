echo "Getting and building memaslap"

cd mem

# Use exactly this version of libmemcached!
wget https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz
tar xvf libmemcached-1.0.18.tar.gz
cd libmemcached-1.0.18
export LDFLAGS=-lpthread

echo "You need to change some files manually according to:"
echo "http://stackoverflow.com/questions/27004144/how-can-i-install-libmemcached-for-mac-os-x-yosemite-10-10-in-order-to-install-t"
read -n1 -r -p "Press any key when done. " key

./configure --enable-memaslap && make clients/memaslap

cd ..