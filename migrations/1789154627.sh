echo "Ensure zram-generator is installed for configured zram swap"

# Apple Silicon images do not ship the omarchy-settings zram drop-ins the
# overlay's oomd skip is written against. Install the generator and start the
# device so those machines are not left without swap. x86 already gets zram
# from the settings package.
omarchy-hw-apple-silicon || exit 0

if omarchy-pkg-missing zram-generator; then
  omarchy-pkg-add zram-generator
fi

zram_conf="${OMARCHY_ZRAM_CONF:-/etc/systemd/zram-generator.conf}"
zram_dropin_usr="${OMARCHY_ZRAM_DROPIN_USR:-/usr/lib/systemd/zram-generator.conf.d/90-omarchy.conf}"
zram_dropin_etc="${OMARCHY_ZRAM_DROPIN_ETC:-/etc/systemd/zram-generator.conf.d/90-omarchy.conf}"
zram_shipped="${OMARCHY_ZRAM_SHIPPED:-$OMARCHY_PATH/default/systemd/zram-generator.conf.d/90-omarchy.conf}"

# aarch64 omarchy-settings does not ship the vendor drop-in. Copy the repo
# template into /etc when nothing configures zram, or the generator has no
# device to start.
if [[ ! -f $zram_conf && ! -f $zram_dropin_usr && ! -f $zram_dropin_etc && -f $zram_shipped ]]; then
  sudo mkdir -p "$(dirname "$zram_dropin_etc")"
  sudo cp "$zram_shipped" "$zram_dropin_etc"
fi

if systemctl is-active --quiet dev-zram0.swap; then
  exit 0
fi

# Installing the package after boot does not run the generated unit until the
# manager reloads. Start it now so upgraded machines get the same zram device a
# fresh install gets on its next boot. With no config the start fails; do not
# block later migrations.
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service || true
