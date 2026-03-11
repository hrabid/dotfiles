git clone https://github.com/sarim/ibus-avro.git
cd ibus-avro

sudo dnf install automake -y
sudo dnf install ibus-devel ibus-libs -y

aclocal && autoconf && automake --add-missing
./configure --prefix=/usr
sudo make install
