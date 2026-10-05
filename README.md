# Canon SELPHY CP1500 — "pending" print job troubleshooting

Main reference: https://gist.github.com/benjaminkott/e293147dd0ea9e6fa7f1194567a5d1ba

## Symptom

Print jobs sent to `Canon_SELPHY_CP1500_USB` sit at "pending" and never print.

## Root cause

Despite the `_USB` name, this queue is not a raw USB queue — it's an
`implicitclass://` queue backed by **ipp-usb**, a service that bridges the
USB-connected, AirPrint-capable Selphy into a local IPP endpoint and
advertises it over Bonjour/mDNS as:

```
ipp://Canon%20SELPHY%20CP1500%20(USB)._ipp._tcp.local/
```

`cups-browsed` is responsible for keeping the `implicitclass` queue pointed
at that resolved mDNS address. When cups-browsed isn't running (or falls out
of sync with avahi, e.g. after the printer sleeps/wakes), the queue has no
destination host to send jobs to, the backend fails, and CUPS auto-disables
the printer.

Confirmed from `/var/log/cups/error_log`:

```
E [...] [Job 4] No destination host name supplied by cups-browsed for printer "Canon_SELPHY_CP1500_USB", is cups-browsed running?
W [...] [Job 4] Backend implicitclass returned status 4 (stop printer)
```

## Diagnosis steps

1. Check whether the queue is disabled:

   ```
   lpstat -p -d
   ```

2. Check the queue's device URI — confirms it's `implicitclass`, not a raw
   `usb://` URI:

   ```
   lpstat -v Canon_SELPHY_CP1500_USB
   ```

3. Check the tail of the CUPS error log for the actual failure reason:

   ```
   tail -50 /var/log/cups/error_log
   # or: journalctl -u cups -n 100 --no-pager
   ```

4. Confirm the printer is discoverable over mDNS via ipp-usb:

   ```
   lpinfo -v | grep -i selphy
   ```

   Expect: `network ipp://Canon%20SELPHY%20CP1500%20(USB)._ipp._tcp.local/`

5. Check the health of the services in the discovery chain:
   ```
   systemctl status cups-browsed
   systemctl status ipp-usb
   systemctl status avahi-daemon
   ```

## Fix

If `cups-browsed` is inactive/dead/failed:

```
sudo systemctl enable --now cups-browsed
```

Otherwise, restart the whole discovery chain in order (fixes stale mDNS
cache, common after the printer sleeps/wakes):

```
sudo systemctl restart avahi-daemon
sudo systemctl restart ipp-usb
sudo systemctl restart cups-browsed
sudo systemctl restart cups
```

Re-enable the queue and test:

```
sudo cupsenable Canon_SELPHY_CP1500_USB
sudo cupsaccept Canon_SELPHY_CP1500_USB
lp -d Canon_SELPHY_CP1500_USB /workspace/hand.JPG
```

## Notes / red herrings seen in the log

- `[cups-driverd] Bad driver information file ".../Utax/..."` — unrelated
  broken OpenPrinting PPD entries for a different (Utax) driver set. Ignore.
- `CreateProfile failed: ... AlreadyExists ...` — ColorManager warnings about
  already-registered ICC profiles for this printer. Harmless, not the cause.
