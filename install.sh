#!/bin/bash
echo "--------------------------- Konfigurasi Server ---------------------------"
echo "Jumlah Core CPU: " $(nproc --all) "CORE"
echo -n "Kapasitas RAM: " && free -h | awk '/Mem/ {sub(/Gi/, " GB", $2); print $2}'
echo "Kapasitas Penyimpanan:" $(df -B 1G --total | awk '/total/ {print $2}' | tail -n 1) "GB"
echo "------------------------------------------------------------------------"

echo "--------------------------- BASH SHELL TITAN ---------------------------"
# Ambil nilai hash dari terminal
echo "Masukkan kode Hash Anda (Identity code): "
read hash_value

# Periksa jika hash_value adalah string kosong (pengguna hanya menekan Enter) maka hentikan program
if [ -z "$hash_value" ]; then
    echo "Tidak ada nilai hash yang dimasukkan. Menghentikan program."
    exit 1
fi


service_content="
[Unit]
Description=Titan Node
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
ExecStart=/usr/local/titan/titan-edge daemon start
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
"

sudo apt-get update
sudo apt-get install -y nano

wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.18/titan_v0.1.18_linux_amd64.tar.gz

sudo tar -xf titan_v0.1.18_linux_amd64.tar.gz -C /usr/local

sudo mv /usr/local/titan_v0.1.18_linux_amd64 /usr/local/titan

rm titan_v0.1.18_linux_amd64.tar.gz

if [ ! -f ~/.bash_profile ]; then
    echo 'export PATH=$PATH:/usr/local/titan' >> ~/.bash_profile
    source ~/.bash_profile
elif ! grep -q '/usr/local/titan' ~/.bash_profile; then
    echo 'export PATH=$PATH:/usr/local/titan' >> ~/.bash_profile
    source ~/.bash_profile
fi

# Jalankan titan-edge daemon di latar belakang
(titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!

echo "PID dari titan-edge daemon: $daemon_pid"

# Tunggu 10 detik untuk memastikan daemon telah berhasil dimulai
sleep 15

# Jalankan titan-edge bind di latar belakang
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!

echo "PID dari titan-edge bind: $bind_pid"

# Tunggu proses bind selesai
wait $bind_pid

sleep 15

# Lakukan pengaturan lainnya

config_file="/root/.titanedge/config.toml"
if [ -f "$config_file" ]; then
    sed -i "s/#StorageGB = 2/StorageGB = 21/" "$config_file"
    echo "Telah mengubah kapasitas penyimpanan database menjadi 21 GB."
else
    echo "Kesalahan: File konfigurasi $config_file tidak ada."
fi

echo "$service_content" | sudo tee /etc/systemd/system/titand.service > /dev/null

# Hentikan proses yang terkait dengan titan-edge
pkill titan-edge

# Perbarui systemd
sudo systemctl daemon-reload

# Aktifkan dan mulai titand.service
sudo systemctl enable titand.service
sudo systemctl start titand.service

sleep 8
# Tampilkan informasi dan konfigurasi dari titan-edge
sudo systemctl status titand.service && titan-edge config show && titan-edge info
