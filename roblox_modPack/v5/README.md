# Roblox ModPack v5 – lokaler Realismus
Dieses Paket ist **kein** neuer Renderer und keine serverseitige Physiksimulation. Es nutzt lokale Luau-Effekte und verändert weder Schaden noch Waffenprojekteile.

## Start (Real Executor)
Nur **eine** Zeile in den Executor einfügen:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/roblox_modPack/v5/load.lua"))()
```
**Voraussetzung:** Executor mit `loadstring` und `game:HttpGet`. In normalem Roblox-Luau/Studio funktioniert dieser Remote-Loader nicht unverändert.

## Funktionen
- Basis-Core: Physik-Akkumulator mit 90 festen Berechnungsschritten/Sekunde; Regen/Schnee mit gesweepten Raycasts, kleinen Pfützenzellen und begrenzter Schneeablagerung.
- `body`: lokale Wassertropfen auf Händen, Armen, Kopf und auf unterstützten Werkzeug-/Viewmodel-Parts. Tropfen laufen unter Schwerkraft, lösen sich bei Bewegung und prüfen Aufprall-Kollisionen. Schnee-Flocken haften länger.
- `surface`: kleine Schnee-/Wasserflecken auf dem Boden, auf Dächern und schrägen statischen Oberflächen. Schnee sammelt sich und schmilzt bei Regen oder im Verlauf. Optional Schnee-Schrittgeräusch per **eigenem, gültigen Roblox-Audio-Asset-ID**.
- `worldfx`: zurückhaltendes Feuerlicht an bereits vorhandenen Feuer-/Mündungs-Emittern, leichte Baumblatt-Bewegung, Scope-Tiefenschärfe beim Zoom. Spielmechanik und Zielerfassung bleiben unverändert.
- `optics`: dezentes wetterabhängiges Color-Grading, Bloom und Sonnenstrahlen mittels normaler Roblox-PostFX.
- `ui`: schwarzes anpassbares Menü mit Eckenradius, Transparenz, Akzent, Roblox-Image-Asset-ID und echten Statuswerten.

## Steuerung
- **F10:** Menü ein-/ausblenden
- **F7:** Regen, Schnee, Aus
- **F9:** Wetterstärke wechseln
- **F8:** Basis-Realismus ein/aus
- **F6:** Basiskern-Diagnose

## Sicherheits- und Enginegrenzen
- Alle visuellen Veränderungen sind **clientseitig**, nicht für andere Spieler oder den Server. Sie sind unabhängig von anderen Spielen und können durch Roblox-Sicherheitsbeschränkungen begrenzt sein.
- Es gibt keine echte globale Wasservolumen-Simulation, kein physikalisches Schneeverdrängungsmodell, keine Server-Änderung von Waffen, Feuer, Bäumen oder NPCs. Keine neuen nativen GPU-Shader.
- Die Basis versucht, `LightingStyle` umzuschalten, aber Roblox schützt das Schreiben dieser Property; ein Fehlschlag wird gemeldet.
- Hochgeladene Roblox-Bild- und Audio-Asset-IDs können funktionieren, sofern Roblox diese zur Anzeige/Wiedergabe freigibt. Beliebige lokale PNG/GIF-Dateien funktionieren nicht über `ImageLabel`; GIF-Animation ist damit nicht verfügbar.
- Die gepackten Module verwenden **reversible XOR/Hex-Kodierung + Adler32-Prüfung**, **keine echte Verschlüsselung oder sichere VM**. Da der Client alle Bytes ausführen muss, können diese entschlüsselt werden. Der Loader lädt eine Git-Revision mit festem Commit-Hash, keine veränderlichen Modulpfade.
- Auto-Execute bei jedem Beitritt ist nur möglich, wenn der verwendete Executor eine entsprechende Funktion anbietet; Roblox selbst bietet dafür keinen universellen Clientmod-Mechanismus.
- CPU-Limit: 90 Hz ist ein Ziel im festen Zeitraster, kein garantierter Istwert. Bei niedriger FPS oder CPU-Last werden Nachholschritte begrenzt. F6/GUI zeigen gemessene Werte.
- `ctx.Stop()` bzw. erneutes Ausführen räumt lokale Effekte auf und restauriert gespeicherte Änderungen, soweit Spielscripts sie nicht inzwischen selbst überschrieben haben.

## Versionsaufbau
- `load.lua`: einziger Loader, direkt als RAW-Datei verfügbar.
- `core.lua`, `body.lua`, `surface.lua`, `worldfx.lua`, `optics.lua`, `ui.lua`: lesbare Quellmodule.
- `dist/*.lua`: dekodierbare Release-Kopien, mit Checksummen.

## Tests
Kopie/Packdateien wurden auf bytegleiche Dekodierbarkeit und Adler32-Prüfsummen geprüft. **Kein Live-Test mit Real Executor durchgeführt.** Sollten einzelne Module von Roblox blockiert werden, werden sie per Fehlermeldung gekennzeichnet statt als erfolgreich ausgegeben.
