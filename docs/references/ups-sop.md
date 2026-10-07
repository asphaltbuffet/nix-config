# UPS SOP (bunyip)

bunyip's CyberPower CP1500AVR is on USB (`0764:0501`). NUT runs standalone in
`nixos/common/ups.nix`; the device is defined in `nixos/hosts/bunyip/configuration.nix`.
bunyip is the UPS's only load. The network gear and NAS are on a separate,
unmonitored UPS, so this is the house's only Mains failure sensor.

## What happens in an outage

| Time | Event |
|---|---|
| 0 s | UPS on battery; auto-deploy / restic runs are skipped (`/var/lib/ups-deferred/<unit>`) |
| 30 s | Alert "on battery: mains failure" (priority 4) |
| runtime < 300 s or charge < 20 % | Alert "low battery: shutting down" (priority 5), `shutdown now`, then killpower cuts outlets after 60 s |
| mains back (no shutdown) | after 30 s stable: Resolution "mains restored", deferred jobs start |
| mains back (after shutdown) | UPS restores outlets after 120 s, BIOS powers on, 2 min after boot (`ups-boot-check`): Resolution "mains restored after shutdown", deferred jobs start |

## Alerts

All go through `alert`; fields are numbers or closed-set values (ADR-0018).

| Alert | Priority | Sent |
|---|---|---|
| on battery: mains failure | 4 | Once per outage, 30 s after going on battery. A power flap inside the 30 s mains-stable window does not send a second one. |
| mains restored (Resolution) | 3 | 30 s after mains is stable, and only if an on-battery Alert actually went out (flag in `/var/lib/ups-events`, survives shutdown) |
| low battery: shutting down | 5 | Once (LOWBATT, FSD and SHUTDOWN all fire on the way down). LOWBATT only alerts while on battery (`OB`): with `ignorelb` the driver can set LB on mains while recharging. |
| UPS communication lost | 3 | Once per comm outage (`NOCOMM`, link down 300 s). A `COMMOK` event silently re-arms it (flag `/run/upssched/nocomm-alerted`). `COMMBAD` never alerts: it fires on every upsd/driver restart, i.e. every deploy. |
| UPS battery needs replacing | 3 | On `REPLBATT`; NUT repeats it every 12 h |
| UPS self-test did not pass | 3 | After `ups-selftest` if the result is not "Done and passed". The test is skipped (no Alert) unless on mains (`OL`, not `OB`) with charge >= 95 %. |

## Prerequisite (one-time, at the console)

BIOS → *Restore on AC power loss* = **Power On**. Already set on bunyip
(2026-10-06). Without it bunyip stays off after killpower.

## Everyday commands

```bash
upsc cyberpower@localhost                 # all variables
upsc cyberpower@localhost ups.status      # OL / OB / LB ...
sudo upscmd -l cyberpower@localhost       # supported instant commands
sudo systemctl start ups-selftest         # quick battery test now
journalctl -u upsmon -u upsd -u upsdrv -b # NUT logs
ls /var/lib/ups-deferred                  # jobs waiting for mains
cat /var/lib/node-exporter-textfile/ups.prom  # last self-test result
```

## Outage drill (do after changes to ups.nix)

1. Pull the UPS plug for **60 s**. Expect the on-battery Alert at about 30 s.
2. While still unplugged, run `sudo systemctl start restic-backup-bunyip`. Expect
   "on battery … deferring restic-backup-bunyip" in its journal, no failure
   Alert, and a marker in `/var/lib/ups-deferred/`.
3. Reconnect. Expect the "mains restored" Resolution about 30 s later, and any
   marker gone with the job started (`journalctl -u ups-catch-up`).
4. While `sudo systemctl start ups-selftest` runs (on mains), watch
   `upsc cyberpower@localhost ups.status`. If it shows `OB`, report it: a test
   that reports OB would trip deferral and the "Last mains failure" stat
   (follow-up needed).

Testing the low-battery shutdown is optional and disruptive. Run
`sudo upsmon -c fsd` to force the shutdown path. bunyip should halt, the
outlets should cut about 60 s later, and bunyip should boot by itself because
mains is still present. Expect the priority-5 "low battery: shutting down"
Alert (via SHUTDOWN/FSD). No "mains restored" Resolution follows: `fsd` runs on
mains, so no on-battery Alert was sent.

**Warning:** many CyberPower units ignore the shutdown command while on mains.
If the outlets never cut, bunyip stays powered off until someone presses the
power button. Only run this drill when someone is physically present.

If the outlets never cut, check `journalctl -b -1 -u ups-killpower` after
powering bunyip back on, and try different `offdelay`/`ondelay`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `NOCOMM` Alert / all dashboard panels "No data" | USB link or driver down | `systemctl status upsdrv`; replug USB; `sudo systemctl restart upsdrv upsd upsmon` |
| upsd refuses `upsmon` login | `nut-upsmon.age` empty or changed without restart | `sudo wc -c /run/agenix/nut-upsmon` (expect 49); see deploy-stale-cache SOP for 0-byte secrets |
| Beeper still sounds | firmware ignored `beeper.disable` | `systemctl status ups-beeper-off`; check `upscmd -l` for `beeper.mute` |
| Self-test "Never run" | timer only fires on the 1st | `sudo systemctl start ups-selftest` |
| Battery "needs replacing" Alert | `REPLBATT` from the UPS's own test | Replace the battery (RB1290X2; confirm on the unit's label); run the self-test afterwards |
| Deferred job never ran after mains returned | `ups-catch-up.path` / marker stuck | `ls /var/lib/ups-deferred /run/upssched`; `sudo systemctl start ups-catch-up` |
