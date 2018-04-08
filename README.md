# macos-setup-helper
This tool quickly gathers system resource and health information on macOS. It can simplify the process onboarding / setup for Mac computers in an IT setting.

## Usage ##
Just run the script to generate a deivce report. Check `--help` for more options.

```
$ ./macos_setup_helper.sh
===============================================
DEVICE REPORT - Sun  8 Apr 2018 10:13:36 PDT
===============================================
Name: Prisms
Serial: D25KF0RM1234
MAC (WiFi): ec:35:86:00:12:34
Model: iMac (27-inch, Late 2012)
Year: 2012
CPU Speed: 3.4 GHz
CPU Type: Intel Core i7
CPU Full: 3.4 GHz Intel Core i7
RAM: 16 GB
Storage: 121.3 GB
macOS Version: 10.13.4+17E199
FileVault: On
===============================================
```

## Todo ##
* Move employee username feature to an addon (mostly useful for imaging)
* Move "prepare" steps (password policy and disk rename) to an addon
* Load addon files dynamically from addons folder 
* Load addon options into usage / help dynamically
* Generalize Snipe-IT addon custom field names (declare vars so they can be edited easily)
