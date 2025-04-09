# kextdl

A script to download kexts from GitHub repos

# Usage

`cd <my repo>`
`/path/to/kextdl.sh < ./kext.list`

# kext.list

### This file is formatted like:

```
developer/repo kextName-{VERSION}-{VARIANT} (mainKext, kextModule1, kextModule2)
```

### Example (to download VirtualSMC & its modules):

```
acidanthera/VirtualSMC  VirtualSMC-{VERSION}-{VARIANT}  (VirtualSMC, SMCBatteryManager, SMCProcessor, SMCSuperIO)
```

See [example_kext.list](https://github.com/h4dynn/kextdl/blob/main/example_kext.list)
for an example of the list
