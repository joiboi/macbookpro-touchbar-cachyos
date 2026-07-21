## Sound Fix
```bash
sudo pacman -S --needed base-devel linux-headers git dkms
```

```bash
git clone https://github.com/davidjo/snd_hda_macbookpro
cd snd_hda_macbookpro
# Use the -i flag to install via DKMS
sudo ./install.cirrus.driver.sh -i
