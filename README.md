# FOG Snapin Scripts

**Notes:**
- The environment I developed these for only use HP assets so these have only been tested on the various HP laptops, desktops, and workstations at my disposal.
- These are meant to be deployed within a snapin pack.
  - e.g. `sp170175.exe` and `Update-BIOS.ps1` will be bundled within a single `.zip` archive and uploaded as a snapin pack.
  - You should change the parameters at the top to fit your environment.

**BIOS Configuration:**
- `Configure-BIOS.ps1` is meant to be used on assets that have the `HP BIOS Configuration Utility` installed or bundled with it inside a snapin pack.
  - Feel free to adjust the configurations within to suit your environment.
  - I'd also recommend to output a `config.txt` from a test asset to see what you'd like to actually configure.
  - I've developed an `Import-BIOS.ps1` PS script that will just take the output of a `config.txt` and essentially import it but it needs to be sanitized before being published to the public.
 
**To-do/Future Plans:**
- Upload `Import-BIOS.ps1`.
- Create better documentation with examples.
