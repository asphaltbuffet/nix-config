# The cabinet uses Retrorama, whose base resolution is the monitor's

The cosmo theme was replaced with [Retrorama](https://github.com/matteocedroni/am-theme-retrorama) because cosmo is authored for 16:9 (1280×720 assets, element positions expressed as fractions of screen dimensions) while the cabinet's monitor is 5:4 (1280×1024). Since `flw` and `flh` scale independently, every vertical fraction stretched 42%: backgrounds became unrecognisable smears, and cosmo's `static.mp4` video backdrop was left exposed around panels whose proportions no longer matched their contents. Retrorama computes `xs = surfaceWidth/1280` and `ys = surfaceHeight/1024`, so on this monitor both scale factors are exactly 1.0 and every element lands at its authored pixel.

Rescaling cosmo's vertical fractions by 720/1024 was considered and rejected on arithmetic: it restores the correct proportions but leaves the same 304 px (30%) of screen unused, making it identical to letterboxing. A theme authored for the cabinet's aspect ratio was the only fix that used the whole screen.

## Consequences

- Retrorama reads only the `snap` and `flyer` artwork slots. The `flyer` slot is pointed at the already-synced `boxart` directories rather than syncing the same files under a second name. The `wheel` and `cartart` art (~8 GB) is now unused but deliberately retained, so a future theme change needs no re-sync.
- Retrorama ships no `Nintendo Game Boy` or `Atari 2600` asset folder and has no fallback for an unmatched system — the layout builds a path to a nonexistent directory. Both folders were assembled by hand (console photo, 1280×1024 background, splash, specs sheet) and live on the cabinet as out-of-band content per ADR-0012.
- Per-display layout options are plain keys inside a `display` section, not a `layout_config` section: `FeDisplayInfo::process_setting` routes unrecognised keys to `m_layout_per_display_params` and `save()` writes them back there. Retrorama's `system` option is set through `displays.<name>.extraSettings`, so `programs.attract-mode` needed no new option.
- Displays-menu artwork is a third, separate mechanism — `~/.attract/menu-art/<slot>/<display name>.<ext>` — independent of both emulator artwork and layout assets. It was empty, which is why the system wheel rendered `?` placeholders regardless of theme.
- A theme's assumed aspect ratio is worth checking before adopting it. Cosmo was chosen on appearance and its 16:9 assumption surfaced only after deployment, as three seemingly unrelated visual faults.
