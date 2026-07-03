# Huion KD100 (Keydial mini) — raw key codes

USB ID `256c:006d`. Kernel `hid_uclogic` binds but emits **zero evdev events**
for the 18 keys / dial (verified: 55s broad monitor over all input nodes caught
nothing). So the keys must be read from the **raw vendor HID stream** instead.

## Where to read

- **Keypad interface** = USB `:1.0` = hidraw for `…:1.0/` (here `/dev/hidraw4`,
  by-id `usb-256c_006d-hidraw`). Carries all keys + dial.
- `:1.1` (`/dev/hidraw5`, `usb-256c_006d-if01-hidraw`) is the Keyboard/Consumer
  interface — not used.
- Resolve at runtime, don't hardcode `hidrawN` (renumbers on replug).

## Report formats

Buttons (12 bytes): `f7 e0 01 01 <b4> <b5> <b6> 00 00 00 00 00`
Dial rotate:        `f9 f1 01 01 0f <dir> …`

Press sets the bit; release = all-zero (`f7 e0 01 01 00 00 00 …`).
19-bit mask, LSB-first: `mask = b4 | b5<<8 | b6<<16`, key number = bit + 1.

| Key        | Byte | Hex | Bit |
|------------|------|-----|-----|
| 1          | b4   | 01  | 0   |
| 2          | b4   | 02  | 1   |
| 3          | b4   | 04  | 2   |
| 4          | b4   | 08  | 3   |
| 5          | b4   | 10  | 4   |
| 6          | b4   | 20  | 5   |
| 7          | b4   | 40  | 6   |
| 8          | b4   | 80  | 7   |
| 9          | b5   | 01  | 8   |
| 10         | b5   | 02  | 9   |
| 11         | b5   | 04  | 10  |
| 12         | b5   | 08  | 11  |
| 13         | b5   | 10  | 12  |
| 14         | b5   | 20  | 13  |
| 15         | b5   | 40  | 14  |
| 16         | b5   | 80  | 15  |
| 17         | b6   | 01  | 16  |
| 18         | b6   | 02  | 17  |
| dial push  | b6   | 04  | 18  |

Dial rotate direction = byte 5 of the `f9` report: `0x01` one way, `0xff` the
other. Which is CW vs CCW is arbitrary — set to taste in the daemon.

## Notes

- Device sleeps when idle; a blocking `os.read` on the hidraw just resumes on
  wake, no special handling needed.
- Reading hidraw needs root (node is `root:root 0660`), or a udev rule granting
  the user access.
