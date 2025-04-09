just execute phase0.sh

in phase0:
- user-openssl user is created
- user-openssl user is defined as sudo
- phase1 and phase2 executed

in phase1:
- rootCA directory created
- openssl config file created and modified

in phase2:
- CA / OCSP certificates created
- openssl ocsp responder created as a service (port 80)
