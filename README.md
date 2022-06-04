# The Fail Safe Boot Project

The Fail Safe Boot Project provides an EFI Linux bootloader program and associated user utilities that monitor the number of attempts to boot a primary operating system.  If the number of attempts reaches a pre-defined limit, Fail Safe Boot will then attempt booting a secondary operating system.  Booting of this secondary operating system is attempted until the pre-defined boot count limit is reached, then Fail Safe Boot switches back to the primary operating system.  This cycling of primary and secondary operating system attempts continues until the system has a successful boot.

Note that Fail Safe Boot differs from traditional 'dual boot' methods in that Fail Safe Boot acts at the EFI firmware level.  Traditional 'dual boot' methods act at the bootloader level.  With Fail Safe Boot the bootloader is switched.  Traditional 'dual boot' methods have a single bootloader that switches the operating system.

Fail Safe Boot:

```
 EFI firmware -+-> Primary Bootloader   --> Primary OS
               +-> Secondary Bootloader --> Secondary OS
```
Traditional dual boot:

```
 EFI firmware --> Bootloader -+-> Primary OS
                              +-> Secondary OS
```

The motivation for such a boot method is that if the system has only a single bootloader, and there is a problem with that single bootloader, the system can become unbootable or impossible to upgrade without a complete 're-install'.  With Fail Safe Boot the system will have two completely independent operating system installations; so two independent EFI boot partitions, two independent bootloaders, two independent system partitions, etc.

The system generally boots to the primary operating system.  When an upgrade is done the secondary operating system installation is upgraded.  No modification to the primary is needed, and so the upgrade will have no effect on the stability of the primary.  The secondary operating system is then set to be the primary and the old primary becomes the 'known good' secondary.  If the newly installed system cannot boot, the 'known good' secondary can be booted manually through the firmware boot menu, or will be booted automatically after the Fail Safe Boot counter reaches the pre-defined limit.  Recovery of the 'bad' system can then be done from the 'good' system.

# The FSB Utilities

## fsb-util

Utility for managing Fail Safe Boot variables.

### Usage

```
fsb-util.sh - Utility for managing fail safe boot.
Usage: fsb-util.sh [flags]
Option flags:
  -c --fsb-counter - Set fsb-counter value. Default=''.
  -m --fsb-map     - Set fsb-map value. Default=''.
  -i --fsb-index   - Set fsb-index value. Default=''.
  -n --efi-next    - Set EFI BootNext value. Default=''.
  -p --print       - Print current variable values.
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
  -d --dry-run     - Dry run, don't modify variables.
Info:
  Fail Safe Boot fsb-util.sh
  Project Home: https://github.com/glevand/fail-safe-boot
```

## fsb-ack

Used to acknowledge a successful Fail Safe Boot.  Resets the Fail Safe Boot counter to zero.

### Usage

```
fsb-ack.sh - Acknowledge a successful fail safe boot.
Usage: fsb-ack.sh [flags]
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
Info:
  Fail Safe Boot fsb-ack.sh
  Project Home: https://github.com/glevand/fail-safe-boot
```

# License & Usage

All files in the [Fail Safe Boot Project](https://github.com/glevand/fail-safe-boot),
unless otherwise noted, are covered by an
[MIT Plus License](https://github.com/glevand/fail-safe-boot/blob/master/mit-plus-license.txt).
The text of the license describes what usage is allowed.
