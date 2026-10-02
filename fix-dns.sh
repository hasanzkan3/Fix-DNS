#!/usr/bin/env bash

set -e

# Kullanıcı Kontrolü
if [ "$EUID" -ne 0 ]; then
  echo "[-] Lütfen bu betiği root yetkisiyle (sudo) ya da root kullanıcısı olarak çalıştırınız."
  exit 1
fi

echo "[+] systemd-resolved yapılandırılıyor..."

# /etc/systemd/resolved.conf dosyasını oluştur veya güncelle
bash -c 'cat <<EOF | sudo tee /etc/systemd/resolved.conf >/dev/null
[Resolve]
DNS=1.1.1.1 1.0.0.1
FalbackDNS=8.8.8.8 8.8.4.4
Domains=~.
DNSoverTLS=no
DNSSEC=no
EOF'

# NetworkManager kullanılıyorsa çakışmayı önlemek için entegrasyon dosyası ekle
if [ -d /etc/NetworkManager/conf.d ]; then
  echo "[+] NetworkManager entegrasyonu ayarlanıyor..."

  bash -c 'cat <<EOF | sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null
  [main]
  dns=systemd-resolved
  EOF'
fi

# /etc/resolv.conf sembolik bağını güncelle
echo "[+] /etc/resolv.conf sembolik bağı (symlink) güncelleniyor..."
rm -f /etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Servisleri yeniden başlat ve önbelleği sıfırla
echo "[+] Servisler yeniden başlatılıyor..."
systemctl enable --now systemd-resolved
systemctl restart systemd-resolved

if systemctl is-active --quiet NetworkManager; then
  systemctl restart NetworkManager
fi

resolvectl flush-caches

echo "[✓] Yapılandırma tamamlandı! Doğrulama yapılıyor..."
sleep 2

# Test
if ping -c 2 -W 3 archlinux.org >/dev/null 2>&1; then
  echo "[✓] Başarılı! İnternet ve DNS çözümlemesi aktif."
else
  echo "[!] Ping başarısız oldu! 'resolvectl status' çıktısını kontrol edin"
fi
